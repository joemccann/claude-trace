<p align="center">
  <img src="assets/github-banner.png" alt="Claude Trace" width="900" />
</p>

<p align="center">
  <strong>Your Claude Code is slow. Here's why.</strong>
</p>

<p align="center">
  <a href="#installation">Install</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#tools">Tools</a> •
  <a href="#menu-bar-app">Menu Bar App</a> •
  <a href="#diagnostic-workflow">Workflow</a>
</p>

---

Stop guessing why Claude Code is eating your CPU. **Claude Trace** gives you instant visibility into every Claude process running on your machine — CPU spikes, memory leaks, runaway file watchers, the works.

Built with **Bash + Rust + Swift** for zero-dependency monitoring that's as fast as the problems it finds.

## Quick Start

```bash
# See all Claude processes right now
./cli/claude-trace

# Watch mode — refreshes every 2 seconds
./cli/claude-trace -w

# Something's wrong? Go deep.
./cli/target/release/claude-diagnose --pid <PID> -d -s
```

### See Everything at a Glance

Run `./cli/claude-trace -v` to get a full picture of every Claude session on your machine — which projects they're in, how much CPU and memory they're consuming, and how long they've been running.

<p align="center">
  <img src="assets/trace-1.png" alt="Claude Trace Output" width="900" />
</p>

When aggregate CPU exceeds 100%, you'll get an instant warning with suggested diagnostic commands. No more wondering why your fan is spinning — now you know exactly which session to kill or investigate.

## Installation

```bash
# Clone the repository
git clone https://github.com/joemccann/claude-trace.git ~/claude-trace
cd ~/claude-trace

# Build the Rust diagnostic tool
cd cli && cargo build --release && cd ..

# Add to PATH
export PATH="$HOME/claude-trace/cli:$HOME/claude-trace/cli/target/release:$PATH"

# Or install the binaries system-wide
sudo cp cli/target/release/claude-diagnose /usr/local/bin/
sudo cp cli/claude-trace /usr/local/bin/
```

## Project Structure

```
claude-trace/
├── cli/                          # Command-line tools
│   ├── claude-trace              # Bash script - real-time monitor
│   ├── src/main.rs               # Rust binary source
│   ├── Cargo.toml                # Rust dependencies
│   └── target/release/
│       └── claude-diagnose       # Compiled Rust binary
├── apps/
│   └── ClaudeTraceMenuBar/       # macOS SwiftUI menu bar app
├── dev.sh                        # Development convenience script
├── README.md
└── CLAUDE.md                     # Project instructions for Claude Code
```

## Development

A convenience script is provided for building and running all tools:

```bash
./dev.sh              # Build CLI tools and show status
./dev.sh build        # Build Rust binary only
./dev.sh build-app    # Build the menu bar app (requires Xcode)
./dev.sh build-all    # Build everything
./dev.sh trace        # Run the Bash monitor (claude-trace)
./dev.sh trace -v     # Run with verbose output
./dev.sh diagnose     # Run the Rust diagnostics (claude-diagnose)
./dev.sh watch 5      # Watch mode with 5s refresh
./dev.sh run-app      # Build and launch the menu bar app
./dev.sh install      # Build and install menu bar app to /Applications
./dev.sh test         # Run tests and validate scripts
./dev.sh clean        # Clean build artifacts
```

## Tools

### `claude-trace` - Process Monitor (Bash)

Fast, lightweight Bash script for real-time process monitoring.

```bash
# One-shot process list
./cli/claude-trace

# Watch mode (refresh every 2s)
./cli/claude-trace -w

# Watch with 5s interval
./cli/claude-trace -w 5

# JSON output for scripting
./cli/claude-trace -j | jq '.totals.cpu_percent'

# Verbose mode with threads, project, and working directory
./cli/claude-trace -v

# Show process tree
./cli/claude-trace -t

# Warn when CPU exceeds threshold
./cli/claude-trace -k 50

# Warn when RSS memory exceeds threshold (in MB)
./cli/claude-trace -m 512

# Uninstall all menu bar app installations
./cli/claude-trace --uninstall-app
```

**Output Fields:**
| Field | Description |
|-------|-------------|
| PID | Process ID |
| PPID | Parent Process ID |
| CPU% | CPU utilization percentage (color-coded: red ≥80%, yellow ≥50%, cyan ≥20%) |
| MEM% | Memory utilization percentage |
| RSS | Resident Set Size (color-coded: red ≥1GB, yellow ≥512MB, cyan ≥256MB) |
| STATE | Process state (R=running, S=sleeping, S+=foreground) |
| TIME | Cumulative CPU time |
| PROJECT | Project name (extracted from `--append-system-prompt` or CWD basename) |

**Verbose Mode (`-v`) adds:**
| Field | Description |
|-------|-------------|
| THRDS | Thread count |
| CWD | Current working directory |

