import SwiftUI
import AppKit

/// Manages the status bar item and popover using AppKit for programmatic control
class StatusBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    private var monitor: ProcessMonitor

    init(monitor: ProcessMonitor) {
        self.monitor = monitor
        super.init()
        setupStatusItem()
        setupNotificationObserver()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "Claude Trace")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 450)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarView(monitor: monitor))

        // Close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let self = self, self.popover.isShown {
                self.popover.performClose(nil)
            }
        }

        // Update icon based on monitor state
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStatusIcon()
        }
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenPopover(_:)),
            name: .openMenuBarPopover,
            object: nil
        )
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func handleOpenPopover(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            DispatchQueue.main.async { [weak self] in
                self?.showPopover()
            }
            return
        }

        // Extract PID if present
        if let pid = userInfo["pid"] as? Int {
            monitor.highlightedPid = pid

            // Clear highlight after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                if self?.monitor.highlightedPid == pid {
                    self?.monitor.highlightedPid = nil
                }
            }
        }

        // Build alert info from notification data
        if let alertTypeString = userInfo["alertType"] as? String,
           let alertType = AlertInfo.AlertType(rawValue: alertTypeString) ?? alertTypeFromString(alertTypeString) {
            let alertInfo = AlertInfo(
                type: alertType,
                message: userInfo["alertBody"] as? String ?? "",
                threshold: userInfo["threshold"] as? String ?? "N/A",
                actual: userInfo["actual"] as? String ?? "N/A",
                processName: userInfo["processName"] as? String,
                pid: userInfo["pid"] as? Int
            )
            monitor.activeAlert = alertInfo

            // Clear alert after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                if self?.monitor.activeAlert == alertInfo {
                    self?.monitor.activeAlert = nil
                }
            }
        }

        // Show the popover
        DispatchQueue.main.async { [weak self] in
            self?.showPopover()
        }
    }

    private func alertTypeFromString(_ string: String) -> AlertInfo.AlertType? {
        switch string {
        case "aggregateCPU": return .aggregateCPU
        case "aggregateMemory": return .aggregateMemory
        case "processCPU": return .processCPU
        case "processMemory": return .processMemory
        default: return nil
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }

        if monitor.processes.isEmpty {
            button.image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "Claude Trace")
        } else if monitor.totals.cpuPercent >= 100 {
            button.image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: "High CPU")
        } else if monitor.totals.cpuPercent >= 50 {
            button.image = NSImage(systemSymbolName: "waveform.path.ecg.rectangle", accessibilityDescription: "Claude Trace - Active")
        } else {
            button.image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "Claude Trace")
        }
    }

    deinit {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        NotificationCenter.default.removeObserver(self)
    }
}
