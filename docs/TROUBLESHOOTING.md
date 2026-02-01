# Troubleshooting

Common issues and how to fix them.

## Common CPU Spinning Causes

### 1. FSEvents Watcher Storm

**Symptom:** High kevent/CFRunLoop samples in diagnostics

**Cause:** Claude is watching too many files/directories

**Fix:** Add exclusions to `.claude/settings.json`:
```json
{
  "fileWatcher": {
    "exclude": ["node_modules", ".git", "build", "dist"]
  }
}
```

### 2. Event Loop Blocking

**Symptom:** High poll/kevent with no I/O activity

**Cause:** Synchronous operations blocking the Node.js event loop

**Fix:** Restart the affected session

### 3. GC Pressure

**Symptom:** High V8 GC samples (Scavenge, MarkCompact) in stack sampling

**Cause:** Memory churn from large operations

**Fix:** Increase memory limit:
```bash
NODE_OPTIONS="--max-old-space-size=4096" claude
```

### 4. DNS/Network Retry Storm

**Symptom:** High getaddrinfo/TCP samples

**Cause:** Network connectivity issues causing retry loops

**Fix:**
1. Check network connection
2. Restart the session
3. Check firewall/VPN settings

## Menu Bar App Issues

### App doesn't show processes

**Cause:** CLI not found or returning errors

**Fix:**
1. Verify CLI works: `./cli/claude-trace`
2. Check CLI path in app (the app searches multiple locations)
3. Reinstall: `./dev.sh deploy`

### Notifications not appearing

**Cause:** macOS notification permissions

**Fix:**
1. System Settings → Notifications
2. Find "Claude Trace"
3. Enable notifications

### App not starting at login

**Cause:** Login item not registered

**Fix:**
1. Open the app
2. Go to Settings
3. Toggle "Launch at Login" off and on

### High memory usage from the app itself

**Cause:** Polling interval too fast with many processes

**Fix:** Increase polling interval in Settings (try 5 or 10 seconds)

## CLI Issues

### "No Claude processes found"

This is normal when Claude isn't running. The CLI only shows active Claude processes.

### Colors not displaying

**Cause:** Terminal doesn't support ANSI colors

**Fix:** Use a modern terminal (iTerm2, Terminal.app, etc.)

### JSON output malformed

**Cause:** May have non-JSON output mixed in

**Fix:** Ensure you're not also using `-v` or other flags that add text output

### Watch mode (-w) flickering

**Cause:** Screen refresh on each update

**Fix:** This is normal behavior. If it's distracting, use a longer interval: `claude-trace -w 5`

## Diagnostics Issues

### "Permission denied" for DTrace

**Cause:** DTrace requires root access

**Fix:** Run with sudo:
```bash
sudo ./cli/target/release/claude-diagnose -D --pid <PID>
```

### "dtrace: failed to initialize" or limited output

**Cause:** System Integrity Protection (SIP) restricts DTrace

**Fix:**
- The tool automatically falls back to `fs_usage`
- For full access: boot to recovery mode and run `csrutil enable --without dtrace`

### Flamegraph won't open

**Cause:** SVG not generated or browser issue

**Fix:**
1. Check the file was created: `ls -la output.svg`
2. Try a different browser
3. Check for errors in the trace output

### Stack sampling returns empty results

**Cause:** Process may have exited or be too short-lived

**Fix:**
1. Verify process is still running: `ps -p <PID>`
2. Try a longer sample duration: `--sample-duration 15`

## Build Issues

### Rust build fails

**Cause:** Missing dependencies or old Rust version

**Fix:**
```bash
rustup update
cd cli && cargo clean && cargo build --release
```

### Xcode build fails

**Cause:** Old Xcode or missing SDK

**Fix:**
1. Update Xcode to 15.0+
2. Verify macOS SDK: `xcode-select -p`
3. Clean build: Product → Clean Build Folder

### bats tests fail

**Cause:** bats-core not installed

**Fix:**
```bash
brew install bats-core
```

## Process Detection Issues

### False positives (non-Claude processes showing)

**Cause:** Process command matches Claude patterns

**Fix:** Report this as a bug with the process details

### Missing Claude processes

**Cause:** Process doesn't match expected patterns

**Fix:** Check the process command:
```bash
ps aux | grep -i claude
```

Claude processes should have commands containing:
- `claude` as the binary name
- `.local/share/claude/` in the path
- `/anthropic/` in the path

## Getting Help

If you're still stuck:

1. Run diagnostics and save output:
   ```bash
   claude-trace -j -v > ~/claude-trace-debug.json
   ./cli/target/release/claude-diagnose -d > ~/claude-diagnose-debug.txt
   ```

2. Open an issue at: https://github.com/joemccann/claude-trace/issues

3. Include:
   - macOS version
   - Claude version
   - The debug output files
   - Steps to reproduce
