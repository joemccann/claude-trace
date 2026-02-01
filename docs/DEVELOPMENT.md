# Development Guide

## Project Structure

```
claude-trace/
├── cli/                          # Command-line tools
│   ├── claude-trace              # Bash script - real-time monitor
│   ├── src/main.rs               # Rust binary - deep diagnostics
│   ├── Cargo.toml                # Rust dependencies
│   └── tests/                    # CLI tests (bats-core)
├── apps/
│   └── ClaudeTraceMenuBar/       # macOS SwiftUI app
│       ├── ClaudeTraceMenuBar.xcodeproj/
│       └── ClaudeTraceMenuBar/
│           ├── ClaudeTraceMenuBarApp.swift
│           ├── Models/ProcessMonitor.swift
│           ├── Views/
│           └── Services/
├── docs/                         # Documentation
├── assets/                       # Images and screenshots
└── dev.sh                        # Development script
```

## Quick Start

```bash
# Clone
git clone https://github.com/joemccann/claude-trace.git
cd claude-trace

# Build and install
./dev.sh deploy
```

## Development Commands

```bash
./dev.sh              # Show status
./dev.sh deploy       # Build CLI + app, install to /Applications
./dev.sh trace        # Run claude-trace
./dev.sh trace -v     # Verbose mode
./dev.sh clean        # Clean build artifacts
./dev.sh test         # Run all tests
./dev.sh test-cli     # Run CLI tests only
./dev.sh test-app     # Run Swift tests only
```

## Building Components

### CLI (Bash)

The Bash script runs as-is. For the Rust diagnostics tool:

```bash
cd cli
cargo build --release
```

### Menu Bar App (Swift)

Via Xcode:
```bash
open apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar.xcodeproj
# Build: Cmd+B
# Run: Cmd+R
```

Via command line:
```bash
xcodebuild -project apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar.xcodeproj \
  -scheme ClaudeTraceMenuBar \
  -configuration Release \
  build
```

## Testing

### CLI Tests (bats-core)

```bash
# Install bats-core
brew install bats-core

# Run tests
./dev.sh test-cli
# Or directly:
bats cli/tests/claude-trace.bats
```

### Swift Tests

```bash
./dev.sh test-app
# Or directly:
cd apps/ClaudeTraceMenuBar/ClaudeTraceMenuBarTests
swift test
```

## Feature Parity

**IMPORTANT**: The CLI and menu bar app share a JSON contract. When modifying JSON output:

1. Update `output_json()` in `cli/claude-trace`
2. Update `TraceOutput` and `ProcessInfo` structs in `ProcessMonitor.swift`
3. Update any views that display the new data

### Current JSON Fields

**TraceOutput**: `timestamp`, `hostname`, `os`, `os_version`, `latest_local_version`, `process_count`, `orphaned_count`, `outdated_count`, `totals`, `processes`

**ProcessInfo**: `pid`, `ppid`, `cpu_percent`, `mem_percent`, `rss_kb`, `vsz_kb`, `state`, `elapsed_time`, `command`, `version`, `is_orphaned`, `is_outdated`, `open_files`, `threads`, `cwd`, `project`, `session_id`

## Code Conventions

### Bash (`cli/claude-trace`)

- `set -euo pipefail` for strict error handling
- Functions prefixed descriptively: `get_*`, `print_*`, `output_*`
- Color output via ANSI codes

### Rust (`cli/src/main.rs`)

- `clap` derive macros for CLI parsing
- `serde` for JSON serialization
- `anyhow::Result` for error handling
- Diagnostics have severity levels: high, medium, low

### Swift (`apps/ClaudeTraceMenuBar/`)

- SwiftUI with `@Observable` macro
- `@AppStorage` for persisting preferences
- Background threads for CLI calls

## System-Wide CLI Sync

The macOS app may use `/usr/local/bin/claude-trace` if it exists. After modifying the CLI:

```bash
sudo cp ./cli/claude-trace /usr/local/bin/claude-trace
```

The app searches for the CLI in this order:
1. `~/dev/apps/ops/claude-trace/cli/claude-trace`
2. Bundle-relative path
3. `~/.local/bin/claude-trace`
4. `/usr/local/bin/claude-trace`
5. `claude-trace` in PATH

## Adding Features

### New CLI Flag

1. Add case in argument parsing loop in `cli/claude-trace`
2. Update `show_help()`
3. Add corresponding feature in menu bar app if applicable

### New Diagnostic Check

1. Add detection logic in `cli/src/main.rs`
2. Create a `Diagnosis` struct with severity, issue, recommendation
3. Add to diagnostic report aggregation

### New Menu Bar Feature

1. Add state to `ProcessMonitor.swift`
2. Create/update views in `Views/`
3. For notifications, update `NotificationService.swift`
4. Persist settings with `@AppStorage`

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+
- Rust 1.70+
- Bash 4.0+

## Dependencies

### CLI Tools
- `ps`, `lsof`, `sample`, `vm_stat`, `memory_pressure`
- `dtruss`, `dtrace`, `fs_usage` (for diagnostics)

### Rust Crates
- clap, serde, serde_json, chrono, colored, regex, anyhow, inferno

### Swift
- SwiftUI, UNUserNotificationCenter, SMAppService
