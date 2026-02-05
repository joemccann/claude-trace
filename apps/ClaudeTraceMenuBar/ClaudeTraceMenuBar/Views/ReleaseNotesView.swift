import SwiftUI

/// Displays formatted release notes fetched from GitHub in a standalone window.
@MainActor
struct ReleaseNotesView: View {
    @Bindable var monitor: ProcessMonitor

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding()

            Divider()

            // Content
            if monitor.isFetchingReleaseNotes {
                loadingState
            } else if let error = monitor.releaseNotesError {
                errorState(error)
            } else if let notes = monitor.releaseNotes {
                ScrollView {
                    MarkdownContentView(content: notes)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                emptyState
            }

            Divider()

            // Footer
            footer
                .padding()
        }
        .frame(minWidth: 440, idealWidth: 520, maxWidth: 800,
               minHeight: 400, idealHeight: 600, maxHeight: 1000)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if monitor.releaseNotes == nil && !monitor.isFetchingReleaseNotes {
                await monitor.fetchReleaseNotes()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Release Notes")
                    .font(.title2)
                    .fontWeight(.bold)

                if let version = monitor.releaseNotesVersion {
                    HStack(spacing: 8) {
                        Text("v\(version)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.teal)
                            .fontWeight(.semibold)

                        if let date = monitor.releaseNotesDate {
                            Text(date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "doc.text.fill")
                .font(.title2)
                .foregroundStyle(.teal)
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Fetching release notes...")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Failed to load release notes")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await monitor.fetchReleaseNotes()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No release notes available")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let urlString = monitor.releaseNotesURL,
               let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("View on GitHub")
                    }
                    .font(.caption)
                }
            }

            Spacer()

            Button("Refresh") {
                Task {
                    monitor.releaseNotes = nil
                    monitor.releaseNotesVersion = nil
                    monitor.releaseNotesURL = nil
                    monitor.releaseNotesDate = nil
                    await monitor.fetchReleaseNotes()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Markdown Content Renderer

/// Renders markdown content as styled SwiftUI views.
/// Handles headers, code blocks, bullet/numbered lists, dividers, and inline formatting.
struct MarkdownContentView: View {
    let content: String

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Types

    private enum Block {
        case header(level: Int, text: String)
        case paragraph(text: String)
        case codeBlock(code: String)
        case listItem(text: String, indent: Int)
        case divider
        case blank
    }

    // MARK: - Parser

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        let lines = content.components(separatedBy: "\n")
        var idx = 0

        while idx < lines.count {
            let line = lines[idx]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code blocks
            if trimmed.hasPrefix("```") {
                var code = ""
                idx += 1
                while idx < lines.count {
                    let codeLine = lines[idx]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        idx += 1
                        break
                    }
                    code += (code.isEmpty ? "" : "\n") + codeLine
                    idx += 1
                }
                blocks.append(.codeBlock(code: code))
                continue
            }

            // Headers (check ### before ## before #)
            if trimmed.hasPrefix("### ") {
                blocks.append(.header(level: 3, text: String(trimmed.dropFirst(4))))
                idx += 1
                continue
            }
            if trimmed.hasPrefix("## ") {
                blocks.append(.header(level: 2, text: String(trimmed.dropFirst(3))))
                idx += 1
                continue
            }
            if trimmed.hasPrefix("# ") {
                blocks.append(.header(level: 1, text: String(trimmed.dropFirst(2))))
                idx += 1
                continue
            }

            // Horizontal rule
            if isHorizontalRule(trimmed) {
                blocks.append(.divider)
                idx += 1
                continue
            }

            // Bullet list items (- or * or +)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count / 2
                blocks.append(.listItem(text: String(trimmed.dropFirst(2)), indent: indent))
                idx += 1
                continue
            }

            // Numbered list items
            if let dotIndex = trimmed.firstIndex(of: "."),
               trimmed[trimmed.startIndex..<dotIndex].allSatisfy({ $0.isNumber }),
               !trimmed[trimmed.startIndex..<dotIndex].isEmpty,
               trimmed.index(after: dotIndex) < trimmed.endIndex,
               trimmed[trimmed.index(after: dotIndex)] == " " {
                let text = String(trimmed[trimmed.index(dotIndex, offsetBy: 2)...])
                blocks.append(.listItem(text: text, indent: 0))
                idx += 1
                continue
            }

            // Blank line
            if trimmed.isEmpty {
                blocks.append(.blank)
                idx += 1
                continue
            }

            // Paragraph (default)
            blocks.append(.paragraph(text: trimmed))
            idx += 1
        }

        return blocks
    }

    private func isHorizontalRule(_ line: String) -> Bool {
        guard line.count >= 3 else { return false }
        let chars = Set(line.filter { !$0.isWhitespace })
        return chars.count == 1 && (chars.contains("-") || chars.contains("*") || chars.contains("_"))
    }

    // MARK: - Rendering

    @ViewBuilder
    private func renderBlock(_ block: Block) -> some View {
        switch block {
        case .header(let level, let text):
            Text(text)
                .font(headerFont(level))
                .fontWeight(.bold)
                .padding(.top, level == 1 ? 12 : 8)
                .padding(.bottom, 2)

        case .paragraph(let text):
            Text(.init(text))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 1)

        case .codeBlock(let code):
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.vertical, 2)

        case .listItem(let text, let indent):
            HStack(alignment: .top, spacing: 6) {
                Text("\u{2022}")
                    .foregroundStyle(.secondary)
                Text(.init(text))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(indent * 16 + 8))

        case .divider:
            Divider()
                .padding(.vertical, 6)

        case .blank:
            Spacer()
                .frame(height: 4)
        }
    }

    private func headerFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2
        case 2: return .title3
        default: return .headline
        }
    }
}
