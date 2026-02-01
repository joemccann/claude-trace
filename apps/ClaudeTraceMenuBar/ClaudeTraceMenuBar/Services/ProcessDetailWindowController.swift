import AppKit
import SwiftUI

/// Controller for managing floating detail windows for process inspection.
/// Uses singleton pattern for easy access from anywhere in the app.
final class ProcessDetailWindowController {

    // MARK: - Singleton

    static let shared = ProcessDetailWindowController()

    // MARK: - Properties

    /// Currently open window, if any
    private var window: NSWindow?

    /// Hosting controller for the SwiftUI view
    private var hostingController: NSHostingController<ProcessDetailWindow>?

    /// PID of the currently displayed process
    private var currentPID: Int?

    /// Window autosave name for remembering frame between uses
    private let windowAutosaveName = "ProcessDetailWindowV2"

    /// Kill callback - set this before showing window
    var onKill: ((Int, Bool) -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Shows a detail window for the given process.
    /// If a window is already open for this PID, brings it to front.
    /// Otherwise creates or updates the window with the new process.
    /// - Parameter process: The process to display details for
    func showWindow(for process: ProcessInfo) {
        if let existingWindow = window, currentPID == process.pid {
            // Window already open for this PID - bring to front
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if window == nil {
            // Create new window
            createWindow(for: process)
        } else {
            // Update existing window with new process
            updateWindow(for: process)
        }

        currentPID = process.pid

        // Bring window to front
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes the detail window if open.
    func closeWindow() {
        window?.close()
        window = nil
        hostingController = nil
        currentPID = nil
    }

    // MARK: - Private Methods

    private func createWindow(for process: ProcessInfo) {
        // Create the SwiftUI view
        let detailView = ProcessDetailWindow(process: process, onKill: onKill)

        // Create hosting controller
        let hosting = NSHostingController(rootView: detailView)
        hostingController = hosting

        // Create window with standard chrome - use popover-aligned dimensions
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        // Configure window
        newWindow.title = "Process Details - \(process.displayName) (PID \(String(process.pid)))"
        newWindow.contentViewController = hosting
        newWindow.minSize = NSSize(width: 400, height: 450)
        newWindow.maxSize = NSSize(width: 800, height: 1000)

        // Set window level to floating but not always on top
        newWindow.level = .normal
        newWindow.isReleasedWhenClosed = false

        // Always use fixed size and center
        newWindow.setContentSize(NSSize(width: 520, height: 600))
        newWindow.center()

        // Set up close notification to clean up
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: newWindow
        )

        window = newWindow
    }

    private func updateWindow(for process: ProcessInfo) {
        // Update the SwiftUI view with new process
        let detailView = ProcessDetailWindow(process: process, onKill: onKill)
        hostingController?.rootView = detailView

        // Update window title
        window?.title = "Process Details - \(process.displayName) (PID \(String(process.pid)))"
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else {
            return
        }

        // Clean up when window is closed
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.willCloseNotification,
            object: window
        )

        window = nil
        hostingController = nil
        currentPID = nil
    }
}
