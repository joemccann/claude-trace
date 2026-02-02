import Foundation
import Combine

// MARK: - JSON Data Structures (matching CLI output)

struct TraceOutput: Codable {
    let timestamp: String
    let hostname: String
    let os: String
    let osVersion: String
    let latestLocalVersion: String?
    let processCount: Int
    let orphanedCount: Int?
    let outdatedCount: Int?
    let totals: Totals
    let processes: [ProcessInfo]

    enum CodingKeys: String, CodingKey {
        case timestamp, hostname, os, processes, totals
        case osVersion = "os_version"
        case latestLocalVersion = "latest_local_version"
        case processCount = "process_count"
        case orphanedCount = "orphaned_count"
        case outdatedCount = "outdated_count"
    }
}

struct Totals: Codable, Equatable {
    let cpuPercent: Double
    let memPercent: Double
    let rssKb: Int
    let rssHuman: String

    enum CodingKeys: String, CodingKey {
        case cpuPercent = "cpu_percent"
        case memPercent = "mem_percent"
        case rssKb = "rss_kb"
        case rssHuman = "rss_human"
    }

    static let empty = Totals(cpuPercent: 0, memPercent: 0, rssKb: 0, rssHuman: "0K")
}

struct ProcessInfo: Codable, Identifiable, Equatable {
    let pid: Int
    let ppid: Int
    let cpuPercent: Double
    let memPercent: Double
    let rssKb: Int
    let vszKb: Int
    let state: String
    let elapsedTime: String
    let command: String
    let version: String?
    let isOrphaned: Bool?
    let isOutdated: Bool?
    let openFiles: Int?
    let threads: Int?
    let cwd: String?
    let project: String?
    let sessionId: String?  // From --session-id flag

    var id: Int { pid }

    enum CodingKeys: String, CodingKey {
        case pid, ppid, state, command, version, threads, cwd, project
        case cpuPercent = "cpu_percent"
        case memPercent = "mem_percent"
        case rssKb = "rss_kb"
        case vszKb = "vsz_kb"
        case elapsedTime = "elapsed_time"
        case isOrphaned = "is_orphaned"
        case isOutdated = "is_outdated"
        case openFiles = "open_files"
        case sessionId = "session_id"
    }

    /// Returns RSS in MB
    var rssMB: Double {
        Double(rssKb) / 1024.0
    }

    /// Human-readable RSS string
    var rssHuman: String {
        if rssKb >= 1_048_576 {
            return String(format: "%.1fG", Double(rssKb) / 1_048_576.0)
        } else if rssKb >= 1024 {
            return String(format: "%.1fM", Double(rssKb) / 1024.0)
        } else {
            return "\(rssKb)K"
        }
    }

    /// Display name (project name or truncated command)
    var displayName: String {
        if let project = project, !project.isEmpty {
            return project
        }
        // Extract executable name from command
        let components = command.split(separator: " ")
        if let first = components.first {
            let name = String(first)
            if let lastSlash = name.lastIndex(of: "/") {
                return String(name[name.index(after: lastSlash)...])
            }
            return name
        }
        return "claude"
    }

    /// Returns true if this is an MCP (Model Context Protocol) process
    /// Detected by --claude-in-chrome-mcp (Chrome MCP child) or --chrome-native-host (native host) flags
    var isMCPProcess: Bool {
        command.contains("--claude-in-chrome-mcp") || command.contains("--chrome-native-host")
    }

    /// Returns true if this is specifically a Chrome MCP child process (spawned by a main Claude instance)
    var isChromeMcpChild: Bool {
        command.contains("--claude-in-chrome-mcp")
    }

    /// Returns true if this is an orphaned Chrome MCP process
    var orphaned: Bool {
        isOrphaned ?? false
    }

    /// Returns true if running an outdated version
    var outdated: Bool {
        isOutdated ?? false
    }

    /// Returns true if process has any warnings
    var hasWarnings: Bool {
        orphaned || outdated
    }
}

// MARK: - Alert Info (shown when notification is clicked)

