import SwiftUI

@main
struct ClaudeTraceMenuBarApp: App {
    @State private var monitor = ProcessMonitor()

    init() {
        // Request notification permissions on first launch
        Task {
            let status = await NotificationService.shared.checkPermissionStatus()
            if status == .notDetermined {
                _ = await NotificationService.shared.requestPermission()
            }
        }

        // Listen for notification actions
        NotificationCenter.default.addObserver(
            forName: .openMenuBarPopover,
            object: nil,
            queue: .main
        ) { _ in
            // The MenuBarExtra will handle showing its content
            // This is primarily for future extensibility
        }
    }

    var body: some Scene {
        // Menu bar item
        MenuBarExtra {
            MenuBarView(monitor: monitor)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        // Settings window (accessible via Cmd+,)
        Settings {
            SettingsView(monitor: monitor)
        }
    }

    // MARK: - Menu Bar Label

    @ViewBuilder
    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "waveform.path.ecg")

            if monitor.processes.isEmpty {
                // No processes
            } else if monitor.totals.cpuPercent >= 100 {
                // High CPU indicator
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            } else if monitor.totals.cpuPercent >= 50 {
                // Medium CPU indicator
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }
        }
        .onAppear {
            monitor.startMonitoring()
        }
    }
}
