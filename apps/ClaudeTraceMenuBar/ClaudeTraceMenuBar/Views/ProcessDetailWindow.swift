import SwiftUI
import AppKit

struct ProcessDetailWindow: View {
    let process: ProcessInfo
    var relatedProcess: ProcessInfo?  // Parent (for Chrome MCP) or child (for main Claude)
    var cpuThreshold: Double = 80.0
    var memoryThresholdMB: Int = 1024
    var onRefresh: (() -> Void)?
    var onKill: ((Int, Bool) -> Void)?  // (pid, force)
    @State private var showKillConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection

                Divider()

                // Command Section
                commandSection

                Divider()

                // Working Directory Section
                workingDirectorySection

                Divider()

                // Metrics Grid
                metricsSection

                Divider()

                // Process Info Section
                processInfoSection

                // Related Process Section (if applicable)
                if relatedProcess != nil || process.isChromeMcpChild {
                    Divider()
                    relatedProcessSection
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(process.displayName)
                        .font(.system(.title2, weight: .semibold))

                    // MCP badge for chrome-native-host processes
                    if process.isMCPProcess {
                        Text("MCP")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.purple)
                            .clipShape(Capsule())
                    }

                    // Orphaned badge
                    if process.orphaned {
                        Text("ORPHANED")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange)
                            .clipShape(Capsule())
                            .help("This MCP process is running without Claude Desktop")
                    }

                    // Outdated badge
                    if process.outdated {
                        Text("OUTDATED")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.8))
                            .clipShape(Capsule())
                            .help("Running an older version of Claude Code")
                    }
                }
                Text("PID \(String(process.pid))")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                // Refresh button
                if let onRefresh = onRefresh {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .help("Refresh process data")
                }

                // Kill button (SIGTERM)
                if onKill != nil {
                    Button(action: { onKill?(process.pid, false) }) {
                        Image(systemName: "stop.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .help("Terminate process (SIGTERM)")

                    // Force kill button (SIGKILL)
                    Button(action: { showKillConfirmation = true }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .help("Force kill process (SIGKILL)")
                    .confirmationDialog(
                        "Force kill process \(process.pid)?",
                        isPresented: $showKillConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Force Kill", role: .destructive) {
                            onKill?(process.pid, true)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will immediately terminate \(process.displayName) without cleanup.")
                    }
                }
            }
        }
    }

    // MARK: - Command Section

    private var commandSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Command", icon: "terminal")

            HStack(alignment: .top, spacing: 8) {
                Text(process.command)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)

                Button(action: copyCommandToClipboard) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .help("Copy command to clipboard")
            }
        }
    }

    // MARK: - Working Directory Section

    private var workingDirectorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Working Directory", icon: "folder")

            if let cwd = process.cwd, !cwd.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text(cwd)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)

                    Button(action: { openInFinder(path: cwd) }) {
                        Image(systemName: "folder.badge.gearshape")
                    }
                    .buttonStyle(.bordered)
                    .help("Open in Finder")
                }
            } else {
                Text("Not available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }

    // MARK: - Metrics Section

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Metrics", icon: "chart.bar")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                metricCard(
                    label: "CPU",
                    value: String(format: "%.1f%%", process.cpuPercent),
                    icon: "cpu",
                    color: cpuColor
                )

                metricCard(
                    label: "Memory",
                    value: String(format: "%.2f%%", process.memPercent),
                    icon: "memorychip",
                    color: memoryColor
                )

                metricCard(
                    label: "RSS",
                    value: process.rssHuman,
                    icon: "arrow.up.circle",
                    color: memoryColor
                )

                metricCard(
                    label: "VSZ",
                    value: vszHuman,
                    icon: "arrow.up.arrow.down.circle",
                    color: .primary
                )

                metricCard(
                    label: "Threads",
                    value: process.threads.map { "\($0)" } ?? "N/A",
                    icon: "cpu.fill",
                    color: .primary
                )

                metricCard(
                    label: "Open Files",
                    value: process.openFiles.map { "\($0)" } ?? "N/A",
                    icon: "doc.text",
                    color: .primary
                )

                metricCard(
                    label: "State",
                    value: stateDescription,
                    icon: stateIcon,
                    color: stateColor
                )

                metricCard(
                    label: "Elapsed",
                    value: process.elapsedTime,
                    icon: "clock",
                    color: .primary
                )
            }
        }
    }

    // MARK: - Related Process Section

    private var relatedProcessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Related Process", icon: "link")

            if process.isChromeMcpChild {
                // This is a Chrome MCP child process
                if let parent = relatedProcess {
                    // Parent is alive
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Parent Claude Process")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Text(parent.displayName)
                                    .font(.system(.body, weight: .medium))
                                Text("PID \(parent.pid)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)

                    Text("This Chrome MCP process is actively serving its parent Claude instance.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    // Parent is dead - this is an orphan
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Orphaned Chrome MCP")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Text("Parent PID \(process.ppid)")
                                    .font(.system(.body, weight: .medium))
                                Text("(no longer running)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)

                    Text("The parent Claude process has exited but this Chrome MCP child is still running. Consider terminating it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let child = relatedProcess, child.isChromeMcpChild {
                // This is a main Claude process with a Chrome MCP child
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Chrome MCP Child")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Text("chrome")
                                .font(.system(.body, weight: .medium))
                            Text("MCP")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .clipShape(Capsule())
                            Text("PID \(child.pid)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)

                Text("This Claude instance has an active Chrome MCP connection for browser automation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Process Info Section

    private var processInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Process Info", icon: "info.circle")

            HStack(spacing: 24) {
                infoRow(label: "Parent PID", value: "\(process.ppid)")

                if let project = process.project, !project.isEmpty {
                    infoRow(label: "Project", value: project)
                }

                if let version = process.version, !version.isEmpty {
                    infoRow(label: "Version", value: version)
                }
            }

            // Session ID (from --session-id flag)
            if let sessionId = process.sessionId, !sessionId.isEmpty {
                HStack(spacing: 4) {
                    Text("Session:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(sessionId)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            HStack(spacing: 24) {
                infoRow(label: "RSS (KB)", value: "\(process.rssKb)")
                infoRow(label: "VSZ (KB)", value: "\(process.vszKb)")
            }
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
        }
    }

    private func metricCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
        }
    }

    // MARK: - Computed Properties

    private var vszHuman: String {
        let vszKb = process.vszKb
        if vszKb >= 1_048_576 {
            return String(format: "%.1fG", Double(vszKb) / 1_048_576.0)
        } else if vszKb >= 1024 {
            return String(format: "%.1fM", Double(vszKb) / 1024.0)
        } else {
            return "\(vszKb)K"
        }
    }

    private var stateDescription: String {
        switch process.state {
        case "R": return "Running"
        case "S": return "Sleeping"
        case "S+": return "Foreground"
        case "T": return "Stopped"
        case "Z": return "Zombie"
        case "U": return "Uninterruptible"
        default: return process.state
        }
    }

    private var stateIcon: String {
        switch process.state {
        case "R": return "play.circle.fill"
        case "S", "S+": return "moon.circle"
        case "T": return "stop.circle"
        case "Z": return "exclamationmark.triangle"
        case "U": return "hourglass"
        default: return "questionmark.circle"
        }
    }

    private var stateColor: Color {
        switch process.state {
        case "R": return .green
        case "S", "S+": return .primary
        case "T": return .orange
        case "Z": return .red
        case "U": return .yellow
        default: return .primary
        }
    }

    private var cpuColor: Color {
        if process.cpuPercent >= cpuThreshold { return .red }
        if process.cpuPercent >= cpuThreshold * 0.625 { return .orange }
        if process.cpuPercent >= cpuThreshold * 0.25 { return .cyan }
        return .primary
    }

    private var memoryColor: Color {
        let thresholdKb = memoryThresholdMB * 1024
        if process.rssKb >= thresholdKb { return .red }
        if process.rssKb >= thresholdKb / 2 { return .orange }
        if process.rssKb >= thresholdKb / 4 { return .cyan }
        return .primary
    }

    // MARK: - Actions

    private func copyCommandToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(process.command, forType: .string)
    }

    private func openInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}

// MARK: - Preview

#Preview("Main Claude with Chrome child") {
    ProcessDetailWindow(
        process: ProcessInfo(
            pid: 12345,
            ppid: 1,
            cpuPercent: 85.5,
            memPercent: 2.3,
            rssKb: 524288,
            vszKb: 2097152,
            state: "R",
            elapsedTime: "02:34:56",
            command: "claude --dangerously-skip-permissions Working in: my-project",
            version: "2.1.29",
            isOrphaned: false,
            isOutdated: false,
            openFiles: 42,
            threads: 8,
            cwd: "/Users/user/projects/my-project",
            project: "my-project",
            sessionId: "abc123-def456-789"
        ),
        relatedProcess: ProcessInfo(
            pid: 12346,
            ppid: 12345,
            cpuPercent: 0.5,
            memPercent: 0.3,
            rssKb: 65536,
            vszKb: 524288,
            state: "S",
            elapsedTime: "02:34:50",
            command: "/Users/user/.local/share/claude/versions/2.1.29 --claude-in-chrome-mcp",
            version: "2.1.29",
            isOrphaned: false,
            isOutdated: false,
            openFiles: 12,
            threads: 5,
            cwd: "/Users/user/projects/my-project",
            project: "my-project",
            sessionId: nil
        ),
        cpuThreshold: 80.0,
        memoryThresholdMB: 1024,
        onRefresh: { print("Refresh tapped") }
    )
}

#Preview("Chrome MCP with parent alive") {
    ProcessDetailWindow(
        process: ProcessInfo(
            pid: 12346,
            ppid: 12345,
            cpuPercent: 0.5,
            memPercent: 0.3,
            rssKb: 65536,
            vszKb: 524288,
            state: "S",
            elapsedTime: "02:34:50",
            command: "/Users/user/.local/share/claude/versions/2.1.29 --claude-in-chrome-mcp",
            version: "2.1.29",
            isOrphaned: false,
            isOutdated: false,
            openFiles: 12,
            threads: 5,
            cwd: "/Users/user/projects/my-project",
            project: "my-project",
            sessionId: nil
        ),
        relatedProcess: ProcessInfo(
            pid: 12345,
            ppid: 1,
            cpuPercent: 85.5,
            memPercent: 2.3,
            rssKb: 524288,
            vszKb: 2097152,
            state: "R",
            elapsedTime: "02:34:56",
            command: "claude --dangerously-skip-permissions Working in: my-project",
            version: "2.1.29",
            isOrphaned: false,
            isOutdated: false,
            openFiles: 42,
            threads: 8,
            cwd: "/Users/user/projects/my-project",
            project: "my-project",
            sessionId: "abc123-def456-789"
        ),
        cpuThreshold: 80.0,
        memoryThresholdMB: 1024,
        onRefresh: { print("Refresh tapped") }
    )
}

#Preview("Orphaned Chrome MCP") {
    ProcessDetailWindow(
        process: ProcessInfo(
            pid: 12346,
            ppid: 12345,
            cpuPercent: 0.5,
            memPercent: 0.3,
            rssKb: 65536,
            vszKb: 524288,
            state: "S",
            elapsedTime: "02:34:50",
            command: "/Users/user/.local/share/claude/versions/2.1.29 --claude-in-chrome-mcp",
            version: "2.1.29",
            isOrphaned: false,
            isOutdated: false,
            openFiles: 12,
            threads: 5,
            cwd: "/Users/user/projects/my-project",
            project: "my-project",
            sessionId: nil
        ),
        relatedProcess: nil,  // Parent is gone
        cpuThreshold: 80.0,
        memoryThresholdMB: 1024,
        onRefresh: { print("Refresh tapped") }
    )
}
