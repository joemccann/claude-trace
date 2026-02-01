# Deep Diagnostics

The `claude-diagnose` tool is a Rust-powered diagnostic engine for deep analysis of Claude Code processes. Use it when the CLI shows a problem but you need to understand *why*.

## Quick Start

```bash
# Build the diagnostic tool
cd cli && cargo build --release

# Quick overview of all Claude processes
./cli/target/release/claude-diagnose

# Deep analysis with file descriptors
./cli/target/release/claude-diagnose -d

# Deep analysis with stack sampling
./cli/target/release/claude-diagnose -d -s

# Analyze specific PID
./cli/target/release/claude-diagnose --pid 35072 -d -s
```

## All Flags

| Flag | Description |
|------|-------------|
| `-d, --deep` | Enable deep analysis (file descriptors, network) |
| `-s, --sample` | Enable stack sampling |
| `--sample-duration N` | Sample duration in seconds (default: 5) |
| `--pid PID` | Analyze specific process |
| `-j, --json` | JSON output |
| `-D, --dtrace` | Enable DTrace syscall tracing (requires sudo) |
| `--duration N` | DTrace duration in seconds |
| `--io` | Focus on I/O syscalls |
| `--network` | Focus on network syscalls |
| `--flamegraph` | Generate flamegraph SVG |
| `-o FILE` | Output file for flamegraph |

## Diagnostic Capabilities

### Stack Sampling

Uses the macOS `sample` command to capture what functions are running:

```bash
./cli/target/release/claude-diagnose --pid 35072 -d -s --sample-duration 10
```

Detects:
- Hot function ranking
- FSEvents watcher activity
- CFRunLoop spin detection
- V8 GC pressure

### File Descriptor Analysis

```bash
./cli/target/release/claude-diagnose --pid 35072 -d
```

Shows:
- Open file count
- Network connections
- File descriptor leaks
- Socket states

### DTrace Syscall Tracing

For the deepest analysis, trace system calls in real-time (requires sudo):

```bash
# Basic syscall trace
sudo ./cli/target/release/claude-diagnose -D --pid 35072

# 10-second trace
sudo ./cli/target/release/claude-diagnose -D --duration 10 --pid 35072

# I/O focused (read, write, open, close, stat)
sudo ./cli/target/release/claude-diagnose -D --io --pid 35072

# Network focused (socket, connect, send, recv)
sudo ./cli/target/release/claude-diagnose -D --network --pid 35072
```

**DTrace Output Fields:**

| Field | Description |
|-------|-------------|
| Top Syscalls | Most frequently called system calls |
| Total Time | Cumulative time spent in each syscall |
| Avg Time | Average latency per syscall |
| Errors | Failed syscall count |
| I/O Operations | File read/write activity with paths |
| Network Operations | Socket operations with addresses |

### Flamegraph Generation

Generate interactive SVG visualizations of syscall activity:

```bash
# Basic flamegraph
sudo ./cli/target/release/claude-diagnose -D --flamegraph --pid 35072 -o syscalls.svg

# I/O focused flamegraph
sudo ./cli/target/release/claude-diagnose -D --io --flamegraph --pid 35072 -o io.svg

# Network focused flamegraph
sudo ./cli/target/release/claude-diagnose -D --network --flamegraph --pid 35072 -o network.svg

# Longer trace for more data
sudo ./cli/target/release/claude-diagnose -D --flamegraph --duration 10 --pid 35072 -o syscalls.svg

# Open in browser
open syscalls.svg
```

**Flamegraph Features:**
- Syscalls grouped by category (file, network, memory, process, event)
- Width represents call frequency
- Interactive: hover for details, click to zoom
- Also generates `.folded` file for external tools

## Diagnostic Workflow

```bash
# 1. Quick scan — find the problem process
claude-trace

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
claude-trace -w 5 -k 50
```

## SIP Considerations

On macOS with System Integrity Protection (SIP) enabled, DTrace may be restricted. The tool will:

1. Detect SIP restrictions automatically
2. Fall back to `fs_usage` for limited file system tracing
3. Report the fallback reason in output

To enable full DTrace support:
- Use `csrutil enable --without dtrace` in recovery mode
- Or disable SIP entirely (not recommended for production)

## Syscall Categories

The flamegraph groups syscalls into categories:

| Category | Syscalls |
|----------|----------|
| File | open, read, write, close, stat, fstat, lstat, access, unlink, rename, mkdir, rmdir, readlink, fsync, ftruncate |
| Network | socket, connect, accept, bind, listen, send, recv, sendto, recvfrom, shutdown, getpeername, getsockname |
| Memory | mmap, munmap, mprotect, brk, sbrk |
| Process | fork, exec, exit, wait, kill, getpid, getppid |
| Event | kevent, select, poll, kqueue |
| Time | gettimeofday, clock_gettime |
| IPC | pipe, dup, dup2, fcntl, ioctl |
| Other | Everything else |

## Performance Notes

- Stack sampling (`sample`) adds overhead — use judiciously
- DTrace/dtruss adds overhead to traced process — keep duration reasonable (5-30s)
- Flamegraph generation is CPU-intensive for large traces
- `fs_usage` fallback is less precise but has lower overhead
