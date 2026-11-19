#include "data_hub_plugin.h"

#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>

#include "generated/data_hub.g.h"

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using planstar_data_hub::DataChangePayload;
using planstar_data_hub::DataHubFlutterApi;
using planstar_data_hub::DataHubSnapshot;
using planstar_data_hub::ErrorOr;
using planstar_data_hub::FlutterError;
using planstar_data_hub::WriteResult;

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  const int size = ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), nullptr, 0);
  if (size <= 0) return std::wstring();
  std::wstring wide(static_cast<size_t>(size), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(),
                        static_cast<int>(utf8.size()), &wide[0], size);
  return wide;
}

// Only keys/values are JSON strings; UTF-8 bytes >= 0x80 are passed through.
std::string JsonQuote(const std::string& value) {
  std::string out;
  out.reserve(value.size() + 2);
  out.push_back('"');
  for (const unsigned char c : value) {
    switch (c) {
      case '"':
        out += "\\\"";
        break;
      case '\\':
        out += "\\\\";
        break;
      case '\n':
        out += "\\n";
        break;
      case '\r':
        out += "\\r";
        break;
      case '\t':
        out += "\\t";
        break;
      default:
        if (c < 0x20) {
          char buffer[8];
          std::snprintf(buffer, sizeof(buffer), "\\u%04x", c);
          out += buffer;
        } else {
          out.push_back(static_cast<char>(c));
        }
    }
  }
  out.push_back('"');
  return out;
}

// Single source of truth for the whole Win32 process. All windows/engines
// live in one process (see main.cpp / desktop_multi_window), so a mutex
// protected singleton removes the read-modify-write race completely.
class DataHub {
 public:
  static DataHub& Instance() {
    static DataHub hub;
    return hub;
  }

  DataHub(const DataHub&) = delete;
  DataHub& operator=(const DataHub&) = delete;

  DataHubSnapshot Configure(const std::string& file_path,
                            const EncodableMap& initial) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!configured_) {
      file_path_ = file_path;
      for (const auto& item : initial) {
        if (const auto* key = std::get_if<std::string>(&item.first)) {
          if (const auto* value = std::get_if<std::string>(&item.second)) {
            entries_[*key] = *value;
          }
        }
      }
      if (!PersistLocked()) {
        // Keep configured_=false so a later configure can retry initial persist.
        return SnapshotLocked();
      }
      configured_ = true;
    }
    return SnapshotLocked();
  }

  DataHubSnapshot Snapshot() {
    std::lock_guard<std::mutex> lock(mutex_);
    return SnapshotLocked();
  }

  WriteResult Write(const std::string& key, const std::string& value,
                    const std::string& origin) {
    std::vector<std::shared_ptr<DataHubFlutterApi>> targets;
    int64_t revision = 0;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      const auto previous = entries_.find(key);
      const bool existed = previous != entries_.end();
      const std::string old_value = existed ? previous->second : std::string();
      entries_[key] = value;
      revision = revision_ + 1;
      // 盘上 revision 必须与 entries 快照同版本：先推进再落盘，失败回滚两者。
      const int64_t previous_revision = revision_;
      revision_ = revision;
      if (!PersistLocked()) {
        // Roll back both data and revision: a failed write must not be
        // observed by other engines nor advance the monotonic clock.
        if (existed) {
          entries_[key] = old_value;
        } else {
          entries_.erase(key);
        }
        revision_ = previous_revision;
        return ErrorResult("persist failed; write was rolled back");
      }
      targets = proxies_;
    }
    Broadcast(targets, key, &value, false, revision, origin);
    return WriteResult(true, revision);
  }

  WriteResult Delete(const std::string& key, const std::string& origin) {
    std::vector<std::shared_ptr<DataHubFlutterApi>> targets;
    int64_t revision = 0;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      const auto previous = entries_.find(key);
      if (previous == entries_.end()) return WriteResult(true, revision_);
      const std::string old_value = previous->second;
      entries_.erase(previous);
      revision = revision_ + 1;
      const int64_t previous_revision = revision_;
      revision_ = revision;
      if (!PersistLocked()) {
        entries_[key] = old_value;
        revision_ = previous_revision;
        return ErrorResult("persist failed; delete was rolled back");
      }
      targets = proxies_;
    }
    Broadcast(targets, key, nullptr, true, revision, origin);
    return WriteResult(true, revision);
  }

  WriteResult Clear() {
    std::vector<std::shared_ptr<DataHubFlutterApi>> targets;
    int64_t revision = 0;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      const auto previous = entries_;
      entries_.clear();
      revision = revision_ + 1;
      const int64_t previous_revision = revision_;
      revision_ = revision;
      if (!PersistLocked()) {
        entries_ = previous;
        revision_ = previous_revision;
        return ErrorResult("persist failed; clear was rolled back");
      }
      targets = proxies_;
    }
    Broadcast(targets, std::string(), nullptr, true, revision, std::string());
    return WriteResult(true, revision);
  }

  void AddProxy(std::shared_ptr<DataHubFlutterApi> proxy) {
    std::lock_guard<std::mutex> lock(mutex_);
    proxies_.push_back(std::move(proxy));
  }

  void RemoveProxy(const std::shared_ptr<DataHubFlutterApi>& proxy) {
    std::lock_guard<std::mutex> lock(mutex_);
    proxies_.erase(
        std::remove(proxies_.begin(), proxies_.end(), proxy), proxies_.end());
  }

 private:
  DataHub() = default;

  // ok=false carries the unchanged revision: rollback never advances the clock.
  WriteResult ErrorResult(const char* message) {
    const std::string error(message);
    return WriteResult(false, revision_, &error);
  }

  DataHubSnapshot SnapshotLocked() {
    EncodableMap entries;
    for (const auto& item : entries_) {
      entries[EncodableValue(item.first)] = EncodableValue(item.second);
    }
    return DataHubSnapshot(revision_, entries);
  }

  // Atomic replace: write a temp file, then MoveFileEx(REPLACE_EXISTING).
  // A concurrently reading engine can never observe a half-written JSON.
  // Returns false on any IO failure so callers can roll back the in-memory
  // mutation and report the error instead of silently claiming success.
  bool PersistLocked() {
    if (file_path_.empty()) return true;
    std::ostringstream out;
    out << "{\"revision\":" << revision_ << ",\"entries\":{";
    bool first = true;
    for (const auto& item : entries_) {
      if (!first) out << ',';
      first = false;
      out << JsonQuote(item.first) << ':' << JsonQuote(item.second);
    }
    out << "}}";

    const std::wstring tmp = Utf8ToWide(file_path_ + ".tmp");
    const std::wstring target = Utf8ToWide(file_path_);
    if (tmp.empty() || target.empty()) return false;
    {
      std::ofstream file(tmp, std::ios::binary | std::ios::trunc);
      if (!file) return false;
      file << out.str();
      file.flush();
      if (!file.good()) return false;
    }
    if (!::MoveFileExW(tmp.c_str(), target.c_str(),
                       MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
      ::DeleteFileW(tmp.c_str());
      return false;
    }
    return true;
  }

  void Broadcast(
      const std::vector<std::shared_ptr<DataHubFlutterApi>>& targets,
      const std::string& key, const std::string* value, bool deleted,
      int64_t revision, const std::string& origin) {
    const DataChangePayload payload(key, revision, origin, deleted, value);
    for (const auto& proxy : targets) {
      if (proxy) {
        proxy->DataChanged(payload, []() {}, [](const FlutterError&) {});
      }
    }
  }

  std::mutex mutex_;
  std::map<std::string, std::string> entries_;
  std::vector<std::shared_ptr<DataHubFlutterApi>> proxies_;
  std::string file_path_;
  int64_t revision_ = 0;
  bool configured_ = false;
};

