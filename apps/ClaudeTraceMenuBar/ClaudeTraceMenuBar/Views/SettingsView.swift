import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Bindable var monitor: ProcessMonitor
    @State private var notificationsEnabled: Bool
    @State private var launchAtLogin: Bool
    @State private var showingPermissionAlert = false

    init(monitor: ProcessMonitor) {
        self.monitor = monitor
        _notificationsEnabled = State(initialValue: NotificationService.shared.notificationsEnabled)
        _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
    }

    var body: some View {
        Form {
            // Polling Settings
            Section("Monitoring") {
                HStack {
                    Text("Refresh Interval")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { monitor.pollingInterval },
                        set: { newValue in
                            monitor.pollingInterval = newValue
                            monitor.saveSettings()
                            if monitor.isRunning {
                                monitor.restartMonitoring()
                            }
                        }
                    )) {
                        Text("1 sec").tag(1.0)
                        Text("2 sec").tag(2.0)
                        Text("5 sec").tag(5.0)
                        Text("10 sec").tag(10.0)
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
            }

            // Aggregate Thresholds
            Section("Aggregate Thresholds") {
                thresholdStepper(
                    label: "CPU Warning",
                    value: Binding(
                        get: { monitor.cpuThreshold },
                        set: { monitor.cpuThreshold = $0; monitor.saveSettings() }
                    ),
                    range: 50...200,
                    step: 10,
                    suffix: "%"
                )

                thresholdStepper(
                    label: "Memory Warning",
                    value: Binding(
                        get: { Double(monitor.memoryThresholdMB) },
                        set: { monitor.memoryThresholdMB = Int($0); monitor.saveSettings() }
                    ),
                    range: 512...8192,
                    step: 256,
                    suffix: " MB"
                )
            }

            // Per-Process Thresholds
            Section("Per-Process Thresholds") {
                thresholdStepper(
                    label: "CPU Warning",
                    value: Binding(
                        get: { monitor.perProcessCpuThreshold },
                        set: { monitor.perProcessCpuThreshold = $0; monitor.saveSettings() }
                    ),
                    range: 20...100,
                    step: 10,
                    suffix: "%"
                )

                thresholdStepper(
                    label: "Memory Warning",
                    value: Binding(
                        get: { Double(monitor.perProcessMemThresholdMB) },
                        set: { monitor.perProcessMemThresholdMB = Int($0); monitor.saveSettings() }
                    ),
                    range: 256...4096,
                    step: 128,
                    suffix: " MB"
                )
            }

            // Notifications
            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue {
                            Task {
                                let granted = await NotificationService.shared.requestPermission()
                                if !granted {
                                    showingPermissionAlert = true
                                    notificationsEnabled = false
                                }
                            }
                        } else {
                            NotificationService.shared.notificationsEnabled = false
                        }
                    }

                HStack {
                    Text("Throttle Interval")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { NotificationService.shared.throttleInterval },
                        set: { NotificationService.shared.throttleInterval = $0 }
                    )) {
                        Text("30 sec").tag(30.0)
                        Text("1 min").tag(60.0)
                        Text("2 min").tag(120.0)
                        Text("5 min").tag(300.0)
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
            }

            // Startup
            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            // About
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }

                Link("View on GitHub", destination: URL(string: "https://github.com/joemccann/claude-trace")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 340, height: 520)
        .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable notifications for Claude Trace in System Settings.")
        }
    }

    // MARK: - Helper Views

    private func thresholdStepper(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 8) {
                Button(action: {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= step
                    }
                }) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(value.wrappedValue <= range.lowerBound)

                Text("\(Int(value.wrappedValue))\(suffix)")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 70, alignment: .center)

                Button(action: {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += step
                    }
                }) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
    }

    // MARK: - Launch at Login

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            launchAtLogin = !enabled // Revert
        }
    }
}

#Preview {
    SettingsView(monitor: ProcessMonitor())
}
