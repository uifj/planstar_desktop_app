#include "data_hub_plugin.h"

#include <windows.h>

#include <algorithm>
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
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler.h>
#include <flutter/method_channel.h>
#include <flutter/method_result.h>
#include <flutter/standard_method_codec.h>

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::EventChannel;
using flutter::EventSink;
using flutter::MethodCall;
using flutter::MethodChannel;
using flutter::MethodResult;
using flutter::StandardMethodCodec;
using flutter::StreamHandler;
using flutter::StreamHandlerError;

constexpr char kMethodChannelName[] = "planstar/data_hub";
constexpr char kEventChannelName[] = "planstar/data_hub_events";

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

std::string StringAt(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) return std::string();
  if (const auto* value = std::get_if<std::string>(&it->second)) {
    return *value;
  }
  return std::string();
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

  EncodableMap Configure(const std::string& file_path,
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

  EncodableMap Snapshot() {
    std::lock_guard<std::mutex> lock(mutex_);
    return SnapshotLocked();
  }

  EncodableMap Write(const std::string& key, const std::string& value,
                     const std::string& origin) {
    std::vector<std::shared_ptr<EventSink<EncodableValue>>> targets;
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
        return ErrorResult("persist failed; write was rolled back");
      }
      revision_ = revision;
      targets = sinks_;
    }
    Broadcast(targets, key, &value, false, revision, origin);
    return OkResult(revision);
  }

  EncodableMap Delete(const std::string& key, const std::string& origin) {
    std::vector<std::shared_ptr<EventSink<EncodableValue>>> targets;
    int64_t revision = 0;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      const auto previous = entries_.find(key);
      if (previous == entries_.end()) return OkResult(revision_);
      const std::string old_value = previous->second;
      entries_.erase(previous);
      revision = revision_ + 1;
      if (!PersistLocked()) {
        entries_[key] = old_value;
        return ErrorResult("persist failed; delete was rolled back");
      }
      revision_ = revision;
      targets = sinks_;
    }
    Broadcast(targets, key, nullptr, true, revision, origin);
    return OkResult(revision);
  }

  EncodableMap Clear() {
    std::vector<std::shared_ptr<EventSink<EncodableValue>>> targets;
    int64_t revision = 0;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      const auto previous = entries_;
      entries_.clear();
      revision = revision_ + 1;
      if (!PersistLocked()) {
        entries_ = previous;
        return ErrorResult("persist failed; clear was rolled back");
      }
      revision_ = revision;
      targets = sinks_;
    }
    Broadcast(targets, std::string(), nullptr, true, revision, std::string());
    return OkResult(revision);
  }

  static EncodableMap OkResult(int64_t revision) {
    EncodableMap result;
    result[EncodableValue("ok")] = EncodableValue(true);
    result[EncodableValue("revision")] = EncodableValue(revision);
    return result;
  }

  static EncodableMap ErrorResult(const char* message) {
    EncodableMap result;
    result[EncodableValue("ok")] = EncodableValue(false);
    result[EncodableValue("error")] = EncodableValue(message);
    return result;
  }

  void AddSink(std::shared_ptr<EventSink<EncodableValue>> sink) {
    std::lock_guard<std::mutex> lock(mutex_);
    sinks_.push_back(std::move(sink));
  }

  void RemoveSink(const std::shared_ptr<EventSink<EncodableValue>>& sink) {
    std::lock_guard<std::mutex> lock(mutex_);
    sinks_.erase(std::remove(sinks_.begin(), sinks_.end(), sink), sinks_.end());
  }

 private:
  DataHub() = default;

  EncodableMap SnapshotLocked() {
    EncodableMap entries;
    for (const auto& item : entries_) {
      entries[EncodableValue(item.first)] = EncodableValue(item.second);
    }
    EncodableMap snapshot;
    snapshot[EncodableValue("revision")] = EncodableValue(revision_);
    snapshot[EncodableValue("entries")] = EncodableValue(entries);
    return snapshot;
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
      const std::vector<std::shared_ptr<EventSink<EncodableValue>>>& targets,
      const std::string& key, const std::string* value, bool deleted,
      int64_t revision, const std::string& origin) {
    EncodableMap event;
    event[EncodableValue("key")] = EncodableValue(key);
    event[EncodableValue("revision")] = EncodableValue(revision);
    event[EncodableValue("origin")] = EncodableValue(origin);
    event[EncodableValue("deleted")] = EncodableValue(deleted);
    if (deleted || value == nullptr) {
      event[EncodableValue("value")] = EncodableValue();
    } else {
      event[EncodableValue("value")] = EncodableValue(*value);
    }
    const EncodableValue payload(std::move(event));
    for (const auto& sink : targets) {
      if (sink) sink->Success(payload);
    }
  }

  std::mutex mutex_;
  std::map<std::string, std::string> entries_;
  std::vector<std::shared_ptr<EventSink<EncodableValue>>> sinks_;
  std::string file_path_;
  int64_t revision_ = 0;
  bool configured_ = false;
};

