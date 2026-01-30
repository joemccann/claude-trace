import SwiftUI

struct ProcessRowView: View {
    let process: ProcessInfo
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main row
            HStack {
                // Expand/collapse button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                // Process name/project
                VStack(alignment: .leading, spacing: 1) {
                    Text(process.displayName)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)
                    Text("PID \(process.pid)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // CPU
                HStack(spacing: 2) {
                    Text(String(format: "%.1f%%", process.cpuPercent))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(cpuColor)
                }
                .frame(width: 50, alignment: .trailing)

                // Memory
                Text(process.rssHuman)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(memoryColor)
                    .frame(width: 50, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isExpanded.toggle()
            }

            // Expanded details
            if isExpanded {
                expandedDetails
                    .padding(.leading, 16)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isExpanded ? Color.secondary.opacity(0.1) : Color.clear)
        )
    }

    // MARK: - Expanded Details

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Command
            detailRow(label: "Command", value: truncatedCommand)

            // Working directory
            if let cwd = process.cwd, !cwd.isEmpty {
                detailRow(label: "Directory", value: cwd)
            }

            // State and time
            HStack(spacing: 16) {
                detailRow(label: "State", value: stateDescription)
                detailRow(label: "Time", value: process.elapsedTime)
            }

            // Threads and files (if available)
            HStack(spacing: 16) {
                if let threads = process.threads {
                    detailRow(label: "Threads", value: "\(threads)")
                }
                if let files = process.openFiles {
                    detailRow(label: "Open Files", value: "\(files)")
                }
            }

            // Memory details
            HStack(spacing: 16) {
                detailRow(label: "RSS", value: "\(process.rssKb) KB")
                detailRow(label: "VSZ", value: "\(process.vszKb) KB")
                detailRow(label: "MEM%", value: String(format: "%.2f%%", process.memPercent))
            }
        }
        .font(.caption)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Computed Properties

    private var truncatedCommand: String {
        if process.command.count > 60 {
            return String(process.command.prefix(57)) + "..."
        }
        return process.command
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

    private var cpuColor: Color {
        if process.cpuPercent >= 80 { return .red }
        if process.cpuPercent >= 50 { return .orange }
        if process.cpuPercent >= 20 { return .cyan }
        return .primary
    }

    private var memoryColor: Color {
        // >= 1GB red, >= 512MB orange, >= 256MB cyan
        if process.rssKb >= 1_048_576 { return .red }
        if process.rssKb >= 524_288 { return .orange }
        if process.rssKb >= 262_144 { return .cyan }
        return .primary
    }
}

#Preview {
    VStack {
        ProcessRowView(process: ProcessInfo(
            pid: 12345,
            ppid: 1,
            cpuPercent: 85.5,
            memPercent: 2.3,
            rssKb: 524288,
            vszKb: 1048576,
            state: "R",
            elapsedTime: "02:34:56",
            command: "/Users/user/.local/share/claude/claude-node",
            openFiles: 42,
            threads: 8,
            cwd: "/Users/user/projects/my-project",
            project: "my-project"
        ))

        ProcessRowView(process: ProcessInfo(
            pid: 12346,
            ppid: 12345,
            cpuPercent: 5.2,
            memPercent: 0.8,
            rssKb: 65536,
            vszKb: 131072,
            state: "S",
            elapsedTime: "00:05:12",
            command: "claude",
            openFiles: 12,
            threads: 4,
            cwd: nil,
            project: nil
        ))
    }
    .padding()
    .frame(width: 320)
}
