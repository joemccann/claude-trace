# Claude Code Project Instructions

## Project Overview

**claude-trace** is a diagnostic toolkit for monitoring and analyzing Claude Code CLI process resource usage on macOS. It uses a hybrid Bash + Rust + Swift architecture for fast monitoring, deep diagnostics, and native macOS integration.

## Architecture

```
claude-trace/
├── cli/                          # Command-line tools
│   ├── claude-trace              # Bash script - real-time process monitor
│   ├── src/main.rs               # Rust binary source - deep diagnostic analysis
│   ├── Cargo.toml                # Rust dependencies
│   └── Cargo.lock                # Dependency lockfile
├── apps/
│   └── ClaudeTraceMenuBar/       # macOS SwiftUI menu bar app
│       ├── ClaudeTraceMenuBar.xcodeproj/
│       └── ClaudeTraceMenuBar/
│           ├── ClaudeTraceMenuBarApp.swift
│           ├── Models/ProcessMonitor.swift
│           ├── Views/
│           │   ├── MenuBarView.swift
│           │   ├── ProcessRowView.swift
│           │   └── SettingsView.swift
│           ├── Services/NotificationService.swift
│           └── Assets.xcassets/
├── README.md
├── CLAUDE.md
└── .gitignore
```

### Tool Responsibilities

| Tool | Language | Purpose |
|------|----------|---------|
| `claude-trace` | Bash | Fast, lightweight real-time monitoring with watch mode |
| `claude-diagnose` | Rust | Deep analysis: stack sampling, FD analysis, DTrace tracing, flamegraphs |
| `ClaudeTraceMenuBar` | Swift | Native macOS menu bar app with notifications |

## Feature Parity Requirements

**IMPORTANT**: The CLI (`cli/claude-trace`) and macOS menu bar app (`apps/ClaudeTraceMenuBar/`) must maintain feature parity. Any feature added to one must be implemented in the other.

### System-Wide CLI Sync (CRITICAL)

**WARNING**: There may be an older version of `claude-trace` installed at `/usr/local/bin/claude-trace`. The macOS app will use this outdated version if it exists, causing features to not work!

**After modifying `cli/claude-trace`, ALWAYS update the system-wide installation:**

```bash
# Update the system-wide CLI
sudo cp ./cli/claude-trace /usr/local/bin/claude-trace

# Verify it was updated (check file size and date)
ls -la /usr/local/bin/claude-trace
ls -la ./cli/claude-trace
```

The macOS app searches for the CLI in this order:
1. `~/dev/apps/ops/claude-trace/cli/claude-trace` (project path)
2. Bundle-relative path (for development)
3. `~/.local/bin/claude-trace`
4. `/usr/local/bin/claude-trace`
5. Falls back to `claude-trace` in PATH

### Before Every Commit

Run this checklist before committing changes:

1. **Feature Parity Check**
   - [ ] If CLI was modified, are equivalent changes made to the macOS app?
   - [ ] If macOS app was modified, are equivalent changes made to the CLI?
   - [ ] Do both tools produce consistent JSON output fields?

2. **CLI Sync Check**
   - [ ] If CLI was modified, update system-wide: `sudo cp ./cli/claude-trace /usr/local/bin/claude-trace`
   - [ ] Verify versions match: compare `ls -la` output for both files

3. **Build Verification**
   - [ ] CLI runs without errors: `./cli/claude-trace --help`
   - [ ] macOS app builds: `xcodebuild -project apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar.xcodeproj -scheme ClaudeTraceMenuBar build`

4. **Test Coverage**
   - [ ] CLI tested: `./cli/claude-trace`, `./cli/claude-trace -j | jq .`, `./cli/claude-trace -v`
   - [ ] New CLI flags tested with `--help` and actual usage
   - [ ] macOS app tested manually or via Xcode tests

5. **Documentation**
   - [ ] README.md updated if user-facing features changed
   - [ ] CLAUDE.md updated if architecture/conventions changed
   - [ ] CLI `--help` output updated for new flags
   - [ ] Output Fields table updated if JSON schema changed

### Shared Data Contract

The macOS app parses JSON from the CLI. When modifying JSON output:
1. Update `output_json()` in `cli/claude-trace`
2. Update `TraceOutput` and `ProcessInfo` structs in `ProcessMonitor.swift`
3. Update any views that display the new data