struct AlertInfo: Equatable {
    enum AlertType: String {
        case aggregateCPU = "Total CPU Exceeded"
        case aggregateMemory = "Total Memory Exceeded"
        case processCPU = "Process CPU Exceeded"
        case processMemory = "Process Memory Exceeded"
    }

    let type: AlertType
    let message: String
    let threshold: String
    let actual: String
    let processName: String?
    let pid: Int?

    var icon: String {
        switch type {
        case .aggregateCPU, .processCPU:
            return "cpu"
        case .aggregateMemory, .processMemory:
            return "memorychip"
        }
    }

    var isAggregate: Bool {
        switch type {
        case .aggregateCPU, .aggregateMemory:
            return true
        case .processCPU, .processMemory:
            return false
        }
    }
}

// MARK: - Process Monitor

@Observable
final class ProcessMonitor {
    // Current state
    var processes: [ProcessInfo] = []
    var totals: Totals = .empty
    var lastUpdate: Date?
    var isRunning = false
    var errorMessage: String?

    // Version tracking
    var latestLocalVersion: String?
    var orphanedCount: Int = 0
    var outdatedCount: Int = 0

    // Version check state
    var isCheckingVersion = false
    var versionCheckResult: VersionCheckResult?

    // Highlighted process (from notification click)
    var highlightedPid: Int?

    // Alert info (shown when notification is clicked)
    var activeAlert: AlertInfo?

    // Stable process order - preserves order to prevent UI jumping
    // PIDs are added in order of first appearance, removed when process exits
    private var stableProcessOrder: [Int] = []

    // Settings (persisted via @AppStorage in views)
    var pollingInterval: TimeInterval = 2.0
    var cpuThreshold: Double = 100.0        // Aggregate CPU threshold
    var memoryThresholdMB: Int = 2048       // Aggregate memory threshold in MB
    var perProcessCpuThreshold: Double = 80.0
    var perProcessMemThresholdMB: Int = 1024  // Per-process memory threshold in MB

    // Path to CLI tool
    private var cliPath: String {
        // Look for CLI tool relative to app bundle or in common locations
        // Priority: project path first (for development), then installed paths
        let possiblePaths = [
            // Project path (hardcoded for development)
            NSHomeDirectory() + "/dev/apps/ops/claude-trace/cli/claude-trace",
            // Development path (relative to project)
            Bundle.main.bundlePath + "/../../../../../cli/claude-trace",
            // Home directory
            NSHomeDirectory() + "/.local/bin/claude-trace",
            // Installed path (check last since it may be outdated)
            "/usr/local/bin/claude-trace",
            // Current working directory
            FileManager.default.currentDirectoryPath + "/cli/claude-trace"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Default to hoping it's in PATH
        return "claude-trace"
    }

    private var timer: Timer?
    private var notificationService: NotificationService?

    init() {
        // Load settings from UserDefaults
        loadSettings()
        Task { @MainActor [weak self] in
            self?.notificationService = NotificationService.shared
        }
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "pollingInterval") != nil {
            pollingInterval = defaults.double(forKey: "pollingInterval")
        }
        if defaults.object(forKey: "cpuThreshold") != nil {
            cpuThreshold = defaults.double(forKey: "cpuThreshold")
        }
        if defaults.object(forKey: "memoryThresholdMB") != nil {
            memoryThresholdMB = defaults.integer(forKey: "memoryThresholdMB")
        }
        if defaults.object(forKey: "perProcessCpuThreshold") != nil {
            perProcessCpuThreshold = defaults.double(forKey: "perProcessCpuThreshold")
        }
        if defaults.object(forKey: "perProcessMemThresholdMB") != nil {
            perProcessMemThresholdMB = defaults.integer(forKey: "perProcessMemThresholdMB")
        }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(pollingInterval, forKey: "pollingInterval")
        defaults.set(cpuThreshold, forKey: "cpuThreshold")
        defaults.set(memoryThresholdMB, forKey: "memoryThresholdMB")
        defaults.set(perProcessCpuThreshold, forKey: "perProcessCpuThreshold")
        defaults.set(perProcessMemThresholdMB, forKey: "perProcessMemThresholdMB")
    }