### Project Name Detection

The CLI automatically extracts project names from Claude sessions:

1. **From `--append-system-prompt`**: If you launch Claude with `--append-system-prompt "Working in: myproject"`, the project name "myproject" is extracted
2. **Fallback to CWD**: Otherwise, uses the basename of the process's working directory

**Recommended functions for unique instance tracking:**

Add these to your `~/.zshrc` to ensure every Claude instance is uniquely identifiable—even when running multiple sessions in the same project:

```bash
# Standard Claude with unique instance tracking
claude_traced() {
  local dir=${PWD:t}          # basename of $PWD in zsh
  local tty_id=${TTY:t}       # e.g. /dev/ttys003 -> ttys003
  command claude \
    --append-system-prompt "Working in: ${dir} @${tty_id}" \
    "$@"
}
alias claude=claude_traced

# Skip permissions variant (use with caution)
claude_skip() {
  local dir=${PWD:t}
  local tty_id=${TTY:t}
  command claude --dangerously-skip-permissions \
    --append-system-prompt "Working in: ${dir} @${tty_id}" \
    "$@"
}
alias claude-skip=claude_skip
```

Both append the project directory and terminal session ID (e.g., `Working in: myproject @ttys003`), guaranteeing each Claude instance is distinguishable in the CLI and menu bar app. Use `claude` for normal operation with permission prompts, or `claude-skip` when you want to bypass them.

### `claude-diagnose` - Deep Diagnostics (Rust)

High-performance Rust binary for in-depth analysis including stack sampling and file descriptor inspection.

```bash
# Quick overview
./cli/target/release/claude-diagnose

# Deep analysis with file descriptor inspection
./cli/target/release/claude-diagnose -d

# Deep analysis with stack sampling (5s default)
./cli/target/release/claude-diagnose -d -s

# 10-second sample with JSON output
./cli/target/release/claude-diagnose -d -s --sample-duration 10 -j

# Analyze specific PID
./cli/target/release/claude-diagnose --pid 35072 -d -s

# Full help
./cli/target/release/claude-diagnose --help
```

**Diagnostic Capabilities:**
- Stack sampling via macOS `sample` command
- Hot function detection and ranking
- FSEvents watcher detection
- File descriptor leak detection
- Network connection enumeration
- Memory pressure analysis
- V8 GC pressure detection
- CFRunLoop spin detection
- **DTrace/dtruss syscall tracing**
- **Flamegraph generation**

### DTrace Syscall Tracing

Enable system call tracing for deep analysis of process behavior:

```bash
# Basic syscall trace (requires sudo)
sudo ./cli/target/release/claude-diagnose -D --pid 35072

# 10-second trace with JSON output
sudo ./cli/target/release/claude-diagnose -D --duration 10 --pid 35072 -j

# I/O focused trace (read, write, open, close, stat)
sudo ./cli/target/release/claude-diagnose -D --io --pid 35072

# Network focused trace (socket, connect, send, recv)
sudo ./cli/target/release/claude-diagnose -D --network --pid 35072
```

**Flamegraph Generation:**

Generate interactive SVG visualizations of syscall activity:

```bash
# Basic flamegraph (5s default duration)
sudo ./cli/target/release/claude-diagnose -D --flamegraph --pid 35072 -o syscalls.svg

# I/O focused flamegraph
sudo ./cli/target/release/claude-diagnose -D --io --flamegraph --pid 35072 -o io.svg

# Network focused flamegraph
sudo ./cli/target/release/claude-diagnose -D --network --flamegraph --pid 35072 -o network.svg

# Longer trace (10s) for more comprehensive data
sudo ./cli/target/release/claude-diagnose -D --flamegraph --duration 10 --pid 35072 -o syscalls.svg

# Open the generated flamegraph
open syscalls.svg
```

**DTrace Output Includes:**
| Field | Description |
|-------|-------------|
| Top Syscalls | Most frequently called system calls |
| Total Time | Cumulative time spent in each syscall |
| Avg Time | Average latency per syscall |
| Errors | Failed syscall count |
| I/O Operations | File read/write activity with paths |
| Network Operations | Socket operations with addresses |

**Flamegraph Features:**
- Syscalls grouped by category (file, network, memory, process, event)
- Width represents call frequency
- Interactive SVG - hover for details, click to zoom
- Also generates `.folded` file for use with external flamegraph tools

**SIP Considerations:**

On macOS with System Integrity Protection (SIP) enabled, DTrace may be restricted. The tool will:
1. Detect SIP restrictions automatically
2. Fall back to `fs_usage` for limited file system tracing
3. Report the fallback reason in output

To enable full DTrace support, you can disable SIP (not recommended for production) or use `csrutil enable --without dtrace` in recovery mode.

## Menu Bar App

A native macOS menu bar application for always-on monitoring with desktop notifications.

