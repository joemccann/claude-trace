import Foundation
import Combine

// MARK: - JSON Data Structures (matching CLI output)

struct TraceOutput: Codable {
    let timestamp: String
    let hostname: String
    let os: String
    let osVersion: String
    let processCount: Int
    let totals: Totals
    let processes: [ProcessInfo]

    enum CodingKeys: String, CodingKey {
        case timestamp, hostname, os, processes
        case osVersion = "os_version"
        case processCount = "process_count"
        case totals
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
    let openFiles: Int?
    let threads: Int?
    let cwd: String?
    let project: String?

    var id: Int { pid }

    enum CodingKeys: String, CodingKey {
        case pid, ppid, state, command, threads, cwd, project
        case cpuPercent = "cpu_percent"
        case memPercent = "mem_percent"
        case rssKb = "rss_kb"
        case vszKb = "vsz_kb"
        case elapsedTime = "elapsed_time"
        case openFiles = "open_files"
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

    // Settings (persisted via @AppStorage in views)
    var pollingInterval: TimeInterval = 2.0
    var cpuThreshold: Double = 100.0        // Aggregate CPU threshold
    var memoryThresholdMB: Int = 2048       // Aggregate memory threshold in MB
    var perProcessCpuThreshold: Double = 80.0
    var perProcessMemThresholdMB: Int = 1024  // Per-process memory threshold in MB

    // Path to CLI tool
    private var cliPath: String {
        // Look for CLI tool relative to app bundle or in common locations
        let possiblePaths = [
            // Development path (relative to project)
            Bundle.main.bundlePath + "/../../../../../cli/claude-trace",
            // Installed path
            "/usr/local/bin/claude-trace",
            // Home directory
            NSHomeDirectory() + "/.local/bin/claude-trace",
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
    private let notificationService = NotificationService.shared

    init() {
        // Load settings from UserDefaults
        loadSettings()
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

            // Update state
            self.processes = traceOutput.processes
            self.totals = traceOutput.totals
            self.lastUpdate = Date()
            self.errorMessage = nil

            // Check thresholds and send notifications
            checkThresholds()

        } catch {
            self.errorMessage = error.localizedDescription
        }
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

    private func checkThresholds() {
        // Check aggregate CPU
        if totals.cpuPercent >= cpuThreshold {
            notificationService.sendNotification(
                type: .highAggregateCPU,
                title: "High CPU Usage",
                body: String(format: "Total Claude CPU: %.1f%%", totals.cpuPercent)
            )
        }

        // Check aggregate memory (convert from KB to MB)
        let totalMemoryMB = totals.rssKb / 1024
        if totalMemoryMB >= memoryThresholdMB {
            notificationService.sendNotification(
                type: .highAggregateMemory,
                title: "High Memory Usage",
                body: "Total Claude RSS: \(totals.rssHuman)"
            )
        }

        // Check per-process thresholds
        for process in processes {
            if process.cpuPercent >= perProcessCpuThreshold {
                notificationService.sendNotification(
                    type: .highProcessCPU(pid: process.pid),
                    title: "High Process CPU",
                    body: String(format: "%@ (PID %d): %.1f%% CPU",
                                process.displayName, process.pid, process.cpuPercent)
                )
            }

            let processMemoryMB = process.rssKb / 1024
            if processMemoryMB >= perProcessMemThresholdMB {
                notificationService.sendNotification(
                    type: .highProcessMemory(pid: process.pid),
                    title: "High Process Memory",
                    body: "\(process.displayName) (PID \(process.pid)): \(process.rssHuman)"
                )
            }
        }
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
