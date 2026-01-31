import SwiftUI
import AppKit

struct ProcessDetailWindow: View {
    let process: ProcessInfo
    var cpuThreshold: Double = 80.0
    var memoryThresholdMB: Int = 1024
    var onRefresh: (() -> Void)?

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
                }
                Text("PID \(String(process.pid))")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Refresh button
            if let onRefresh = onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .help("Refresh process data")
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

    // MARK: - Process Info Section

    private var processInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Process Info", icon: "info.circle")

            HStack(spacing: 24) {
                infoRow(label: "Parent PID", value: "\(process.ppid)")

                if let project = process.project, !project.isEmpty {
                    infoRow(label: "Project", value: project)
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

#Preview {
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
            command: "/Users/user/.local/share/claude/claude-node --some-arg --another-arg /Users/user/projects/very-long-project-name-here",
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
