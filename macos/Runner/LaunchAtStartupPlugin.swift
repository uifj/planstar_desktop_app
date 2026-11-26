import Cocoa
import FlutterMacOS
import Foundation
import ServiceManagement

protocol MacLoginItemService {
  var isEnabled: Bool { get }
  func setEnabled(_ enabled: Bool) throws
}

enum MacLoginItemModernStatus: Equatable {
  case notRegistered
  case requiresApproval
  case enabled
}

struct SystemLoginItemService: MacLoginItemService {
  let bundleIdentifier: String
  let defaults: UserDefaults
  let majorVersion: Int
  private let modernStatus: () -> MacLoginItemModernStatus
  private let modernRegister: () throws -> Void
  private let modernUnregister: () throws -> Void
  private let legacySetEnabled: (String, Bool) -> Bool

  init(
    bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "",
    defaults: UserDefaults = .standard,
    majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
    modernStatus: @escaping () -> MacLoginItemModernStatus = {
      if #available(macOS 13.0, *) {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        default: return .notRegistered
        }
      }
      return .notRegistered
    },
    modernRegister: @escaping () throws -> Void = {
      if #available(macOS 13.0, *) {
        try SMAppService.mainApp.register()
      }
    },
    modernUnregister: @escaping () throws -> Void = {
      if #available(macOS 13.0, *) {
        try SMAppService.mainApp.unregister()
      }
    },
    legacySetEnabled: @escaping (String, Bool) -> Bool = { identifier, enabled in
      SMLoginItemSetEnabled(identifier as CFString, enabled)
    }
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.defaults = defaults
    self.majorVersion = majorVersion
    self.modernStatus = modernStatus
    self.modernRegister = modernRegister
    self.modernUnregister = modernUnregister
    self.legacySetEnabled = legacySetEnabled
  }

  private var stateKey: String { "planstar.loginItem.\(bundleIdentifier)" }

  var isEnabled: Bool {
    if majorVersion >= 13 {
      return modernStatus() == .enabled
    }
    return defaults.bool(forKey: stateKey)
  }

  func setEnabled(_ enabled: Bool) throws {
    guard !bundleIdentifier.isEmpty else {
      throw CocoaError(.fileNoSuchFile)
    }
    if majorVersion >= 13 {
      do {
        if enabled {
          try modernRegister()
        } else if modernStatus() == .enabled {
          try modernUnregister()
        }
      } catch {
        defaults.set(false, forKey: stateKey)
        throw error
      }
    } else if !legacySetEnabled(bundleIdentifier, enabled) {
      throw NSError(
        domain: "PlanstarLoginItem",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "无法更新 macOS 登录项"]
      )
    }
    defaults.set(enabled, forKey: stateKey)
  }
}

final class MacLaunchAtStartupPlugin: NSObject, LaunchAtStartupHostApi {
  private let service: MacLoginItemService

  init(messenger: FlutterBinaryMessenger, service: MacLoginItemService = SystemLoginItemService()) {
    self.service = service
    super.init()
    LaunchAtStartupHostApiSetup.setUp(binaryMessenger: messenger, api: self)
  }

  func isEnabled() throws -> Bool {
    service.isEnabled
  }

  func setEnabled(enabled: Bool) throws {
    do {
      try service.setEnabled(enabled)
    } catch {
      throw PigeonError(
        code: "loginItemFailed",
        message: error.localizedDescription,
        details: nil
      )
    }
  }
}
