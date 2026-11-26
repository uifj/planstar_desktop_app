import AppKit
import CoreGraphics
import FlutterMacOS
import Foundation

private final class DesktopOverlayContentView: NSView {
  var hitPaths: [NSBezierPath] = []
  var hitsWholeWindow = false

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    let localPoint = convert(point, from: superview)
    if !hitsWholeWindow && !hitPaths.contains(where: { $0.contains(localPoint) }) {
      return nil
    }
    return super.hitTest(point)
  }
}

enum MacWallpaperLayout {
  struct Display: Equatable {
    let id: UInt32
    let logicalBounds: CGRect
    let pixelSize: CGSize
    let scale: CGFloat
    let screen: NSScreen?
  }

  static func pixelMetrics(_ displays: [Display]) -> DesktopMetricsDto? {
    guard !displays.isEmpty else { return nil }
    let bounds = displays.map(\.logicalBounds).reduce(CGRect.null) { $0.union($1) }
    guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { return nil }
    let scale = displays.map(\.scale).max() ?? 1
    return DesktopMetricsDto(
      x: Int64(bounds.minX.rounded()),
      y: Int64(bounds.minY.rounded()),
      width: Int64((bounds.width * scale).rounded()),
      height: Int64((bounds.height * scale).rounded())
    )
  }

  static func cropRect(
    display: Display,
    virtualBounds: CGRect,
    canvasScale: CGFloat,
    imageSize: CGSize
  ) -> CGRect {
    let x = (display.logicalBounds.minX - virtualBounds.minX) * canvasScale
    let width = display.logicalBounds.width * canvasScale
    let height = display.logicalBounds.height * canvasScale
    let sx = imageSize.width / (virtualBounds.width * canvasScale)
    let sy = imageSize.height / (virtualBounds.height * canvasScale)
    return CGRect(
      x: x * sx,
      y: (virtualBounds.height - display.logicalBounds.maxY + virtualBounds.minY) * canvasScale * sy,
      width: width * sx,
      height: height * sy
    ).intersection(CGRect(origin: .zero, size: imageSize)).integral
  }
}

final class MacDesktopWallpaperController {
  private weak var window: NSWindow?
  private var overlayContentView: DesktopOverlayContentView?
  private var originalContentView: NSView?
  private var originalContentViewController: NSViewController?
  private var originalFlutterController: FlutterViewController?
  private var originalFlutterBackground: NSColor?
  private var originalFlutterLayerBackground: CGColor?
  private var originalFlutterLayerOpaque: Bool?
  private var originalFrame = NSRect.zero
  private var originalStyle: NSWindow.StyleMask = []
  private var originalLevel: NSWindow.Level = .normal
  private var originalCollectionBehavior: NSWindow.CollectionBehavior = []
  private var originalOpaque = true
  private var originalBackground = NSColor.black
  private var originalShadow = true
  private var originalMovable = true
  private var rawRegions: [CardRectDto] = []
  private var dragging = false
  private var overlay = false
  private var screenObserver: NSObjectProtocol?

  var isConfigured: Bool { overlay }

