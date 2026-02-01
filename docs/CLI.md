# CLI Reference

The `claude-trace` command-line tool provides fast, lightweight process monitoring for Claude Code sessions.

## Basic Usage

```bash
# One-shot process list
claude-trace

# Watch mode (refresh every 2s)
claude-trace -w

# Watch with 5s interval
claude-trace -w 5

# Verbose mode with threads, project, and working directory
claude-trace -v

# JSON output for scripting
claude-trace -j | jq '.totals.cpu_percent'
```

## All Flags

| Flag | Description |
|------|-------------|
| `-w [INTERVAL]` | Watch mode, refresh every N seconds (default: 2) |
| `-v` | Verbose mode: show threads, CWD, and project name |
| `-j` | JSON output |
| `-t` | Show process tree |
| `-k THRESHOLD` | Warn when any process exceeds CPU threshold (%) |
| `-m THRESHOLD` | Warn when any process exceeds RSS threshold (MB) |
| `--uninstall-app` | Remove all menu bar app installations |
| `-h, --help` | Show help |

## Output Fields

### Standard Mode

| Field | Description |
|-------|-------------|
| PID | Process ID |
| PPID | Parent Process ID |
| CPU% | CPU utilization (color-coded: red ≥80%, yellow ≥50%, cyan ≥20%) |
| MEM% | Memory utilization percentage |
| RSS | Resident Set Size (color-coded: red ≥1GB, yellow ≥512MB, cyan ≥256MB) |
| STATE | Process state (R=running, S=sleeping, S+=foreground) |
| TIME | Cumulative CPU time |
| PROJECT | Project name (from `--append-system-prompt` or CWD basename) |

### Verbose Mode (`-v`)

Adds these fields:

| Field | Description |
|-------|-------------|
| THRDS | Thread count |
| CWD | Current working directory |

## JSON Schema

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "hostname": "macbook",
  "os": "Darwin",
  "os_version": "24.6.0",
  "process_count": 5,
  "orphaned_count": 1,
  "outdated_count": 0,
  "totals": {
    "cpu_percent": 45.2,
    "mem_percent": 2.1,
    "rss_kb": 524288
  },
  "processes": [
    {
      "pid": 12345,
      "ppid": 12340,
      "cpu_percent": 25.5,
      "mem_percent": 1.2,
      "rss_kb": 262144,
      "vsz_kb": 4194304,
      "state": "S+",
      "elapsed_time": "00:15:30",
      "command": "node claude...",
      "version": "1.0.53",
      "is_orphaned": false,
      "is_outdated": false,
      "open_files": 42,
      "threads": 8,
      "cwd": "/Users/you/project",
      "project": "my-project",
      "session_id": "ttys003"
    }
  ]
}
```

## Scripting Examples

### Find high-CPU processes

```bash
claude-trace -j | jq '.processes[] | select(.cpu_percent > 50)'
```

### Filter by project

```bash
claude-trace -j -v | jq '.processes[] | select(.project == "myproject")'
```

### Get total CPU

```bash
claude-trace -j | jq '.totals.cpu_percent'
```

### Find orphaned processes

```bash
claude-trace -j | jq '.processes[] | select(.is_orphaned == true)'
```

### Auto-throttle script

```bash
#!/bin/bash
THRESHOLD=80
INTERVAL=30

while true; do
    claude-trace -j | jq -r '.processes[] | select(.cpu_percent > '$THRESHOLD') | .pid' | \
    while read pid; do
        echo "[$(date)] Warning: PID $pid exceeds ${THRESHOLD}% CPU"
        # Optional: renice +10 -p $pid
    done
    sleep $INTERVAL
done
```

## Project Name Detection

The CLI extracts project names from Claude sessions using two methods:

1. **From `--append-system-prompt`**: If launched with `--append-system-prompt "Working in: myproject"`, the project name is extracted
2. **Fallback to CWD**: Otherwise, uses the basename of the working directory

### Recommended Shell Functions

Add to `~/.zshrc` for unique instance tracking:

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

# Skip permissions variant
claude_skip() {
  local dir=${PWD:t}
  local tty_id=${TTY:t}
  command claude --dangerously-skip-permissions \
    --append-system-prompt "Working in: ${dir} @${tty_id}" \
    "$@"
}
alias claude-skip=claude_skip
```

Both append the project directory and terminal session ID (e.g., `Working in: myproject @ttys003`), making each Claude instance distinguishable.

## Process Matching

The CLI identifies Claude processes by matching the COMMAND field:

**Matches:**
- `^claude\s` or `^claude$` — the CLI binary
- `/claude\s` — CLI with full path
- `.local/share/claude/` — Claude's Node.js runtime
- `/anthropic/` — Anthropic binaries

**Does NOT match:**
- Apps with "claude" only in arguments
- Scripts in directories named "claude" (unless they ARE the claude binary)
