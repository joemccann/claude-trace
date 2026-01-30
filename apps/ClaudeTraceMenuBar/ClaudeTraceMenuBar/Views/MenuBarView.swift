import SwiftUI

struct MenuBarView: View {
    @Bindable var monitor: ProcessMonitor
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with summary
            headerSection

            Divider()
                .padding(.vertical, 4)

            // Process list or empty state
            if monitor.processes.isEmpty {
                emptyState
            } else {
                processList
            }

            Divider()
                .padding(.vertical, 4)

            // Footer with actions
            footerSection
        }
        .padding(8)
        .frame(width: 320)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Claude Processes")
                    .font(.headline)
                Spacer()
                if let lastUpdate = monitor.lastUpdate {
                    Text(lastUpdate, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                // Total CPU
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .foregroundStyle(cpuColor(for: monitor.totals.cpuPercent, aggregate: true))
                    Text(String(format: "%.1f%%", monitor.totals.cpuPercent))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(cpuColor(for: monitor.totals.cpuPercent, aggregate: true))
                }

                // Total Memory
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .foregroundStyle(memoryColor(for: monitor.totals.rssKb, aggregate: true))
                    Text(monitor.totals.rssHuman)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(memoryColor(for: monitor.totals.rssKb, aggregate: true))
                }

                Spacer()

                // Process count
                Text("\(monitor.processes.count) process\(monitor.processes.count == 1 ? "" : "es")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Error message if any
            if let error = monitor.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Process List

    private var processList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                // Use stable order to prevent UI jumping when data updates
                ForEach(monitor.sortedProcesses) { process in
                    ProcessRowView(
                        process: process,
                        cpuThreshold: monitor.perProcessCpuThreshold,
                        memoryThresholdMB: monitor.perProcessMemThresholdMB
                    )
                }
            }
        }
        .frame(maxHeight: 300)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("No Claude processes running")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack {
            // Monitoring status
            HStack(spacing: 4) {
                Circle()
                    .fill(monitor.isRunning ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(monitor.isRunning ? "Monitoring" : "Stopped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Settings button
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showingSettings) {
                SettingsView(monitor: monitor)
            }

            // Refresh button
            Button(action: {
                monitor.restartMonitoring()
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)

            // Quit button
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Color Helpers

    private func cpuColor(for value: Double, aggregate: Bool) -> Color {
        if aggregate {
            // Aggregate thresholds
            if value >= 100 { return .red }
            if value >= 50 { return .orange }
            return .primary
        } else {
            // Per-process thresholds
            if value >= 80 { return .red }
            if value >= 50 { return .orange }
            if value >= 20 { return .cyan }
            return .primary
        }
    }

    private func memoryColor(for rssKb: Int, aggregate: Bool) -> Color {
        if aggregate {
            // Aggregate: >= 2GB red, >= 1GB orange, >= 512MB cyan
            if rssKb >= 2_097_152 { return .red }
            if rssKb >= 1_048_576 { return .orange }
            if rssKb >= 524_288 { return .cyan }
            return .primary
        } else {
            // Per-process: >= 1GB red, >= 512MB orange, >= 256MB cyan
            if rssKb >= 1_048_576 { return .red }
            if rssKb >= 524_288 { return .orange }
            if rssKb >= 262_144 { return .cyan }
            return .primary
        }
    }
}

#Preview {
    let monitor = ProcessMonitor()
    return MenuBarView(monitor: monitor)
}