  init(window: NSWindow) {
    self.window = window
    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.coverVirtualScreen()
      self?.applyRegion()
    }
  }

  deinit {
    if let screenObserver {
      NotificationCenter.default.removeObserver(screenObserver)
    }
  }

  func configureOverlay(_ enable: Bool, rect: WindowRectDto? = nil) -> Bool {
    guard let window else { return false }
    if enable == overlay {
      if enable, let rect {
        window.setFrame(
          NSRect(
            x: rect.x,
            y: rect.y,
            width: max(1, rect.width),
            height: max(1, rect.height)
          ),
          display: false
        )
        applyRegion()
      }
      return true
    }

    guard enable else {
      restore(window)
      return true
    }

    originalFrame = window.frame
    originalStyle = window.styleMask
    originalLevel = window.level
    originalCollectionBehavior = window.collectionBehavior
    originalOpaque = window.isOpaque
    originalBackground = window.backgroundColor
    originalShadow = window.hasShadow
    originalMovable = window.isMovable

    let flutterView = window.contentView
    originalContentView = flutterView
    originalContentViewController = window.contentViewController
    originalFlutterController = window.contentViewController as? FlutterViewController
    originalFlutterBackground = originalFlutterController?.backgroundColor
    flutterView?.wantsLayer = true
    if let layer = flutterView?.layer {
      originalFlutterLayerBackground = layer.backgroundColor
      originalFlutterLayerOpaque = layer.isOpaque
      layer.backgroundColor = NSColor.clear.cgColor
      layer.isOpaque = false
    }
    originalFlutterController?.backgroundColor = .clear
    let contentFrame = flutterView?.frame ?? window.contentRect(forFrameRect: window.frame)
    let container = DesktopOverlayContentView(frame: contentFrame)
    container.autoresizingMask = [.width, .height]
    container.wantsLayer = true
    container.layer?.backgroundColor = NSColor.clear.cgColor
    if let flutterView {
      flutterView.removeFromSuperview()
      flutterView.frame = container.bounds
      flutterView.autoresizingMask = [.width, .height]
      container.addSubview(flutterView)
    }
    overlayContentView = container
    window.contentView = container

    window.styleMask = [.borderless]
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.isMovable = false
    window.hidesOnDeactivate = false
    window.ignoresMouseEvents = false
    // Finder 的桌面图标层会截走桌面层窗口点击；提升一级但仍低于普通应用。
    window.level = NSWindow.Level(
      rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
    )
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    overlay = true
    if let rect {
      window.setFrame(
        NSRect(
          x: rect.x,
          y: rect.y,
          width: max(1, rect.width),
          height: max(1, rect.height)
        ),
        display: false
      )
    } else {
      coverVirtualScreen()
    }
    applyRegion()
    window.orderFrontRegardless()
    return true
  }

  func setRegion(_ rects: [CardRectDto], dragging: Bool) -> Bool {
    rawRegions = rects
    self.dragging = dragging
    applyRegion()
    return true
  }

  private func applyRegion() {
    guard let overlayContentView else { return }
    overlayContentView.hitsWholeWindow = dragging
    overlayContentView.hitPaths = dragging ? [] : makePaths()
  }

  private func makePaths() -> [NSBezierPath] {
    guard let window else { return [] }
    let scale = max(1, window.backingScaleFactor)
    let frame = window.frame
    let height = window.contentRect(forFrameRect: frame).height
    return rawRegions.compactMap { rect in
      guard rect.width > 0, rect.height > 0 else { return nil }
      let x = rect.x / scale - frame.minX
      let top = rect.y / scale
      let converted = NSRect(
        x: x,
        y: height - top - rect.height / scale,
        width: rect.width / scale,
        height: rect.height / scale
      )
      return NSBezierPath(
        roundedRect: converted,
        xRadius: max(0, rect.radius / scale),
        yRadius: max(0, rect.radius / scale)
      )
    }
  }

  private func coverVirtualScreen() {
    guard let window, overlay else { return }
    let frame = NSScreen.screens.reduce(CGRect.null) { result, screen in
      result.union(screen.frame)
    }
    guard !frame.isNull else { return }
    window.setFrame(frame, display: false)
  }

  private func restore(_ window: NSWindow) {
    if let originalContentViewController {
      window.contentViewController = originalContentViewController
    } else if let flutterView = originalContentView {
      flutterView.removeFromSuperview()
      flutterView.frame = overlayContentView?.bounds ?? flutterView.frame
      window.contentView = flutterView
    }
    originalFlutterController?.backgroundColor = originalFlutterBackground
    if let flutterView = originalContentView {
      flutterView.layer?.backgroundColor = originalFlutterLayerBackground
      if let originalFlutterLayerOpaque {
        flutterView.layer?.isOpaque = originalFlutterLayerOpaque
      }
    }
    overlayContentView = nil
    originalContentView = nil
    originalContentViewController = nil
    originalFlutterController = nil
    originalFlutterBackground = nil
    originalFlutterLayerBackground = nil
    originalFlutterLayerOpaque = nil
    window.styleMask = originalStyle
    window.level = originalLevel
    window.collectionBehavior = originalCollectionBehavior
    window.isOpaque = originalOpaque
    window.backgroundColor = originalBackground
    window.hasShadow = originalShadow
    window.isMovable = originalMovable
    window.setFrame(originalFrame, display: false)
    overlay = false
    rawRegions = []
    dragging = false
  }
}

final class MacDesktopWallpaperPlugin: NSObject, DesktopWallpaperHostApi {
  private let controller: MacDesktopWallpaperController
  private weak var window: NSWindow?
  private let messenger: FlutterBinaryMessenger