### Features

- **Real-time monitoring** - Polls claude-trace for process data at configurable intervals
- **Project names** - Shows project names for each Claude session (from `--append-system-prompt` or CWD)
- **Menu bar presence** - Always visible CPU/memory summary in your menu bar
- **Expandable rows** - Click to expand process details, hover for visual feedback
- **Double-click detail window** - Open a floating window with full process information
- **Native notifications** - Get alerted when thresholds are exceeded
- **Configurable thresholds** - Set aggregate and per-process CPU/memory limits
- **Launch at Login** - Start monitoring automatically
- **No Dock icon** - Runs quietly in the background

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ (for building)

### Building the Menu Bar App

```bash
# Using the dev script
./dev.sh build-app

# Or using xcodebuild directly
xcodebuild -project apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar.xcodeproj -scheme ClaudeTraceMenuBar -configuration Release build

# Run after building
./dev.sh run-app
```

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Polling Interval | 2 sec | How often to refresh process data |
| Aggregate CPU Threshold | 100% | Notify when total CPU exceeds this |
| Aggregate Memory Threshold | 2048 MB | Notify when total RSS exceeds this |
| Per-Process CPU Threshold | 80% | Notify when any process exceeds this |
| Per-Process Memory Threshold | 1024 MB | Notify when any process exceeds this |
| Notification Throttle | 60 sec | Minimum time between same notification type |

## Common CPU Spinning Causes

### 1. FSEvents Watcher Storm
**Symptom:** High kevent/CFRunLoop samples
**Cause:** Watching too many files/directories
**Fix:** Add exclusions to `.claude/settings.json`

### 2. Event Loop Blocking
**Symptom:** High poll/kevent with no I/O
**Cause:** Synchronous operations blocking the loop
**Fix:** Restart affected session

### 3. GC Pressure
**Symptom:** High V8 GC samples (Scavenge, MarkCompact)
**Cause:** Memory churn
**Fix:** Increase `--max-old-space-size`

### 4. DNS/Network Retry Storm
**Symptom:** High getaddrinfo/TCP samples
**Cause:** Network connectivity issues
**Fix:** Check network, restart session

## Diagnostic Workflow

```bash
# 1. Quick scan
./cli/claude-trace

# 2. Identify high-CPU PID (e.g., 35072)

# 3. Deep sample with stack profiling
./cli/target/release/claude-diagnose --pid 35072 -d -s --sample-duration 10

# 4. If still unclear, trace syscalls
sudo ./cli/target/release/claude-diagnose --pid 35072 -D --duration 10

# 5. For I/O bottlenecks, focus on file operations
sudo ./cli/target/release/claude-diagnose --pid 35072 -D --io --duration 10

# 6. Generate flamegraph for visualization
sudo ./cli/target/release/claude-diagnose --pid 35072 -D --flamegraph -o debug.svg

# 7. Check raw sample for details
sample 35072 10 -file /tmp/claude.txt
filtercalltree /tmp/claude.txt

# 8. Monitor for recurrence
./cli/claude-trace -w 5 -k 50
```

## Auto-Throttle Script

For automated monitoring and throttling:

```bash
#!/bin/bash
# Save as: claude-watchdog.sh

THRESHOLD=80
INTERVAL=30
TRACE_PATH="./cli/claude-trace"

while true; do
    "$TRACE_PATH" -j | jq -r '.processes[] | select(.cpu_percent > '$THRESHOLD') | .pid' | \
    while read pid; do
        echo "[$(date)] Warning: PID $pid exceeds ${THRESHOLD}% CPU"
        # Optional: renice or kill
        # renice +10 -p $pid
    done
    sleep $INTERVAL
done
```

## Building from Source

```bash
# Prerequisites: Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Option 1: Use the dev script
./dev.sh build        # CLI tools only
./dev.sh build-all    # CLI + menu bar app

# Option 2: Build directly with cargo
cd cli && cargo build --release

# Option 3: Build menu bar app with xcodebuild
xcodebuild -project apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar.xcodeproj -scheme ClaudeTraceMenuBar -configuration Release build

# Binaries are at:
# - cli/target/release/claude-diagnose
# - ~/Library/Developer/Xcode/DerivedData/ClaudeTraceMenuBar-*/Build/Products/Release/ClaudeTraceMenuBar.app
```

## Requirements

- macOS Darwin (tested on 24.6.0)
- Bash 4.0+ (for `claude-trace`)
- Rust 1.70+ (for building `claude-diagnose`)
- Xcode 15.0+ and macOS 14.0+ (for menu bar app)
- Standard macOS tools: `ps`, `lsof`, `sample`, `vm_stat`
- For DTrace features: `dtruss`, `dtrace`, `fs_usage` (requires sudo)
- Optional: SIP disabled or configured for DTrace (for full tracing)

## License

MIT
