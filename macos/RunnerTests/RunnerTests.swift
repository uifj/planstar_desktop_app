import AppKit
import CoreGraphics
import FlutterMacOS
import Foundation
import XCTest

final class RunnerTests: XCTestCase {
  func testDataHubPersistenceRevisionAndRollback() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
      at: root,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: root) }

    let blocker = root.appendingPathComponent("blocker")
    let directory = root.appendingPathComponent("store")
    let file = directory.appendingPathComponent("data-hub.json")
    try Data("blocked".utf8).write(to: blocker)

    let store = MacDataHubStore()
    XCTAssertThrowsError(
      try store.configure(
        filePath: blocker.appendingPathComponent("data-hub.json").path,
        initial: []
      )
    )
    try FileManager.default.removeItem(at: blocker)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    try Data(
      #"{"revision":7,"entries":{"persisted":"value"}}"#.utf8
    ).write(to: file)

    let configured = try store.configure(
      filePath: file.path,
      initial: [DataHubEntryDto(key: "seed", value: "initial")]
    )
    XCTAssertEqual(configured.revision, 8)
    XCTAssertEqual(entries(configured), ["persisted": "value", "seed": "initial"])

    let written = try store.write(key: "persisted", value: "updated", origin: "test")
    XCTAssertEqual(written, 9)
    let deleted = try store.delete(key: "seed", origin: "test")
    XCTAssertEqual(deleted, 10)

    try FileManager.default.removeItem(at: file)
    try FileManager.default.createDirectory(
      at: file,
      withIntermediateDirectories: false
    )
    let beforeFailure = store.snapshot()
    XCTAssertThrowsError(
      try store.write(key: "new", value: "must-roll-back", origin: "test")
    )
    XCTAssertEqual(store.snapshot().revision, beforeFailure.revision)
    XCTAssertEqual(entries(store.snapshot()), entries(beforeFailure))

    try FileManager.default.removeItem(at: file)
    let recovered = try store.write(key: "new", value: "saved", origin: "test")
    XCTAssertEqual(recovered, 11)
    let disk = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
      as! [String: Any]
    XCTAssertEqual((disk["revision"] as! NSNumber).int64Value, 11)
    XCTAssertEqual(disk["entries"] as? [String: String], [
      "persisted": "updated",
      "new": "saved",
    ])
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent(".data-hub.json.tmp").path
      )
    )
  }

  func testReopenRestoresMinimizedMainWindow() throws {
    let window = NSWindow(
      contentRect: NSRect(x: 40, y: 50, width: 420, height: 300),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    defer { window.close() }
    window.makeKeyAndOrderFront(nil)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    window.miniaturize(nil)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
    XCTAssertTrue(window.isMiniaturized)

    MainWindowRestorer.restoreMainWindows(in: [window])
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
    XCTAssertFalse(window.isMiniaturized)
    XCTAssertTrue(window.isVisible)
  }

  func testOverlayGeometryHitTestingAndRestore() throws {
    let initialFrame = NSRect(x: 40, y: 50, width: 420, height: 300)
    let window = NSWindow(
      contentRect: initialFrame,
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    weak var retainedContentController: NSViewController?
    autoreleasepool {
      let contentController = NSViewController()
      window.contentViewController = contentController
      retainedContentController = contentController
    }
    let flutterView = try XCTUnwrap(retainedContentController).view
    let originalFrame = window.frame
    let originalStyle = window.styleMask
    let originalLevel = window.level
    let originalCollection = window.collectionBehavior
    let originalOpaque = window.isOpaque
    let originalBackground = window.backgroundColor
    let originalShadow = window.hasShadow
    let originalMovable = window.isMovable

    let controller = MacDesktopWallpaperController(window: window)
    autoreleasepool {
      XCTAssertTrue(controller.configureOverlay(true))
    }
    XCTAssertTrue(controller.isConfigured)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    XCTAssertNotNil(retainedContentController)

    let virtualFrame = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    XCTAssertEqual(window.frame, virtualFrame)
    XCTAssertEqual(window.styleMask, [.borderless])
    XCTAssertFalse(window.isOpaque)
    XCTAssertEqual(window.backgroundColor, NSColor.clear)
    XCTAssertFalse(window.hasShadow)
    XCTAssertFalse(window.isMovable)
    let desktopLevel = NSWindow.Level(
      rawValue: Int(CGWindowLevelForKey(.desktopWindow))
    )
    let desktopIconLevel = NSWindow.Level(
      rawValue: Int(CGWindowLevelForKey(.desktopIconWindow))
    )
    XCTAssertGreaterThan(window.level.rawValue, desktopLevel.rawValue)
    XCTAssertGreaterThan(window.level.rawValue, desktopIconLevel.rawValue)
    XCTAssertLessThan(window.level.rawValue, NSWindow.Level.normal.rawValue)
    XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
    XCTAssertTrue(window.collectionBehavior.contains(.stationary))
    XCTAssertTrue(window.collectionBehavior.contains(.ignoresCycle))

    let scale = max(1, window.backingScaleFactor)
    XCTAssertTrue(
      controller.setRegion(
        [
          CardRectDto(
            x: 20 * scale,
            y: 30 * scale,
            width: 120 * scale,
            height: 90 * scale,
            radius: 12 * scale
          )
        ],
        dragging: false
      )
    )
    let content = try XCTUnwrap(window.contentView)
    XCTAssertTrue(content.acceptsFirstMouse(for: nil))
    let cardTop = window.contentRect(forFrameRect: window.frame).height - 60
    XCTAssertNotNil(hitTest(content, localPoint: NSPoint(x: 60, y: cardTop)))
    XCTAssertNil(hitTest(content, localPoint: NSPoint(x: 300, y: 200)))

    XCTAssertTrue(controller.setRegion([], dragging: true))
    XCTAssertNotNil(hitTest(content, localPoint: NSPoint(x: 300, y: 200)))

    XCTAssertTrue(controller.configureOverlay(false))
    XCTAssertFalse(controller.isConfigured)
    XCTAssertIdentical(window.contentView, flutterView)
    XCTAssertIdentical(window.contentViewController, retainedContentController)
    XCTAssertEqual(window.frame, originalFrame)
    XCTAssertEqual(window.styleMask, originalStyle)
    XCTAssertEqual(window.level, originalLevel)
    XCTAssertEqual(window.collectionBehavior, originalCollection)
    XCTAssertEqual(window.isOpaque, originalOpaque)
    XCTAssertEqual(window.backgroundColor, originalBackground)
    XCTAssertEqual(window.hasShadow, originalShadow)
    XCTAssertEqual(window.isMovable, originalMovable)
  }

  func testOverlayClearsFlutterViewBackgroundAndRestoresIt() throws {
    let window = NSWindow(
      contentRect: NSRect(x: 40, y: 50, width: 420, height: 300),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    defer { window.close() }
    let flutterController = FlutterViewController()
    window.contentViewController = flutterController
    let flutterView = try XCTUnwrap(flutterController.view)
    flutterView.wantsLayer = true
    let originalBackground = flutterController.backgroundColor
    let originalLayerBackground = flutterView.layer?.backgroundColor
    let originalLayerOpaque = flutterView.layer?.isOpaque

    let controller = MacDesktopWallpaperController(window: window)
    XCTAssertTrue(controller.configureOverlay(true))
    XCTAssertEqual(flutterController.backgroundColor, NSColor.clear)
    XCTAssertEqual(flutterView.layer?.backgroundColor, NSColor.clear.cgColor)
    XCTAssertEqual(flutterView.layer?.isOpaque, false)
    XCTAssertEqual(window.contentView?.layer?.backgroundColor, NSColor.clear.cgColor)
    XCTAssertEqual(window.contentView?.layer?.isOpaque, false)

    XCTAssertTrue(controller.configureOverlay(false))
    XCTAssertEqual(flutterController.backgroundColor, originalBackground)
    XCTAssertEqual(flutterView.layer?.backgroundColor, originalLayerBackground)
    XCTAssertEqual(flutterView.layer?.isOpaque, originalLayerOpaque)
  }

  func testWallpaperCanvasUsesRetinaPixelsAndCropsEachDisplay() throws {
    let left = MacWallpaperLayout.Display(
      id: 1,
      logicalBounds: CGRect(x: 0, y: 0, width: 1440, height: 900),
      pixelSize: CGSize(width: 2880, height: 1800),
      scale: 2,
      screen: nil
    )
    let right = MacWallpaperLayout.Display(
      id: 2,
      logicalBounds: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
      pixelSize: CGSize(width: 1920, height: 1080),
      scale: 1,
      screen: nil
    )
    let metrics = try XCTUnwrap(MacWallpaperLayout.pixelMetrics([left, right]))
    XCTAssertEqual(metrics.width, 6720)
    XCTAssertEqual(metrics.height, 2160)
    XCTAssertEqual(
      MacWallpaperLayout.cropRect(
        display: left,
        virtualBounds: CGRect(x: 0, y: 0, width: 3360, height: 1080),
        canvasScale: 2,
        imageSize: CGSize(width: 6720, height: 2160)
      ),
      CGRect(x: 0, y: 360, width: 2880, height: 1800)
    )
    XCTAssertEqual(
      MacWallpaperLayout.cropRect(
        display: right,
        virtualBounds: CGRect(x: 0, y: 0, width: 3360, height: 1080),
        canvasScale: 2,
        imageSize: CGSize(width: 6720, height: 2160)
      ),
      CGRect(x: 2880, y: 0, width: 3840, height: 2160)
    )
  }

  func testLoginItemServicePreservesStateAndPropagatesFailure() throws {
    let suite = "planstar.login-item.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let legacy = SystemLoginItemService(
      bundleIdentifier: "com.example.planstarDesktopApp",
      defaults: defaults,
      majorVersion: 12,
      legacySetEnabled: { _, _ in true }
    )
    XCTAssertFalse(legacy.isEnabled)
    try legacy.setEnabled(true)
    XCTAssertTrue(legacy.isEnabled)
    try legacy.setEnabled(false)
    XCTAssertFalse(legacy.isEnabled)

    var modernStatus: MacLoginItemModernStatus = .notRegistered
    let modern = SystemLoginItemService(
      bundleIdentifier: "com.example.planstarDesktopApp",
      defaults: defaults,
      majorVersion: 13,
      modernStatus: { modernStatus },
      modernRegister: { modernStatus = .requiresApproval },
      modernUnregister: { modernStatus = .notRegistered }
    )
    try modern.setEnabled(true)
    XCTAssertEqual(modernStatus, .requiresApproval)
    XCTAssertTrue(defaults.bool(forKey: "planstar.loginItem.com.example.planstarDesktopApp"))
    modernStatus = .enabled
    try modern.setEnabled(false)
    XCTAssertEqual(modernStatus, .notRegistered)
    XCTAssertFalse(defaults.bool(forKey: "planstar.loginItem.com.example.planstarDesktopApp"))

    var legacyShouldFail = false
    let failingLegacy = SystemLoginItemService(
      bundleIdentifier: "com.example.planstarDesktopApp",
      defaults: defaults,
      majorVersion: 12,
      legacySetEnabled: { _, _ in !legacyShouldFail }
    )
    legacyShouldFail = true
    XCTAssertThrowsError(try failingLegacy.setEnabled(true))
    XCTAssertFalse(failingLegacy.isEnabled)
    legacyShouldFail = false
    try failingLegacy.setEnabled(true)
    legacyShouldFail = true
    XCTAssertThrowsError(try failingLegacy.setEnabled(false))
    XCTAssertTrue(failingLegacy.isEnabled)

    let modernFailure = NSError(domain: "PlanstarLoginItemTest", code: 1)
    let failingModern = SystemLoginItemService(
      bundleIdentifier: "com.example.planstarDesktopApp",
      defaults: defaults,
      majorVersion: 13,
      modernStatus: { .enabled },
      modernRegister: { throw modernFailure },
      modernUnregister: { throw modernFailure }
    )
    XCTAssertThrowsError(try failingModern.setEnabled(true)) { error in
      XCTAssertEqual(error as NSError, modernFailure)
    }
    XCTAssertThrowsError(try failingModern.setEnabled(false)) { error in
      XCTAssertEqual(error as NSError, modernFailure)
    }
    XCTAssertTrue(failingModern.isEnabled)
  }

  func testLaunchAtStartupPigeonPluginRegistersTypedChannels() throws {
    let messenger = RecordingBinaryMessenger()
    let service = RecordingLoginItemService()
    let plugin = MacLaunchAtStartupPlugin(messenger: messenger, service: service)
    let codec = LaunchAtStartupHostApiSetup.codec
    let statusName =
      "dev.flutter.pigeon.planstar_desktop_app.LaunchAtStartupHostApi.isEnabled"
    let setName =
      "dev.flutter.pigeon.planstar_desktop_app.LaunchAtStartupHostApi.setEnabled"
    let statusHandler = try XCTUnwrap(messenger.handlers[statusName])
    let setHandler = try XCTUnwrap(messenger.handlers[setName])

    try withExtendedLifetime(plugin) {
      var statusReply: Data?
      statusHandler(nil) { statusReply = $0 }
      let statusEnvelope = try XCTUnwrap(
        codec.decode(try XCTUnwrap(statusReply)) as? [Any?]
      )
      XCTAssertEqual(statusEnvelope.count, 1)
      XCTAssertEqual(statusEnvelope[0] as? Bool, false)

      var successReply: Data?
      setHandler(try codec.encode([true])) { successReply = $0 }
      let successEnvelope = try XCTUnwrap(
        codec.decode(try XCTUnwrap(successReply)) as? [Any?]
      )
      XCTAssertEqual(successEnvelope.count, 1)
      XCTAssertTrue(successEnvelope[0] is NSNull)
      XCTAssertEqual(service.values, [true])
      XCTAssertTrue(service.isEnabled)

      service.failure = NSError(domain: "PlanstarLoginItemTest", code: 1)
      var failureReply: Data?
      setHandler(try codec.encode([false])) { failureReply = $0 }
      let failureEnvelope = try XCTUnwrap(
        codec.decode(try XCTUnwrap(failureReply)) as? [Any?]
      )
      XCTAssertEqual(failureEnvelope.count, 3)
      XCTAssertEqual(failureEnvelope[0] as? String, "loginItemFailed")
      XCTAssertEqual(service.values, [true, false])
      XCTAssertTrue(service.isEnabled)
    }
  }

  private func entries(_ snapshot: DataHubSnapshotDto) -> [String: String] {
    Dictionary(uniqueKeysWithValues: snapshot.entries.map { ($0.key, $0.value) })
  }

  private func hitTest(_ view: NSView, localPoint: NSPoint) -> NSView? {
    guard let superview = view.superview else { return nil }
    return view.hitTest(view.convert(localPoint, to: superview))
  }
}

private final class RecordingLoginItemService: MacLoginItemService {
  var isEnabled = false
  var values: [Bool] = []
  var failure: Error?

  func setEnabled(_ enabled: Bool) throws {
    values.append(enabled)
    if let failure {
      throw failure
    }
    isEnabled = enabled
  }
}

private final class RecordingBinaryMessenger: NSObject, FlutterBinaryMessenger {
  private(set) var handlers: [String: FlutterBinaryMessageHandler] = [:]
  private var nextConnection: Int64 = 1

  func send(onChannel channel: String, message: Data?) {}

  func send(
    onChannel channel: String,
    message: Data?,
    binaryReply callback: ((Data?) -> Void)?
  ) {
    callback?(nil)
  }

  func setMessageHandlerOnChannel(
    _ channel: String,
    binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> Int64 {
    handlers[channel] = handler
    defer { nextConnection += 1 }
    return nextConnection
  }

  func cleanUpConnection(_ connection: Int64) {}
}