// Pigeon HostApi 实现：命令面委托进程级 DataHub 单例；广播订阅以本 engine
// 的 FlutterApi 代理注册，Release 时摘除，避免向已销毁 engine 推送。
class DataHubHostApiImpl : public planstar_data_hub::DataHubHostApi {
 public:
  explicit DataHubHostApiImpl(std::shared_ptr<DataHubFlutterApi> proxy)
      : proxy_(std::move(proxy)) {}

  ErrorOr<DataHubSnapshot> Configure(
      const std::string& file_path, const EncodableMap& entries) override {
    return DataHub::Instance().Configure(file_path, entries);
  }

  ErrorOr<DataHubSnapshot> Snapshot() override {
    return DataHub::Instance().Snapshot();
  }

  ErrorOr<WriteResult> Write(const std::string& key, const std::string& value,
                             const std::string& origin) override {
    return DataHub::Instance().Write(key, value, origin);
  }

  ErrorOr<WriteResult> Delete(const std::string& key,
                              const std::string& origin) override {
    return DataHub::Instance().Delete(key, origin);
  }

  ErrorOr<WriteResult> Clear() override { return DataHub::Instance().Clear(); }

  std::optional<FlutterError> Release() override {
    DataHub::Instance().RemoveProxy(proxy_);
    return std::nullopt;
  }

 private:
  std::shared_ptr<DataHubFlutterApi> proxy_;
};

// One HostApi impl per engine; the process-wide vector keeps it alive after
// RegisterDataHubPlugin returns (BinaryMessenger is engine-private, and the
// generated SetUp captures the raw impl pointer in its channel handlers).
std::vector<std::unique_ptr<DataHubHostApiImpl>> g_impls;
std::mutex g_registry_mutex;

}  // namespace

void RegisterDataHubPlugin(flutter::BinaryMessenger* messenger) {
  if (messenger == nullptr) return;
  auto proxy = std::make_shared<DataHubFlutterApi>(messenger);
  DataHub::Instance().AddProxy(proxy);

  auto impl = std::make_unique<DataHubHostApiImpl>(proxy);
  planstar_data_hub::DataHubHostApi::SetUp(messenger, impl.get());

  std::lock_guard<std::mutex> lock(g_registry_mutex);
  g_impls.push_back(std::move(impl));
}