  init(window: NSWindow, messenger: FlutterBinaryMessenger) {
    self.window = window
    self.messenger = messenger
    controller = MacDesktopWallpaperController(window: window)
    super.init()
    DesktopWallpaperHostApiSetup.setUp(binaryMessenger: messenger, api: self)
  }

  deinit {
    if window != nil {
      _ = controller.configureOverlay(false)
    }
  }

  func configureOverlay(enable: Bool) throws -> Bool {
    return controller.configureOverlay(enable)
  }

  func setRegion(rects: [CardRectDto], dragging: Bool) throws -> Bool {
    controller.setRegion(rects, dragging: dragging)
  }

  func isOverlay() throws -> Bool {
    controller.isConfigured
  }

  func attach(rect: WindowRectDto?) throws -> Bool {
    controller.configureOverlay(true, rect: rect)
  }

  func detach() throws -> Bool {
    controller.configureOverlay(false)
  }

  func isAttached() throws -> Bool {
    controller.isConfigured
  }

  func setWallpaper(path: String) throws -> Bool {
    guard !path.isEmpty else { return false }
    let displays = activeDisplays()
    guard !displays.isEmpty else { return false }
    let source = URL(fileURLWithPath: path)
    guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
      return false
    }

    let bounds = displays.map(\.logicalBounds).reduce(CGRect.null) { $0.union($1) }
    let canvasScale = displays.map(\.scale).max() ?? 1
    let generatedSize = CGSize(
      width: (bounds.width * canvasScale).rounded(),
      height: (bounds.height * canvasScale).rounded()
    )
    let cropsGeneratedCanvas = source.lastPathComponent == "planstar_calendar_wallpaper.png" &&
        image.width == Int(generatedSize.width) && image.height == Int(generatedSize.height)
    let outputDirectory = source.deletingLastPathComponent()
    var applied = false
    for display in displays {
      let targetURL: URL
      if cropsGeneratedCanvas {
        let crop = MacWallpaperLayout.cropRect(
          display: display,
          virtualBounds: bounds,
          canvasScale: canvasScale,
          imageSize: CGSize(width: image.width, height: image.height)
        )
        guard let cropped = image.cropping(to: crop) else { return false }
        targetURL = outputDirectory.appendingPathComponent(
          "planstar_calendar_wallpaper_\(display.id).png"
        )
        let destination = CGImageDestinationCreateWithURL(
          targetURL as CFURL,
          "public.png" as CFString,
          1,
          nil
        )
        guard let destination else { return false }
        CGImageDestinationAddImage(destination, cropped, nil)
        guard CGImageDestinationFinalize(destination) else { return false }
      } else {
        targetURL = source
      }
      guard let screen = display.screen else { continue }
      try NSWorkspace.shared.setDesktopImageURL(targetURL, for: screen, options: [:])
      applied = true
    }
    return applied
  }

  func currentWallpaper() throws -> String {
    let screens = NSScreen.screens
    guard let screen = window?.screen ?? screens.first else { return "" }
    let urls = screens.compactMap { NSWorkspace.shared.desktopImageURL(for: $0) }
    let generatedCrops = urls.filter {
      $0.lastPathComponent.hasPrefix("planstar_calendar_wallpaper_")
    }
    if generatedCrops.count == urls.count, let crop = generatedCrops.first {
      return crop.deletingLastPathComponent()
        .appendingPathComponent("planstar_calendar_wallpaper.png").path
    }
    return NSWorkspace.shared.desktopImageURL(for: screen)?.path ?? ""
  }

  private func activeDisplays() -> [MacWallpaperLayout.Display] {
    var ids = [CGDirectDisplayID](repeating: 0, count: 32)
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(32, &ids, &count) == .success else { return [] }
    return ids.prefix(Int(count)).compactMap { id in
      let bounds = CGDisplayBounds(id)
      guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { return nil }
      let screen = NSScreen.screens.first {
        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
      }
      return MacWallpaperLayout.Display(
        id: id,
        logicalBounds: bounds,
        pixelSize: CGSize(width: CGDisplayPixelsWide(id), height: CGDisplayPixelsHigh(id)),
        scale: screen?.backingScaleFactor ?? 1,
        screen: screen
      )
    }
  }

  func desktopMetrics() throws -> DesktopMetricsDto {
    guard let metrics = MacWallpaperLayout.pixelMetrics(activeDisplays()) else {
      return DesktopMetricsDto(x: 0, y: 0, width: 0, height: 0)
    }
    return metrics
  }
}
