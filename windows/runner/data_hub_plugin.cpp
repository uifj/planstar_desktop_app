#include "data_hub_plugin.h"

#include <windows.h>

#include <algorithm>
#include <any>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>

#include "pigeon/planstar_api.g.h"

namespace {

namespace pp = planstar::pigeon;

using flutter::CustomEncodableValue;
using flutter::EncodableList;
using flutter::EncodableValue;

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

// Pigeon encodes custom classes as CustomEncodableValue(std::any).
const pp::DataHubEntryDto* AsEntry(const EncodableValue& value) {
  if (const auto* custom = std::get_if<CustomEncodableValue>(&value)) {
    const std::any& payload = *custom;
    return std::any_cast<pp::DataHubEntryDto>(&payload);
  }
  return nullptr;
}

struct MutationResult {
  bool ok = true;
  int64_t revision = 0;
  std::string error;
};

// Restores the persisted monotonic revision so a restart continues from the
// on-disk value instead of resetting to 0 (same invariant the Dart fallback
// backend keeps, see test/audit_fixes_test.dart).
int64_t ReadRevisionFromFile(const std::string& path) {
  std::ifstream file(Utf8ToWide(path), std::ios::binary);
  if (!file) return 0;
  std::string head(4096, '\0');
  file.read(&head[0], static_cast<std::streamsize>(head.size()));
  head.resize(static_cast<size_t>(file.gcount()));
  const std::string marker = "\"revision\":";
  std::string::size_type pos = head.find(marker);
  if (pos == std::string::npos) return 0;
  pos += marker.size();
  while (pos < head.size() && head[pos] == ' ') ++pos;
  int64_t value = 0;
  bool has_digits = false;
  while (pos < head.size() && head[pos] >= '0' && head[pos] <= '9') {
    value = value * 10 + (head[pos] - '0');
    has_digits = true;
    ++pos;
  }
  return has_digits ? value : 0;
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

  pp::DataHubSnapshotDto Configure(const std::string& file_path,
                                   const EncodableList& initial) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!configured_) {
      file_path_ = file_path;
      revision_ = std::max(revision_, ReadRevisionFromFile(file_path_));
      for (const auto& item : initial) {
        const pp::DataHubEntryDto* entry = AsEntry(item);
        if (entry != nullptr) entries_[entry->key()] = entry->value();
      }
      if (!PersistLocked()) {
        // Keep configured_=false so a later configure can retry initial persist.
        return SnapshotLocked();
      }
      configured_ = true;
    }
    return SnapshotLocked();
  }

  pp::DataHubSnapshotDto Snapshot() {
    std::lock_guard<std::mutex> lock(mutex_);
    return SnapshotLocked();
  }

  MutationResult Write(const std::string& key, const std::string& value,
                       const std::string& origin) {
    std::vector<std::shared_ptr<pp::DataHubEventsFlutterApi>> targets;
    int64_t revision = 0;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      const auto previous = entries_.find(key);
      const bool existed = previous != entries_.end();
      const std::string old_value = existed ? previous->second : std::string();
      entries_[key] = value;
      revision = revision_ + 1;
      if (!PersistLocked()) {
        // Roll back both data and revision: a failed write must not be
        // observed by other engines nor advance the monotonic clock.
        if (existed) {
          entries_[key] = old_value;
        } else {
          entries_.erase(key);
        }
        return MutationResult{false, 0, "persist failed; write was rolled back"};
      }
      revision_ = revision;
      targets = listeners_;
    }
    Broadcast(targets, key, &value, false, revision, origin);
    return MutationResult{true, revision, std::string()};
  }

  MutationResult Delete(const std::string& key, const std::string& origin) {
    std::vector<std::shared_ptr<pp::DataHubEventsFlutterApi>> targets;
    int64_t revision = 0;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      const auto previous = entries_.find(key);
      if (previous == entries_.end()) {
        return MutationResult{true, revision_, std::string()};
      }
      const std::string old_value = previous->second;
      entries_.erase(previous);
      revision = revision_ + 1;
      if (!PersistLocked()) {
        entries_[key] = old_value;
        return MutationResult{false, 0,
                              "persist failed; delete was rolled back"};
      }
      revision_ = revision;
      targets = listeners_;
    }
    Broadcast(targets, key, nullptr, true, revision, origin);
    return MutationResult{true, revision, std::string()};
  }

  MutationResult Clear() {
    std::vector<std::shared_ptr<pp::DataHubEventsFlutterApi>> targets;
    int64_t revision = 0;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      const auto previous = entries_;
      entries_.clear();
      revision = revision_ + 1;
      if (!PersistLocked()) {
        entries_ = previous;
        return MutationResult{false, 0, "persist failed; clear was rolled back"};
      }
      revision_ = revision;
      targets = listeners_;
    }
    Broadcast(targets, std::string(), nullptr, true, revision, std::string());
    return MutationResult{true, revision, std::string()};
  }

  void AddListener(std::shared_ptr<pp::DataHubEventsFlutterApi> listener) {
    std::lock_guard<std::mutex> lock(mutex_);
    listeners_.push_back(std::move(listener));
  }

 private:
  DataHub() = default;

  pp::DataHubSnapshotDto SnapshotLocked() {
    EncodableList entries;
    entries.reserve(entries_.size());
    for (const auto& item : entries_) {
      entries.push_back(CustomEncodableValue(
          pp::DataHubEntryDto(item.first, item.second)));
    }
    return pp::DataHubSnapshotDto(revision_, entries);
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
    // Atomic replace without MOVEFILE_WRITE_THROUGH: the rename is atomic, so
    // readers never see partial JSON, while we avoid an fsync per write (the
    // pre-Pigeon implementation also did not force a disk flush).
    if (!::MoveFileExW(tmp.c_str(), target.c_str(), MOVEFILE_REPLACE_EXISTING)) {
      ::DeleteFileW(tmp.c_str());
      return false;
    }
    return true;
  }

  void Broadcast(
      const std::vector<std::shared_ptr<pp::DataHubEventsFlutterApi>>& targets,
      const std::string& key, const std::string* value, bool deleted,
      int64_t revision, const std::string& origin) {
    if (targets.empty()) return;
    const pp::DataChangeDto change(key, revision, origin, deleted, value);
    for (const auto& listener : targets) {
      if (listener == nullptr) continue;
      listener->OnDataChanged(change, []() {},
                              [](const pp::FlutterError&) {});
    }
  }

  std::mutex mutex_;
  std::map<std::string, std::string> entries_;
  std::vector<std::shared_ptr<pp::DataHubEventsFlutterApi>> listeners_;
  std::string file_path_;
  int64_t revision_ = 0;
  bool configured_ = false;
};

