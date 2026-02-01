import SwiftUI

struct MenuBarView: View {
    @Bindable var monitor: ProcessMonitor
    var sizeManager: PopoverSizeManager?
    @State private var showingSettings = false
    @State private var showingVersionCheck = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Alert banner (shown when notification is clicked)
            if let alert = monitor.activeAlert {
                alertBanner(alert)
            }

            // Header with summary
            headerSection

            Divider()
                .padding(.vertical, 4)

            // Warnings section (orphaned/outdated)
            if monitor.orphanedCount > 0 || monitor.outdatedCount > 0 {
                warningsSection
            }

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Alert Banner

    private func alertBanner(_ alert: AlertInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: alert.icon)
                    .foregroundStyle(.white)
                Text(alert.type.rawValue)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button(action: { monitor.activeAlert = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Threshold")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(alert.threshold)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Actual")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(alert.actual)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.white)
                }

                if let processName = alert.processName {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Process")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(processName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
            }

            if alert.isAggregate {
                Text("Total across all Claude processes")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(alert.type == .aggregateCPU || alert.type == .processCPU ? Color.orange : Color.purple)
        )
        .padding(.bottom, 8)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Process List

    /// Computes disambiguators for processes with the same display name.
    /// Returns a dictionary mapping PID to disambiguator string (e.g., "#1", "#2").
    /// Only processes that share a display name with others get disambiguators.
    private var processDisambiguators: [Int: String] {
        let processes = monitor.sortedProcesses

        // Group by display name
        var nameGroups: [String: [ProcessInfo]] = [:]
        for process in processes {
            nameGroups[process.displayName, default: []].append(process)
        }

        // Build disambiguator map only for names with multiple processes
        var disambiguators: [Int: String] = [:]
        for (_, group) in nameGroups where group.count > 1 {
            // Sort by PID for consistent numbering
            let sorted = group.sorted { $0.pid < $1.pid }
            for (index, process) in sorted.enumerated() {
                disambiguators[process.pid] = "#\(index + 1)"
            }
        }

        return disambiguators
    }

    private var processList: some View {
        let disambiguators = processDisambiguators

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                // Use stable order to prevent UI jumping when data updates
                ForEach(monitor.sortedProcesses) { process in
                    ProcessRowView(
                        process: process,
                        cpuThreshold: monitor.perProcessCpuThreshold,
                        memoryThresholdMB: monitor.perProcessMemThresholdMB,
                        isHighlighted: monitor.highlightedPid == process.pid,
                        disambiguator: disambiguators[process.pid],
                        onKill: { pid, force in
                            Task {
                                _ = await monitor.killProcess(pid: pid, force: force)
                            }
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Warnings Section

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if monitor.orphanedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(monitor.orphanedCount) orphaned process\(monitor.orphanedCount == 1 ? "" : "es")")
                        .font(.caption)
                    Spacer()
                    Text("MCP without Claude Desktop")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if monitor.outdatedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("\(monitor.outdatedCount) outdated process\(monitor.outdatedCount == 1 ? "" : "es")")
                        .font(.caption)
                    Spacer()
                    if let version = monitor.latestLocalVersion {
                        Text("Latest: \(version)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.bottom, 4)
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
            // Quit button (moved away from resize corner)
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)

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

            // Reset size button (only if size manager is available and size has changed)
            if let sm = sizeManager,
               sm.width != PopoverSizeManager.defaultWidth || sm.height != PopoverSizeManager.defaultHeight {
                Button(action: { sm.resetToDefault() }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Reset window size")
            }

            // Version check button
            Button(action: { showingVersionCheck = true }) {
                Image(systemName: "arrow.up.circle")
            }
            .buttonStyle(.borderless)
            .help("Check for updates")
            .popover(isPresented: $showingVersionCheck) {
                versionCheckPopover
            }

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
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: - Version Check Popover

    private var versionCheckPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Claude Code Version")
                    .font(.headline)
                Spacer()
            }

            if let version = monitor.latestLocalVersion {
                HStack {
                    Text("Installed:")
                        .foregroundStyle(.secondary)
                    Text(version)
                        .font(.system(.body, design: .monospaced))
                }
            }

            if monitor.isCheckingVersion {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Checking for updates...")
                        .foregroundStyle(.secondary)
                }
            } else if let result = monitor.versionCheckResult {
                HStack(spacing: 6) {
                    Image(systemName: result.isUpToDate ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(result.isUpToDate ? .green : .orange)
                    Text(result.message)
                        .font(.caption)
                }

                if case .updateAvailable = result {
                    Button("Upgrade Now") {
                        Task {
                            let success = await monitor.upgradeClaudeCode()
                            if success {
                                await monitor.checkForUpdates()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Button("Check for Updates") {
                Task {
                    await monitor.checkForUpdates()
                }
            }
            .disabled(monitor.isCheckingVersion)
        }
        .padding()
        .frame(width: 240)
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
    let sizeManager = PopoverSizeManager()
    return ResizablePopoverContainer(sizeManager: sizeManager) {
        MenuBarView(monitor: monitor, sizeManager: sizeManager)
    }
}
