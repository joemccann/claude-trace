# Claude Code Project Instructions

## Project Overview

**claude-trace** is a diagnostic toolkit for monitoring and analyzing Claude Code CLI process resource usage on macOS. It uses a hybrid Bash + Rust architecture for fast monitoring and deep diagnostics.

## Architecture

```
claude-trace/
├── claude-trace           # Bash script - real-time process monitor (lightweight, fast)
├── src/main.rs            # Rust binary source - deep diagnostic analysis
├── target/release/
│   └── claude-diagnose    # Compiled Rust binary
├── Cargo.toml             # Rust dependencies
└── Cargo.lock             # Dependency lockfile (committed for reproducible builds)
```

### Tool Responsibilities

| Tool | Language | Purpose |
|------|----------|---------|
| `claude-trace` | Bash | Fast, lightweight real-time monitoring with watch mode |
| `claude-diagnose` | Rust | Deep analysis: stack sampling, FD analysis, DTrace tracing, flamegraphs |

## Build Commands

```bash
# Build the Rust diagnostic binary
cargo build --release

# Run the Bash monitor
./claude-trace

# Run the Rust diagnostics
./target/release/claude-diagnose
```

## Key Dependencies

- **macOS system tools**: `ps`, `lsof`, `sample`, `vm_stat`, `memory_pressure`, `dtruss`, `dtrace`, `fs_usage`
- **Rust crates**: clap (CLI), serde/serde_json (JSON), chrono (timestamps), colored (terminal output), regex, anyhow, inferno (flamegraphs)

## Code Conventions

### Bash (`claude-trace`)
- Use `set -euo pipefail` for strict error handling
- Functions prefixed descriptively: `get_*`, `print_*`, `output_*`
- Support both Darwin (macOS) and Linux where feasible
- Color output via ANSI codes: RED (>=80% CPU), YELLOW (>=50%), CYAN (>=20%)
- Verbose mode (`-v`) adds: thread count, open files, working directory (CWD), and project name

### Rust (`claude-diagnose`)
- Use `clap` derive macros for CLI argument parsing
- Structured data with `serde` for JSON serialization
- Error handling via `anyhow::Result`
- Diagnostics have severity levels: high, medium, low

## Testing

```bash
# Test Bash script
./claude-trace --help
./claude-trace -v
./claude-trace -j | jq .

# Test Rust binary
cargo test
./target/release/claude-diagnose --help
./target/release/claude-diagnose -d -s
```

## Common Tasks

### Adding a new diagnostic check
1. Add detection logic in `src/main.rs` within appropriate analysis function
2. Create a `Diagnosis` struct with severity, issue, and recommendation
3. Add to the diagnostic report aggregation

### Adding new CLI flags
- **Bash**: Add case in argument parsing loop, update `show_help()`
- **Rust**: Add field to `Cli` struct with `#[arg(...)]` attribute

### Modifying process discovery
- Pattern: regex matching "claude" or "anthropic" in process command
- Location: `get_claude_pids()` in both tools

### Adding new DTrace analysis
1. Add syscall detection in `parse_dtruss_output()` or create specialized extractor
2. Update `analyze_dtrace_issues()` with new diagnostic patterns
3. Add new fields to `DtraceResult` struct if needed
4. Update `print_report()` to display new data

### Modifying flamegraph categories
- Edit `categorize_syscall()` in `src/main.rs` to adjust syscall groupings
- Categories: file, network, memory, process, event, time, ipc, other

## Output Fields

### Standard Mode (`claude-trace`)
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

### Verbose Mode (`claude-trace -v`)
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

## Platform Notes

- **Primary platform**: macOS (Darwin)
- **macOS-specific**: `sample` command for stack profiling, `memory_pressure` for system memory state
- **Linux compatibility**: Bash script has OS detection, Rust binary is macOS-focused

## Debugging Tips

1. **Quick scan**: `./claude-trace` to see all Claude processes
2. **Watch mode**: `./claude-trace -w 2` for continuous monitoring
3. **Project view**: `./claude-trace -v` to see working directory and project name for each process
4. **Deep dive**: `./target/release/claude-diagnose --pid <PID> -d -s --sample-duration 10`
5. **JSON pipeline**: `./claude-trace -j | jq '.processes[] | select(.cpu > 50)'`
6. **Filter by project**: `./claude-trace -j -v | jq '.processes[] | select(.project == "myproject")'`
7. **Syscall tracing**: `sudo ./target/release/claude-diagnose --pid <PID> -D --duration 10`
8. **I/O analysis**: `sudo ./target/release/claude-diagnose --pid <PID> -D --io`
9. **Network analysis**: `sudo ./target/release/claude-diagnose --pid <PID> -D --network`
10. **Flamegraph**: `sudo ./target/release/claude-diagnose --pid <PID> -D --flamegraph -o trace.svg`

## Performance Considerations

- Bash script is intentionally lightweight for frequent polling
- Verbose mode (`-v`) adds `lsof` calls per process which increases execution time
- Rust binary uses LTO and stripping for optimized binary size
- Stack sampling (`sample`) is expensive - use judiciously with `--sample-duration`
- DTrace/dtruss adds overhead to traced process - keep `--duration` reasonable (5-30s)
- Flamegraph generation is CPU-intensive for large traces
- `fs_usage` fallback is less precise but has lower overhead than full DTrace