### Current JSON Fields (keep in sync)

**TraceOutput**: `timestamp`, `hostname`, `os`, `os_version`, `latest_local_version`, `process_count`, `orphaned_count`, `outdated_count`, `totals`, `processes`

**ProcessInfo**: `pid`, `ppid`, `cpu_percent`, `mem_percent`, `rss_kb`, `vsz_kb`, `state`, `elapsed_time`, `command`, `version`, `is_orphaned`, `is_outdated`, `open_files`, `threads`, `cwd`, `project`, `session_id`

## Build Commands

```bash
# Build the Rust diagnostic binary
cd cli && cargo build --release

# Run the Bash monitor
./cli/claude-trace

# Run the Rust diagnostics
./cli/target/release/claude-diagnose

# Build the menu bar app (via Xcode)
open apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar.xcodeproj
# Or via command line:
xcodebuild -project apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar.xcodeproj -scheme ClaudeTraceMenuBar -configuration Release build
```

## Key Dependencies

### CLI Tools
- **macOS system tools**: `ps`, `lsof`, `sample`, `vm_stat`, `memory_pressure`, `dtruss`, `dtrace`, `fs_usage`
- **Rust crates**: clap (CLI), serde/serde_json (JSON), chrono (timestamps), colored (terminal output), regex, anyhow, inferno (flamegraphs)

### Menu Bar App
- **Framework**: SwiftUI (macOS 14.0+)
- **APIs**: MenuBarExtra, UNUserNotificationCenter, SMAppService, @Observable

## Code Conventions

### Bash (`cli/claude-trace`)
- Use `set -euo pipefail` for strict error handling
- Functions prefixed descriptively: `get_*`, `print_*`, `output_*`
- Support both Darwin (macOS) and Linux where feasible
- Color output via ANSI codes: RED (>=80% CPU), YELLOW (>=50%), CYAN (>=20%)
- Verbose mode (`-v`) adds: thread count, open files, working directory (CWD), and project name

### Rust (`cli/src/main.rs`)
- Use `clap` derive macros for CLI argument parsing
- Structured data with `serde` for JSON serialization
- Error handling via `anyhow::Result`
- Diagnostics have severity levels: high, medium, low

### Swift (`apps/ClaudeTraceMenuBar/`)
- Use SwiftUI with `@Observable` macro for state management
- Use `@AppStorage` for persisting user preferences
- Follow Apple Human Interface Guidelines for menu bar apps
- Keep the main thread responsive - run CLI calls on background threads

## Testing

```bash
# Test Bash script
./cli/claude-trace --help
./cli/claude-trace -v
./cli/claude-trace -j | jq .

# Test Rust binary
cd cli && cargo test
./cli/target/release/claude-diagnose --help
./cli/target/release/claude-diagnose -d -s

# Test Swift app
# Open Xcode project and run tests (Cmd+U)
# Or via command line:
xcodebuild -project apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar.xcodeproj -scheme ClaudeTraceMenuBar test
```

## Common Tasks

### Adding a new diagnostic check
1. Add detection logic in `cli/src/main.rs` within appropriate analysis function
2. Create a `Diagnosis` struct with severity, issue, and recommendation
3. Add to the diagnostic report aggregation

### Adding new CLI flags
- **Bash**: Add case in argument parsing loop, update `show_help()`
- **Rust**: Add field to `Cli` struct with `#[arg(...)]` attribute

### Modifying process discovery
- Location: `get_claude_pids()` in Bash, `get_claude_pids_filtered()` in Rust
- Pattern matches against the COMMAND field specifically (not full ps line) to avoid false positives
- **Matches:**
  - `^claude\s` or `^claude$` - the CLI binary as direct command
  - `/claude\s` - the CLI binary with full path
  - `.local/share/claude/` - Claude's Node.js runtime
  - `/anthropic/` - Anthropic binaries
- **Does NOT match:**
  - Apps with "claude" only in arguments (e.g., workspace paths, folder names)
  - Scripts in directories named "claude" unless they ARE the claude binary

### Adding new DTrace analysis
1. Add syscall detection in `parse_dtruss_output()` or create specialized extractor
2. Update `analyze_dtrace_issues()` with new diagnostic patterns
3. Add new fields to `DtraceResult` struct if needed
4. Update `print_report()` to display new data