    func startMonitoring() {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil

        // Fetch immediately
        Task {
            await fetchProcessData()
        }

        // Then poll at interval
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.fetchProcessData()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }

    @MainActor
    private func fetchProcessData() async {
        do {
            let output = try await runCLI()
            let decoder = JSONDecoder()
            let traceOutput = try decoder.decode(TraceOutput.self, from: output)

            // Update stable order - preserve existing order, append new PIDs, remove dead ones
            let newPids = Set(traceOutput.processes.map { $0.pid })
            let existingPids = Set(stableProcessOrder)

            // Remove PIDs that no longer exist
            stableProcessOrder.removeAll { !newPids.contains($0) }

            // Append new PIDs (sorted by CPU for initial placement)
            let addedPids = newPids.subtracting(existingPids)
            if !addedPids.isEmpty {
                let newProcesses = traceOutput.processes
                    .filter { addedPids.contains($0.pid) }
                    .sorted { $0.cpuPercent > $1.cpuPercent }
                stableProcessOrder.append(contentsOf: newProcesses.map { $0.pid })
            }

            // Update state
            self.processes = traceOutput.processes
            self.totals = traceOutput.totals
            self.latestLocalVersion = traceOutput.latestLocalVersion
            self.orphanedCount = traceOutput.orphanedCount ?? 0
            self.outdatedCount = traceOutput.outdatedCount ?? 0
            self.lastUpdate = Date()
            self.errorMessage = nil

            // Check thresholds and send notifications
            checkThresholds()

        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// Returns processes in stable order (doesn't jump around on updates)
    var sortedProcesses: [ProcessInfo] {
        let processMap = Dictionary(uniqueKeysWithValues: processes.map { ($0.pid, $0) })
        return stableProcessOrder.compactMap { processMap[$0] }
    }

    private func runCLI() async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [cliPath, "-j", "-v"]
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: CLIError.nonZeroExit(Int(process.terminationStatus)))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @MainActor
    private func checkThresholds() {
        guard let notificationService = notificationService else { return }
        // Check aggregate CPU
        if totals.cpuPercent >= cpuThreshold {
            notificationService.sendNotification(
                type: .highAggregateCPU,
                title: "High CPU Usage",
                body: String(format: "Total Claude CPU: %.1f%%", totals.cpuPercent),
                threshold: String(format: "%.0f%%", cpuThreshold),
                actual: String(format: "%.1f%%", totals.cpuPercent)
            )
        }

        // Check aggregate memory (convert from KB to MB)
        let totalMemoryMB = totals.rssKb / 1024
        if totalMemoryMB >= memoryThresholdMB {
            notificationService.sendNotification(
                type: .highAggregateMemory,
                title: "High Memory Usage",
                body: "Total Claude RSS: \(totals.rssHuman)",
                threshold: "\(memoryThresholdMB) MB",
                actual: totals.rssHuman
            )
        }

        // Check per-process thresholds
        for process in processes {
            if process.cpuPercent >= perProcessCpuThreshold {
                notificationService.sendNotification(
                    type: .highProcessCPU(pid: process.pid),
                    title: "High Process CPU",
                    body: String(format: "%@ (PID %d): %.1f%% CPU",
                                process.displayName, process.pid, process.cpuPercent),
                    threshold: String(format: "%.0f%%", perProcessCpuThreshold),
                    actual: String(format: "%.1f%%", process.cpuPercent),
                    processName: process.displayName
                )
            }

            let processMemoryMB = process.rssKb / 1024
            if processMemoryMB >= perProcessMemThresholdMB {
                notificationService.sendNotification(
                    type: .highProcessMemory(pid: process.pid),
                    title: "High Process Memory",
                    body: "\(process.displayName) (PID \(process.pid)): \(process.rssHuman)",
                    threshold: "\(perProcessMemThresholdMB) MB",
                    actual: process.rssHuman,
                    processName: process.displayName
                )
            }

            // Check for orphaned processes
            if process.orphaned {
                notificationService.sendNotification(
                    type: .orphanedProcess(pid: process.pid),
                    title: "Orphaned Process",
                    body: "\(process.displayName) (PID \(process.pid)) has PPID=1 (parent died)",
                    processName: process.displayName
                )
            }

            // Check for outdated processes
            if process.outdated {
                let versionInfo = process.version ?? "unknown"
                let latestInfo = latestLocalVersion ?? "unknown"
                notificationService.sendNotification(
                    type: .outdatedProcess(pid: process.pid),
                    title: "Outdated Claude Version",
                    body: "\(process.displayName) (PID \(process.pid)) is running v\(versionInfo) (latest: v\(latestInfo))",
                    threshold: latestInfo,
                    actual: versionInfo,
                    processName: process.displayName
                )
            }
        }
    }
}

// MARK: - Version Check Result

enum VersionCheckResult: Equatable {
    case upToDate(version: String)
    case updateAvailable(current: String, latest: String)
    case error(message: String)

