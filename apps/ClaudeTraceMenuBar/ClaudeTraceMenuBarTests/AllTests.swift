import XCTest

// =============================================================================
// Standalone Unit Tests for claude-trace macOS App Data Models
// =============================================================================
//
// These tests verify:
// - JSON parsing from CLI output
// - Computed properties (display names, flags, formatting)
// - Equatable conformance
// - Version check result handling
//
// Run with: swift test (from ClaudeTraceMenuBarTests directory)
// =============================================================================

// MARK: - ProcessInfo Tests

final class ProcessInfoTests: XCTestCase {

    // MARK: - JSON Decoding

    func testDecodingFullJSON() throws {
        let json = """
        {
          "pid": 12345,
          "ppid": 12300,
          "cpu_percent": 25.5,
          "mem_percent": 1.2,
          "rss_kb": 524288,
          "vsz_kb": 1048576,
          "state": "S+",
          "elapsed_time": "01:23:45",
          "command": "/Users/test/.local/share/claude/versions/2.1.29/node cli.js",
          "version": "2.1.29",
          "is_orphaned": false,
          "is_outdated": false,
          "open_files": 42,
          "threads": 8,
          "cwd": "/Users/test/projects/myproject",
          "project": "myproject",
          "session_id": "abc123"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let process = try decoder.decode(TestProcessInfo.self, from: json)

        XCTAssertEqual(process.pid, 12345)
        XCTAssertEqual(process.ppid, 12300)
        XCTAssertEqual(process.cpuPercent, 25.5)
        XCTAssertEqual(process.project, "myproject")
    }

    func testDecodingMinimalJSON() throws {
        let json = """
        {
          "pid": 12345,
          "ppid": 12300,
          "cpu_percent": 0.0,
          "mem_percent": 0.0,
          "rss_kb": 1024,
          "vsz_kb": 2048,
          "state": "S",
          "elapsed_time": "00:00:01",
          "command": "claude"
        }
        """.data(using: .utf8)!

        let process = try JSONDecoder().decode(TestProcessInfo.self, from: json)

        XCTAssertEqual(process.pid, 12345)
        XCTAssertNil(process.version)
        XCTAssertNil(process.project)
    }

    // MARK: - Display Name

    func testDisplayNameWithProject() {
        let p = TestProcessInfo.sample(project: "my-project")
        XCTAssertEqual(p.displayName, "my-project")
    }

    func testDisplayNameFromPath() {
        let p = TestProcessInfo.sample(command: "/usr/local/bin/node", project: nil)
        XCTAssertEqual(p.displayName, "node")
    }

    func testDisplayNameFallback() {
        let p = TestProcessInfo.sample(command: "", project: nil)
        XCTAssertEqual(p.displayName, "claude")
    }

    // MARK: - MCP Detection

    func testIsMCPWithChromeNativeHost() {
        let p = TestProcessInfo.sample(command: "/path/to/node --chrome-native-host")
        XCTAssertTrue(p.isMCPProcess)
    }

    func testIsMCPWithChromeMcp() {
        let p = TestProcessInfo.sample(command: "/path/to/node --claude-in-chrome-mcp")
        XCTAssertTrue(p.isMCPProcess)
        XCTAssertTrue(p.isChromeMcpChild)
    }

    func testIsNotMCP() {
        let p = TestProcessInfo.sample(command: "/path/to/node cli.js")
        XCTAssertFalse(p.isMCPProcess)
        XCTAssertFalse(p.isChromeMcpChild)
    }

    // MARK: - Orphaned/Outdated

    func testOrphanedProperty() {
        XCTAssertTrue(TestProcessInfo.sample(isOrphaned: true).orphaned)
        XCTAssertFalse(TestProcessInfo.sample(isOrphaned: false).orphaned)
        XCTAssertFalse(TestProcessInfo.sample(isOrphaned: nil).orphaned)
    }

    func testOutdatedProperty() {
        XCTAssertTrue(TestProcessInfo.sample(isOutdated: true).outdated)
        XCTAssertFalse(TestProcessInfo.sample(isOutdated: false).outdated)
        XCTAssertFalse(TestProcessInfo.sample(isOutdated: nil).outdated)
    }

    func testHasWarnings() {
        XCTAssertTrue(TestProcessInfo.sample(isOrphaned: true, isOutdated: false).hasWarnings)
        XCTAssertTrue(TestProcessInfo.sample(isOrphaned: false, isOutdated: true).hasWarnings)
        XCTAssertFalse(TestProcessInfo.sample(isOrphaned: false, isOutdated: false).hasWarnings)
    }

    // MARK: - RSS Formatting

    func testRSSHumanKB() {
        XCTAssertEqual(TestProcessInfo.sample(rssKb: 512).rssHuman, "512K")
    }

    func testRSSHumanMB() {
        XCTAssertEqual(TestProcessInfo.sample(rssKb: 262144).rssHuman, "256.0M")
    }

    func testRSSHumanGB() {
        XCTAssertEqual(TestProcessInfo.sample(rssKb: 1_048_576).rssHuman, "1.0G")
    }

    func testRSSMB() {
        XCTAssertEqual(TestProcessInfo.sample(rssKb: 1024).rssMB, 1.0, accuracy: 0.01)
    }

    // MARK: - Identifiable/Equatable

    func testId() {
        XCTAssertEqual(TestProcessInfo.sample(pid: 99999).id, 99999)
    }

    func testEquality() {
        let p1 = TestProcessInfo.sample(pid: 12345)
        let p2 = TestProcessInfo.sample(pid: 12345)
        XCTAssertEqual(p1, p2)
    }

    func testInequality() {
        let p1 = TestProcessInfo.sample(pid: 12345)
        let p2 = TestProcessInfo.sample(pid: 12346)
        XCTAssertNotEqual(p1, p2)
    }
}

// MARK: - Totals Tests

final class TotalsTests: XCTestCase {

    func testDecoding() throws {
        let json = """
        {
          "cpu_percent": 35.7,
          "mem_percent": 2.5,
          "rss_kb": 786432,
          "rss_human": "768.0M"
        }
        """.data(using: .utf8)!

        let totals = try JSONDecoder().decode(TestTotals.self, from: json)

        XCTAssertEqual(totals.cpuPercent, 35.7)
        XCTAssertEqual(totals.memPercent, 2.5)
        XCTAssertEqual(totals.rssKb, 786432)
        XCTAssertEqual(totals.rssHuman, "768.0M")
    }

    func testEmpty() {
        let empty = TestTotals.empty
        XCTAssertEqual(empty.cpuPercent, 0.0)
        XCTAssertEqual(empty.rssKb, 0)
    }

    func testEquality() {
        let t1 = TestTotals(cpuPercent: 50.0, memPercent: 2.0, rssKb: 524288, rssHuman: "512.0M")
        let t2 = TestTotals(cpuPercent: 50.0, memPercent: 2.0, rssKb: 524288, rssHuman: "512.0M")
        XCTAssertEqual(t1, t2)
    }
}

// MARK: - TraceOutput Tests

final class TraceOutputTests: XCTestCase {

    func testDecoding() throws {
        let json = TestFixtures.twoProcessesJSON
        let output = try JSONDecoder().decode(TestTraceOutput.self, from: json)

        XCTAssertEqual(output.timestamp, "2024-01-15T12:00:00Z")
        XCTAssertEqual(output.hostname, "test-host")
        XCTAssertEqual(output.processCount, 2)
        XCTAssertEqual(output.orphanedCount, 0)
        XCTAssertEqual(output.processes.count, 2)
    }

    func testEmptyOutput() throws {
        let json = TestFixtures.emptyJSON
        let output = try JSONDecoder().decode(TestTraceOutput.self, from: json)

        XCTAssertEqual(output.processCount, 0)
        XCTAssertTrue(output.processes.isEmpty)
    }

    func testOrphanedOutput() throws {
        let json = TestFixtures.orphanedProcessJSON
        let output = try JSONDecoder().decode(TestTraceOutput.self, from: json)

        XCTAssertEqual(output.orphanedCount, 1)
        XCTAssertTrue(output.processes[0].orphaned)
    }

    func testTotalsAggregation() throws {
        let output = try JSONDecoder().decode(TestTraceOutput.self, from: TestFixtures.twoProcessesJSON)
        XCTAssertEqual(output.totals.cpuPercent, 35.7, accuracy: 0.1)
    }
}

// MARK: - VersionCheckResult Tests

final class VersionCheckResultTests: XCTestCase {

    func testUpToDateMessage() {
        let result = TestVersionCheckResult.upToDate(version: "2.1.29")
        XCTAssertEqual(result.message, "Running latest version (2.1.29)")
        XCTAssertTrue(result.isUpToDate)
    }

    func testUpdateAvailableMessage() {
        let result = TestVersionCheckResult.updateAvailable(current: "2.1.28", latest: "2.1.29")
        XCTAssertEqual(result.message, "Update available: 2.1.28 → 2.1.29")
        XCTAssertFalse(result.isUpToDate)
    }

    func testErrorMessage() {
        let result = TestVersionCheckResult.error(message: "Network error")
        XCTAssertEqual(result.message, "Error: Network error")
        XCTAssertFalse(result.isUpToDate)
    }

    func testEquality() {
        let r1 = TestVersionCheckResult.upToDate(version: "2.1.29")
        let r2 = TestVersionCheckResult.upToDate(version: "2.1.29")
        XCTAssertEqual(r1, r2)
    }
}

// MARK: - NotificationType Tests

final class NotificationTypeTests: XCTestCase {

    func testIdentifiers() {
        XCTAssertEqual(TestNotificationType.highAggregateCPU.identifier, "aggregate_cpu")
        XCTAssertEqual(TestNotificationType.highAggregateMemory.identifier, "aggregate_memory")
        XCTAssertEqual(TestNotificationType.highProcessCPU(pid: 123).identifier, "process_cpu_123")
        XCTAssertEqual(TestNotificationType.orphanedProcess(pid: 789).identifier, "orphaned_789")
    }

    func testCategoryIdentifiers() {
        XCTAssertEqual(TestNotificationType.highAggregateCPU.categoryIdentifier, "CPU_ALERT")
        XCTAssertEqual(TestNotificationType.highAggregateMemory.categoryIdentifier, "MEMORY_ALERT")
        XCTAssertEqual(TestNotificationType.orphanedProcess(pid: 1).categoryIdentifier, "ORPHAN_ALERT")
    }

    func testHashable() {
        var set = Set<TestNotificationType>()
        set.insert(.highAggregateCPU)
        set.insert(.highAggregateMemory)
        set.insert(.highProcessCPU(pid: 123))
        XCTAssertEqual(set.count, 3)

        set.insert(.highAggregateCPU)
        XCTAssertEqual(set.count, 3)  // No duplicate
    }
}

// MARK: - CLIError Tests

final class CLIErrorTests: XCTestCase {

    func testNonZeroExitDescription() {
        let error = TestCLIError.nonZeroExit(1)
        XCTAssertEqual(error.errorDescription, "CLI exited with code 1")
    }

    func testNotFoundDescription() {
        let error = TestCLIError.notFound
        XCTAssertEqual(error.errorDescription, "claude-trace CLI not found")
    }
}

// =============================================================================
// Test Data Structures (mirror production code for standalone testing)
// =============================================================================

struct TestProcessInfo: Codable, Identifiable, Equatable {
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
    let sessionId: String?

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

    var rssMB: Double { Double(rssKb) / 1024.0 }

    var rssHuman: String {
        if rssKb >= 1_048_576 {
            return String(format: "%.1fG", Double(rssKb) / 1_048_576.0)
        } else if rssKb >= 1024 {
            return String(format: "%.1fM", Double(rssKb) / 1024.0)
        }
        return "\(rssKb)K"
    }

    var displayName: String {
        if let project = project, !project.isEmpty { return project }
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

    var isMCPProcess: Bool {
        command.contains("--claude-in-chrome-mcp") || command.contains("--chrome-native-host")
    }

    var isChromeMcpChild: Bool {
        command.contains("--claude-in-chrome-mcp")
    }

    var orphaned: Bool { isOrphaned ?? false }
    var outdated: Bool { isOutdated ?? false }
    var hasWarnings: Bool { orphaned || outdated }

    static func sample(
        pid: Int = 12345, ppid: Int = 12300, cpuPercent: Double = 25.0,
        memPercent: Double = 1.0, rssKb: Int = 262144, vszKb: Int = 524288,
        state: String = "S", elapsedTime: String = "00:30:00",
        command: String = "/Users/test/.local/share/claude/versions/2.1.29/node cli.js",
        version: String? = "2.1.29", isOrphaned: Bool? = false, isOutdated: Bool? = false,
        openFiles: Int? = 20, threads: Int? = 4, cwd: String? = "/Users/test/projects/test",
        project: String? = "test", sessionId: String? = nil
    ) -> TestProcessInfo {
        TestProcessInfo(pid: pid, ppid: ppid, cpuPercent: cpuPercent, memPercent: memPercent,
                       rssKb: rssKb, vszKb: vszKb, state: state, elapsedTime: elapsedTime,
                       command: command, version: version, isOrphaned: isOrphaned,
                       isOutdated: isOutdated, openFiles: openFiles, threads: threads,
                       cwd: cwd, project: project, sessionId: sessionId)
    }
}

struct TestTotals: Codable, Equatable {
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

    static let empty = TestTotals(cpuPercent: 0, memPercent: 0, rssKb: 0, rssHuman: "0K")
}

struct TestTraceOutput: Codable {
    let timestamp: String
    let hostname: String
    let os: String
    let osVersion: String
    let latestLocalVersion: String?
    let processCount: Int
    let orphanedCount: Int?
    let outdatedCount: Int?
    let totals: TestTotals
    let processes: [TestProcessInfo]

    enum CodingKeys: String, CodingKey {
        case timestamp, hostname, os, processes, totals
        case osVersion = "os_version"
        case latestLocalVersion = "latest_local_version"
        case processCount = "process_count"
        case orphanedCount = "orphaned_count"
        case outdatedCount = "outdated_count"
    }
}

enum TestVersionCheckResult: Equatable {
    case upToDate(version: String)
    case updateAvailable(current: String, latest: String)
    case error(message: String)

    var isUpToDate: Bool {
        if case .upToDate = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .upToDate(let version): return "Running latest version (\(version))"
        case .updateAvailable(let current, let latest): return "Update available: \(current) → \(latest)"
        case .error(let message): return "Error: \(message)"
        }
    }
}

enum TestNotificationType: Hashable {
    case highAggregateCPU
    case highAggregateMemory
    case highProcessCPU(pid: Int)
    case highProcessMemory(pid: Int)
    case orphanedProcess(pid: Int)
    case outdatedProcess(pid: Int)

    var identifier: String {
        switch self {
        case .highAggregateCPU: return "aggregate_cpu"
        case .highAggregateMemory: return "aggregate_memory"
        case .highProcessCPU(let pid): return "process_cpu_\(pid)"
        case .highProcessMemory(let pid): return "process_memory_\(pid)"
        case .orphanedProcess(let pid): return "orphaned_\(pid)"
        case .outdatedProcess(let pid): return "outdated_\(pid)"
        }
    }

    var categoryIdentifier: String {
        switch self {
        case .highAggregateCPU, .highProcessCPU: return "CPU_ALERT"
        case .highAggregateMemory, .highProcessMemory: return "MEMORY_ALERT"
        case .orphanedProcess: return "ORPHAN_ALERT"
        case .outdatedProcess: return "OUTDATED_ALERT"
        }
    }
}

enum TestCLIError: LocalizedError {
    case nonZeroExit(Int)
    case notFound

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let code): return "CLI exited with code \(code)"
        case .notFound: return "claude-trace CLI not found"
        }
    }
}

enum TestFixtures {
    static let emptyJSON = """
    {
      "timestamp": "2024-01-15T12:00:00Z",
      "hostname": "test-host",
      "os": "darwin",
      "os_version": "24.0.0",
      "latest_local_version": "2.1.29",
      "process_count": 0,
      "orphaned_count": 0,
      "outdated_count": 0,
      "totals": {"cpu_percent": 0.0, "mem_percent": 0.0, "rss_kb": 0, "rss_human": "0K"},
      "processes": []
    }
    """.data(using: .utf8)!

    static let twoProcessesJSON = """
    {
      "timestamp": "2024-01-15T12:00:00Z",
      "hostname": "test-host",
      "os": "darwin",
      "os_version": "24.0.0",
      "latest_local_version": "2.1.29",
      "process_count": 2,
      "orphaned_count": 0,
      "outdated_count": 0,
      "totals": {"cpu_percent": 35.7, "mem_percent": 2.0, "rss_kb": 786432, "rss_human": "768.0M"},
      "processes": [
        {"pid": 12345, "ppid": 12300, "cpu_percent": 25.5, "mem_percent": 1.2, "rss_kb": 524288, "vsz_kb": 1048576, "state": "S+", "elapsed_time": "01:23:45", "command": "/Users/test/.local/share/claude/versions/2.1.29/node cli.js", "version": "2.1.29", "is_orphaned": false, "is_outdated": false},
        {"pid": 12346, "ppid": 12345, "cpu_percent": 10.2, "mem_percent": 0.8, "rss_kb": 262144, "vsz_kb": 524288, "state": "S", "elapsed_time": "00:10:30", "command": "/Users/test/.local/share/claude/versions/2.1.29/node --claude-in-chrome-mcp", "version": "2.1.29", "is_orphaned": false, "is_outdated": false}
      ]
    }
    """.data(using: .utf8)!

    static let orphanedProcessJSON = """
    {
      "timestamp": "2024-01-15T12:00:00Z",
      "hostname": "test-host",
      "os": "darwin",
      "os_version": "24.0.0",
      "latest_local_version": "2.1.29",
      "process_count": 1,
      "orphaned_count": 1,
      "outdated_count": 0,
      "totals": {"cpu_percent": 15.0, "mem_percent": 2.0, "rss_kb": 1048576, "rss_human": "1.0G"},
      "processes": [
        {"pid": 12345, "ppid": 1, "cpu_percent": 15.0, "mem_percent": 2.0, "rss_kb": 1048576, "vsz_kb": 2097152, "state": "S", "elapsed_time": "02:00:00", "command": "/Users/test/.local/share/claude/versions/2.1.28/node cli.js", "version": "2.1.28", "is_orphaned": true, "is_outdated": false}
      ]
    }
    """.data(using: .utf8)!
}
