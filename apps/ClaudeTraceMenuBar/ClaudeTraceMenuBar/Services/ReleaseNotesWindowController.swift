import AppKit
import SwiftUI

/// Controller for managing the release notes window.
/// Uses singleton pattern consistent with ProcessDetailWindowController.
@MainActor
final class ReleaseNotesWindowController {

    // MARK: - Singleton

    static let shared = ReleaseNotesWindowController()

    // MARK: - Properties

    private var window: NSWindow?
    private var hostingController: NSHostingController<ReleaseNotesView>?
    private let windowAutosaveName = "ReleaseNotesWindow"

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Shows the release notes window, creating it if needed.
    /// Fetches release notes automatically on display.
    func showWindow(monitor: ProcessMonitor) {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if window == nil {
            createWindow(monitor: monitor)
        } else {
            // Update existing window content
            let view = ReleaseNotesView(monitor: monitor)
            hostingController?.rootView = view
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes the release notes window if open.
    func closeWindow() {
        window?.close()
        window = nil
        hostingController = nil
    }

    // MARK: - Private Methods

    private func createWindow(monitor: ProcessMonitor) {
        let view = ReleaseNotesView(monitor: monitor)
        let hosting = NSHostingController(rootView: view)
        hostingController = hosting

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        newWindow.title = "Release Notes"
        newWindow.contentViewController = hosting
        newWindow.minSize = NSSize(width: 400, height: 400)
        newWindow.maxSize = NSSize(width: 800, height: 1000)
        newWindow.level = .normal
        newWindow.isReleasedWhenClosed = false
        newWindow.setContentSize(NSSize(width: 520, height: 600))
        newWindow.center()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: newWindow
        )

        window = newWindow
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else {
            return
        }

        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.willCloseNotification,
            object: window
        )

        window = nil
        hostingController = nil
    }
}