class DataHubStreamHandler : public StreamHandler<EncodableValue> {
 protected:
  std::unique_ptr<StreamHandlerError<EncodableValue>> OnListenInternal(
      const EncodableValue* arguments,
      std::unique_ptr<EventSink<EncodableValue>>&& events) override {
    sink_ = std::shared_ptr<EventSink<EncodableValue>>(std::move(events));
    DataHub::Instance().AddSink(sink_);
    return nullptr;
  }

  std::unique_ptr<StreamHandlerError<EncodableValue>> OnCancelInternal(
      const EncodableValue* arguments) override {
    if (sink_) {
      DataHub::Instance().RemoveSink(sink_);
      sink_.reset();
    }
    return nullptr;
  }

 private:
  std::shared_ptr<EventSink<EncodableValue>> sink_;
};

void HandleCall(const MethodCall<EncodableValue>& call,
                std::unique_ptr<MethodResult<EncodableValue>> result) {
  const EncodableMap empty;
  const EncodableMap* args =
      call.arguments() ? std::get_if<EncodableMap>(call.arguments()) : nullptr;
  const EncodableMap& map = args != nullptr ? *args : empty;
  const std::string& method = call.method_name();
  DataHub& hub = DataHub::Instance();

  if (method == "configure") {
    EncodableMap initial;
    const auto it = map.find(EncodableValue("entries"));
    if (it != map.end()) {
      if (const auto* entries = std::get_if<EncodableMap>(&it->second)) {
        initial = *entries;
      }
    }
    result->Success(EncodableValue(
        hub.Configure(StringAt(map, "filePath"), initial)));
  } else if (method == "snapshot") {
    result->Success(EncodableValue(hub.Snapshot()));
  } else if (method == "write") {
    result->Success(EncodableValue(hub.Write(
        StringAt(map, "key"), StringAt(map, "value"),
        StringAt(map, "origin"))));
  } else if (method == "delete") {
    result->Success(
        EncodableValue(hub.Delete(StringAt(map, "key"),
                                  StringAt(map, "origin"))));
  } else if (method == "clear") {
    result->Success(EncodableValue(hub.Clear()));
  } else {
    result->NotImplemented();
  }
}

// One channel pair per engine; process-wide vectors keep them alive after
// RegisterDataHubPlugin returns (BinaryMessenger is engine-private).
std::vector<std::unique_ptr<MethodChannel<EncodableValue>>> g_method_channels;
std::vector<std::unique_ptr<EventChannel<EncodableValue>>> g_event_channels;
std::mutex g_registry_mutex;

}  // namespace

void RegisterDataHubPlugin(flutter::BinaryMessenger* messenger) {
  if (messenger == nullptr) return;
  auto method = std::make_unique<MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName, &StandardMethodCodec::GetInstance());
  method->SetMethodCallHandler(
      [](const MethodCall<EncodableValue>& call,
         std::unique_ptr<MethodResult<EncodableValue>> result) {
        HandleCall(call, std::move(result));
      });

  auto events = std::make_unique<EventChannel<EncodableValue>>(
      messenger, kEventChannelName, &StandardMethodCodec::GetInstance());
  events->SetStreamHandler(std::make_unique<DataHubStreamHandler>());

  std::lock_guard<std::mutex> lock(g_registry_mutex);
  g_method_channels.push_back(std::move(method));
  g_event_channels.push_back(std::move(events));
}
