import Cocoa
import FlutterMacOS
import Foundation

typealias WindowId = String

extension WindowId {
    static func generate() -> WindowId {
        return UUID().uuidString
    }
}

class CustomWindow: NSWindow {

    init(configuration: WindowConfiguration) {
        super.init(
            contentRect: NSRect(x: 10, y: 10, width: 800, height: 600),
            styleMask: [.miniaturizable, .closable, .titled, .resizable], backing: .buffered,
            defer: false)

        self.isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

class FlutterWindow: NSObject {
    let windowId: WindowId
    let windowArgument: String
    private(set) var window: NSWindow
    private var channel: FlutterMethodChannel?
    private let flutterViewController: FlutterViewController?
    private let shutdownEngineOnClose: Bool

    private var willBecomeActiveObserver: NSObjectProtocol?
    private var didResignActiveObserver: NSObjectProtocol?
    private var closeObserver: NSObjectProtocol?

    init(windowId: WindowId, windowArgument: String, window: NSWindow, shutdownEngineOnClose: Bool = false) {
        self.windowId = windowId
        self.windowArgument = windowArgument
        self.window = window
        self.flutterViewController = window.contentViewController as? FlutterViewController
        self.shutdownEngineOnClose = shutdownEngineOnClose
        super.init()

        willBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.didChangeOcclusionState(notification)
        }

        didResignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.didChangeOcclusionState(notification)
        }

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self, windowId] _ in
            if self?.shutdownEngineOnClose == true {
                self?.shutDownEngine()
            }
            MultiWindowManager.shared.removeWindow(windowId: windowId)
        }
    }

    deinit {
        if let willBecomeActiveObserver = willBecomeActiveObserver {
            NotificationCenter.default.removeObserver(willBecomeActiveObserver)
        }
        if let didResignActiveObserver = didResignActiveObserver {
            NotificationCenter.default.removeObserver(didResignActiveObserver)
        }
        if let closeObserver = closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
    }

    @objc func didChangeOcclusionState(_ notification: Notification) {
        flutterViewController?.engine.handleDidChangeOcclusionState(notification)
    }

    func shutDownEngine() {
        flutterViewController?.engine.shutDownEngine()
    }

    func setChannel(_ channel: FlutterMethodChannel) {
        self.channel = channel
    }

    func notifyWindowEvent(_ event: String, data: [String: Any]) {
        if let channel = channel {
            channel.invokeMethod(event, arguments: data)
        } else {
            debugPrint("Channel not set for window \(windowId), cannot notify event \(event)")
        }
    }

    func handleWindowMethod(method: String, arguments: Any?, result: @escaping FlutterResult) {
        switch method {
        case "window_show":
            window.makeKeyAndOrderFront(nil)
            window.setIsVisible(true)
            NSApp.activate(ignoringOtherApps: true)
            result(nil)
        case "window_hide":
            window.orderOut(nil)
            result(nil)
        default:
            result(FlutterError(code: "-1", message: "unknown method \(method)", details: nil))
        }
    }

}