// HostApi implementation: one per engine, all backed by the singleton above.
class DataHubHostApiImpl : public pp::DataHubHostApi {
 public:
  pp::ErrorOr<pp::DataHubSnapshotDto> Configure(
      const std::string& file_path,
      const EncodableList& entries) override {
    return DataHub::Instance().Configure(file_path, entries);
  }

  pp::ErrorOr<pp::DataHubSnapshotDto> Snapshot() override {
    return DataHub::Instance().Snapshot();
  }

  pp::ErrorOr<int64_t> Write(const std::string& key, const std::string& value,
                             const std::string& origin) override {
    const MutationResult result = DataHub::Instance().Write(key, value, origin);
    if (!result.ok) {
      return pp::FlutterError("persist_failed", result.error);
    }
    return result.revision;
  }

  pp::ErrorOr<int64_t> Delete(const std::string& key,
                              const std::string& origin) override {
    const MutationResult result = DataHub::Instance().Delete(key, origin);
    if (!result.ok) {
      return pp::FlutterError("persist_failed", result.error);
    }
    return result.revision;
  }

  pp::ErrorOr<pp::DataHubSnapshotDto> Clear() override {
    const MutationResult result = DataHub::Instance().Clear();
    if (!result.ok) {
      return pp::FlutterError("persist_failed", result.error);
    }
    return DataHub::Instance().Snapshot();
  }
};

// One registration per engine; process-wide vectors keep them alive after
// RegisterDataHubPlugin returns (BinaryMessenger is engine-private).
struct EngineRegistration {
  std::unique_ptr<DataHubHostApiImpl> api;
  std::shared_ptr<pp::DataHubEventsFlutterApi> events;
};

std::vector<EngineRegistration> g_registrations;
std::mutex g_registry_mutex;

}  // namespace

void RegisterDataHubPlugin(flutter::BinaryMessenger* messenger) {
  if (messenger == nullptr) return;

  EngineRegistration registration;
  registration.api = std::make_unique<DataHubHostApiImpl>();
  pp::DataHubHostApi::SetUp(messenger, registration.api.get());

  // Native -> Dart change feed. Replaces the hand-written EventChannel with a
  // typed FlutterApi call that has no dynamic Map decoding at either end.
  registration.events =
      std::make_shared<pp::DataHubEventsFlutterApi>(messenger);
  DataHub::Instance().AddListener(registration.events);

  std::lock_guard<std::mutex> lock(g_registry_mutex);
  g_registrations.push_back(std::move(registration));
}
