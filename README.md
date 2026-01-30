# claude-trace

CLI tools to identify and diagnose Claude Code CLI process resource usage on macOS.

**Built with Bash + Rust** for maximum performance and minimal dependencies.

## Installation

```bash
# Clone the repository
git clone <repo-url> ~/claude-trace
cd ~/claude-trace

# Build the Rust diagnostic tool
cargo build --release

# Add to PATH
export PATH="$HOME/claude-trace:$HOME/claude-trace/target/release:$PATH"

# Or install the binary system-wide
sudo cp target/release/claude-diagnose /usr/local/bin/
sudo cp claude-trace /usr/local/bin/
```

## Tools

### `claude-trace` - Process Monitor (Bash)

Fast, lightweight Bash script for real-time process monitoring.

```bash
# One-shot process list
claude-trace

# Watch mode (refresh every 2s)
claude-trace -w

# Watch with 5s interval
claude-trace -w 5

# JSON output for scripting
claude-trace -j | jq '.totals.cpu_percent'

# Verbose mode with thread counts
claude-trace -v

# Show process tree
claude-trace -t

# Warn when CPU exceeds threshold
claude-trace -k 50
```

**Output Fields:**
| Field | Description |
|-------|-------------|
| PID | Process ID |
| PPID | Parent Process ID |
| CPU% | CPU utilization percentage |
| MEM% | Memory utilization percentage |
| RSS | Resident Set Size (physical memory) |
| STATE | Process state (R=running, S=sleeping) |
| TIME | Cumulative CPU time |

### `claude-diagnose` - Deep Diagnostics (Rust)

High-performance Rust binary for in-depth analysis including stack sampling and file descriptor inspection.

```bash
# Quick overview
claude-diagnose

# Deep analysis with file descriptor inspection
claude-diagnose -d

# Deep analysis with stack sampling (5s default)
claude-diagnose -d -s

# 10-second sample with JSON output
claude-diagnose -d -s --sample-duration 10 -j

# Analyze specific PID
claude-diagnose --pid 35072 -d -s

# Full help
claude-diagnose --help
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
claude-trace

# 2. Identify high-CPU PID (e.g., 35072)

# 3. Deep sample
claude-diagnose --pid 35072 -d -s --sample-duration 10

# 4. Check raw sample for details
sample 35072 10 -file /tmp/claude.txt
filtercalltree /tmp/claude.txt

# 5. Monitor for recurrence
claude-trace -w 5 -k 50
```

## Auto-Throttle Script

For automated monitoring and throttling:

```bash
#!/bin/bash
# Save as: claude-watchdog.sh

THRESHOLD=80
INTERVAL=30

while true; do
    claude-trace -j | jq -r '.processes[] | select(.cpu_percent > '$THRESHOLD') | .pid' | \
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

# Build release binary
cargo build --release

# Binary is at: target/release/claude-diagnose
```

## Requirements

- macOS Darwin (tested on 24.6.0)
- Bash 4.0+ (for `claude-trace`)
- Rust 1.70+ (for building `claude-diagnose`)
- Standard macOS tools: `ps`, `lsof`, `sample`, `vm_stat`

## License

MIT