### Modifying flamegraph categories
- Edit `categorize_syscall()` in `cli/src/main.rs` to adjust syscall groupings
- Categories: file, network, memory, process, event, time, ipc, other

### Adding menu bar app features
1. Add new state properties to `ProcessMonitor.swift`
2. Create/update views in the `Views/` directory
3. For new notification types, update `NotificationService.swift`
4. Persist settings with `@AppStorage` or UserDefaults

## Output Fields

### Standard Mode (`cli/claude-trace`)
| Field | Description |
|-------|-------------|
| PID | Process ID |
| PPID | Parent Process ID |
| CPU% | CPU utilization percentage |
| MEM% | Memory utilization percentage |
| RSS | Resident Set Size (physical memory) |
| STATE | Process state (R=running, S=sleeping, S+=foreground) |
| TIME | Cumulative CPU time |
| COMMAND | Process command/arguments (truncated) |

### Verbose Mode (`cli/claude-trace -v`)
| Field | Description |
|-------|-------------|
| PID | Process ID |
| PPID | Parent Process ID |
| CPU% | CPU utilization percentage |
| MEM% | Memory utilization percentage |
| RSS | Resident Set Size (physical memory) |
| STATE | Process state |
| THRDS | Thread count |
| TIME | Cumulative CPU time |
| PROJECT | Project name (derived from working directory basename) |
| CWD | Current working directory (absolute path where Claude is running) |

### JSON Output (`-j -v`)
Additional fields in verbose JSON: `open_files`, `threads`, `cwd`, `project`

## Menu Bar App Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Polling Interval | 2 sec | How often to refresh process data |
| Aggregate CPU Threshold | 100% | Notify when total CPU exceeds this |
| Aggregate Memory Threshold | 2048 MB | Notify when total RSS exceeds this |
| Per-Process CPU Threshold | 80% | Notify when any process exceeds this |
| Per-Process Memory Threshold | 1024 MB | Notify when any process exceeds this |
| Notification Throttle | 60 sec | Minimum time between same notification type |

## Platform Notes

- **Primary platform**: macOS (Darwin)
- **Menu bar app**: Requires macOS 14.0 (Sonoma) or later for @Observable macro
- **macOS-specific**: `sample` command for stack profiling, `memory_pressure` for system memory state
- **Linux compatibility**: Bash script has OS detection, Rust binary is macOS-focused, Swift app is macOS-only

## Debugging Tips

1. **Quick scan**: `./cli/claude-trace` to see all Claude processes
2. **Watch mode**: `./cli/claude-trace -w 2` for continuous monitoring
3. **Project view**: `./cli/claude-trace -v` to see working directory and project name for each process
4. **Deep dive**: `./cli/target/release/claude-diagnose --pid <PID> -d -s --sample-duration 10`
5. **JSON pipeline**: `./cli/claude-trace -j | jq '.processes[] | select(.cpu > 50)'`
6. **Filter by project**: `./cli/claude-trace -j -v | jq '.processes[] | select(.project == "myproject")'`
7. **Syscall tracing**: `sudo ./cli/target/release/claude-diagnose --pid <PID> -D --duration 10`
8. **I/O analysis**: `sudo ./cli/target/release/claude-diagnose --pid <PID> -D --io`
9. **Network analysis**: `sudo ./cli/target/release/claude-diagnose --pid <PID> -D --network`
10. **Flamegraph**: `sudo ./cli/target/release/claude-diagnose --pid <PID> -D --flamegraph -o trace.svg`
11. **Uninstall app**: `./cli/claude-trace --uninstall-app` to remove all menu bar app installations

## Performance Considerations

- Bash script is intentionally lightweight for frequent polling
- Verbose mode (`-v`) adds `lsof` calls per process which increases execution time
- Rust binary uses LTO and stripping for optimized binary size
- Stack sampling (`sample`) is expensive - use judiciously with `--sample-duration`
- DTrace/dtruss adds overhead to traced process - keep `--duration` reasonable (5-30s)
- Flamegraph generation is CPU-intensive for large traces
- `fs_usage` fallback is less precise but has lower overhead than full DTrace
- Menu bar app polls in background - adjust interval based on needs vs. battery life