    var isUpToDate: Bool {
        if case .upToDate = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .upToDate(let version):
            return "Running latest version (\(version))"
        case .updateAvailable(let current, let latest):
            return "Update available: \(current) → \(latest)"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - Process Monitor Extensions

extension ProcessMonitor {
    /// Kill a Claude process
    @MainActor
    func killProcess(pid: Int, force: Bool = false) async -> Bool {
        let args = force ? [cliPath, "-K", "\(pid)", "-9"] : [cliPath, "-K", "\(pid)"]

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = args
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Check for Claude Code updates
    @MainActor
    func checkForUpdates() async {
        isCheckingVersion = true
        versionCheckResult = nil

        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [cliPath, "--check-version"]
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""

                    if output.contains("latest version") || output.contains("newer than npm") {
                        // Extract version from output
                        let version = self.latestLocalVersion ?? "unknown"
                        continuation.resume(returning: VersionCheckResult.upToDate(version: version))
                    } else if output.contains("Update available") {
                        // Parse current and latest versions
                        if let match = output.range(of: #"(\d+\.\d+\.\d+) → (\d+\.\d+\.\d+)"#, options: .regularExpression) {
                            let versionStr = String(output[match])
                            let parts = versionStr.split(separator: " ")
                            if parts.count >= 3 {
                                let current = String(parts[0])
                                let latest = String(parts[2])
                                continuation.resume(returning: VersionCheckResult.updateAvailable(current: current, latest: latest))
                            } else {
                                continuation.resume(returning: VersionCheckResult.updateAvailable(
                                    current: self.latestLocalVersion ?? "unknown",
                                    latest: "newer"
                                ))
                            }
                        } else {
                            continuation.resume(returning: VersionCheckResult.updateAvailable(
                                current: self.latestLocalVersion ?? "unknown",
                                latest: "newer"
                            ))
                        }
                    } else if output.contains("Error") || process.terminationStatus != 0 {
                        continuation.resume(returning: VersionCheckResult.error(message: "Failed to check version"))
                    } else {
                        continuation.resume(returning: VersionCheckResult.upToDate(version: self.latestLocalVersion ?? "unknown"))
                    }
                } catch {
                    continuation.resume(returning: VersionCheckResult.error(message: error.localizedDescription))
                }
            }
        }

        isCheckingVersion = false
        versionCheckResult = result
    }

    /// Upgrade Claude Code to latest version
    @MainActor
    func upgradeClaudeCode() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let process = Process()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [cliPath, "--upgrade"]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Kill all orphaned processes
    @MainActor
    func killAllOrphaned(force: Bool = false) async -> Int {
        let orphanedPids = processes.filter { $0.orphaned }.map { $0.pid }
        var killed = 0
        for pid in orphanedPids {
            if await killProcess(pid: pid, force: force) {
                killed += 1
            }
        }
        return killed
    }

    /// Get all orphaned processes
    var orphanedProcesses: [ProcessInfo] {
        processes.filter { $0.orphaned }
    }

    /// Get all outdated processes
    var outdatedProcesses: [ProcessInfo] {
        processes.filter { $0.outdated }
    }
}

// MARK: - Errors

enum CLIError: LocalizedError {
    case nonZeroExit(Int)
    case notFound

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let code):
            return "CLI exited with code \(code)"
        case .notFound:
            return "claude-trace CLI not found"
        }
    }
}
