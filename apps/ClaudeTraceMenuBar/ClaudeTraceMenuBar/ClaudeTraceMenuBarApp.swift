import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var monitor: ProcessMonitor!
    var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize monitor and status bar
        monitor = ProcessMonitor()
        statusBarController = StatusBarController(monitor: monitor)
        monitor.startMonitoring()

        // Request notification permissions
        Task {
            let status = await NotificationService.shared.checkPermissionStatus()
            if status == .notDetermined {
                _ = await NotificationService.shared.requestPermission()
            }
        }
    }
}

@main
struct ClaudeTraceMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window (accessible via Cmd+,)
        Settings {
            SettingsView(monitor: appDelegate.monitor ?? ProcessMonitor())
        }
    }
}
