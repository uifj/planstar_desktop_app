import Darwin
import Foundation
import FlutterMacOS

private enum DataHubFailure: Error {
  case persistence(String)
}

final class MacDataHubStore {
  static let shared = MacDataHubStore()

  private let queue = DispatchQueue(label: "planstar.desktop.data-hub")
  private var listeners: [UUID: DataHubEventsFlutterApiProtocol] = [:]
  private var entries: [String: String] = [:]
  private var fileURL: URL?
  private var revision: Int64 = 0
  private var configured = false

  func addListener(_ id: UUID, _ listener: DataHubEventsFlutterApiProtocol) {
    queue.sync { listeners[id] = listener }
  }

  func removeListener(_ id: UUID) {
    _ = queue.sync { listeners.removeValue(forKey: id) }
  }

  func configure(filePath: String, initial: [DataHubEntryDto]) throws
    -> DataHubSnapshotDto
  {
    try queue.sync {
      if !configured {
        let url = URL(fileURLWithPath: filePath)
        let persisted = try readSnapshot(at: url)
        entries = persisted?.entries ?? [:]
        revision = max(revision, persisted?.revision ?? 0)
        for entry in initial where entries[entry.key] == nil {
          entries[entry.key] = entry.value
        }
        fileURL = url
        try persistLocked(revision + 1)
        revision += 1
        configured = true
      }
      return snapshotLocked()
    }
  }

  func snapshot() -> DataHubSnapshotDto {
    queue.sync { snapshotLocked() }
  }

  func write(key: String, value: String, origin: String) throws -> Int64 {
    try queue.sync {
      let existed = entries[key] != nil
      let previous = entries[key]
      entries[key] = value
      do {
        try persistLocked(revision + 1)
      } catch {
        if existed {
          entries[key] = previous
        } else {
          entries.removeValue(forKey: key)
        }
        throw error
      }
      revision += 1
      let result = revision
      let change = DataChangeDto(
        key: key,
        revision: result,
        origin: origin,
        deleted: false,
        value: value
      )
      broadcast(change)
      return result
    }
  }

  func delete(key: String, origin: String) throws -> Int64 {
    try queue.sync {
      guard let previous = entries.removeValue(forKey: key) else {
        return revision
      }
      do {
        try persistLocked(revision + 1)
      } catch {
        entries[key] = previous
        throw error
      }
      revision += 1
      let result = revision
      broadcast(
        DataChangeDto(
          key: key,
          revision: result,
          origin: origin,
          deleted: true,
          value: nil
        )
      )
      return result
    }
  }

  func clear() throws -> DataHubSnapshotDto {
    try queue.sync {
      let previous = entries
      entries = [:]
      do {
        try persistLocked(revision + 1)
      } catch {
        entries = previous
        throw error
      }
      revision += 1
      let result = revision
      broadcast(
        DataChangeDto(
          key: "",
          revision: result,
          origin: "",
          deleted: true,
          value: nil
        )
      )
      return snapshotLocked()
    }
  }

  private struct Snapshot {
    var revision: Int64
    var entries: [String: String]
  }

  private func snapshotLocked() -> DataHubSnapshotDto {
    DataHubSnapshotDto(
      revision: revision,
      entries: entries.keys.sorted().map {
        DataHubEntryDto(key: $0, value: entries[$0]!)
      }
    )
  }

  private func readSnapshot(at url: URL) throws -> Snapshot? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    do {
      let data = try Data(contentsOf: url)
      let decoded = try JSONSerialization.jsonObject(with: data)
      guard let object = decoded as? [String: Any],
        let rawEntries = object["entries"] as? [String: String]
      else {
        return Snapshot(revision: 0, entries: [:])
      }
      let diskRevision = (object["revision"] as? NSNumber)?.int64Value ?? 0
      return Snapshot(revision: diskRevision, entries: rawEntries)
    } catch {
      throw DataHubFailure.persistence("read failed: \(error.localizedDescription)")
    }
  }

  private func persistLocked(_ nextRevision: Int64) throws {
    guard let fileURL else {
      throw DataHubFailure.persistence("store is not configured")
    }
    let object: [String: Any] = [
      "revision": nextRevision,
      "entries": entries,
    ]
    let data: Data
    do {
      data = try JSONSerialization.data(withJSONObject: object)
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
    } catch {
      throw DataHubFailure.persistence(
        "encode failed: \(error.localizedDescription)"
      )
    }
    let temporary = fileURL.deletingLastPathComponent()
      .appendingPathComponent(".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp")
    defer {
      if FileManager.default.fileExists(atPath: temporary.path) {
        try? FileManager.default.removeItem(at: temporary)
      }
    }
    do {
      try data.write(to: temporary, options: .atomic)
      let result = temporary.path.withCString { source in
        fileURL.path.withCString { destination in
          rename(source, destination)
        }
      }
      if result != 0 {
        throw NSError(
          domain: NSPOSIXErrorDomain,
          code: Int(errno),
          userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errno))]
        )
      }
    } catch {
      throw DataHubFailure.persistence(
        "write failed: \(error.localizedDescription)"
      )
    }
  }

  private func broadcast(_ change: DataChangeDto) {
    let targets = Array(listeners.values)
    for listener in targets {
      listener.onDataChanged(change: change) { _ in }
    }
  }
}

final class MacDataHubPlugin: NSObject, DataHubHostApi {
  private let listenerID = UUID()
  private let messenger: FlutterBinaryMessenger
  private let events: DataHubEventsFlutterApi

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    events = DataHubEventsFlutterApi(binaryMessenger: messenger)
    super.init()
    MacDataHubStore.shared.addListener(listenerID, events)
    DataHubHostApiSetup.setUp(binaryMessenger: messenger, api: self)
  }

  deinit {
    MacDataHubStore.shared.removeListener(listenerID)
  }

  func configure(filePath: String, entries: [DataHubEntryDto]) throws
    -> DataHubSnapshotDto
  {
    return try MacDataHubStore.shared.configure(filePath: filePath, initial: entries)
  }

  func snapshot() throws -> DataHubSnapshotDto {
    MacDataHubStore.shared.snapshot()
  }

  func write(key: String, value: String, origin: String) throws -> Int64 {
    try MacDataHubStore.shared.write(key: key, value: value, origin: origin)
  }

  func delete(key: String, origin: String) throws -> Int64 {
    try MacDataHubStore.shared.delete(key: key, origin: origin)
  }

  func clear() throws -> DataHubSnapshotDto {
    try MacDataHubStore.shared.clear()
  }
}
