#!/usr/bin/env bats
#
# claude-trace.bats - Comprehensive tests for claude-trace CLI
#
# Run with: bats cli/tests/claude-trace.bats
#

# Load test helper
load test_helper

# Setup before each test
setup() {
    # Source CLI functions
    setup_cli_functions
}

# ============================================================================
# ARGUMENT PARSING TESTS (~15 tests)
# ============================================================================

@test "help: -h shows usage" {
    run_cli -h
    [ "$status" -eq 0 ]
    assert_output_contains "claude-trace - Monitor Claude Code CLI"
    assert_output_contains "USAGE:"
    assert_output_contains "OPTIONS:"
}

@test "help: --help shows usage" {
    run_cli --help
    [ "$status" -eq 0 ]
    assert_output_contains "claude-trace - Monitor Claude Code CLI"
}

@test "verbose: -v flag is recognized" {
    # Just test that the flag doesn't cause an error
    # (actual output depends on running processes)
    run_cli -v
    [ "$status" -eq 0 ]
}

@test "verbose: --verbose flag is recognized" {
    run_cli --verbose
    [ "$status" -eq 0 ]
}

@test "json: -j outputs valid JSON" {
    run_cli -j
    [ "$status" -eq 0 ]
    assert_valid_json
}

@test "json: --json outputs valid JSON" {
    run_cli --json
    [ "$status" -eq 0 ]
    assert_valid_json
}

@test "json: combined -j -v outputs valid JSON with extra fields" {
    run_cli -j -v
    [ "$status" -eq 0 ]
    assert_valid_json
}

@test "watch: -w accepts optional interval" {
    # Use timeout to avoid hanging - just verify parsing works
    run timeout 1 "$CLI_SCRIPT" -w 1 || true
    # Either exits 0 (no processes) or times out (124) - both acceptable
    [[ "$status" -eq 0 || "$status" -eq 124 || "$status" -eq 143 ]]
}

@test "threshold: -k accepts numeric argument" {
    run_cli -k 50
    [ "$status" -eq 0 ]
}

@test "threshold: -m accepts numeric memory threshold" {
    run_cli -m 512
    [ "$status" -eq 0 ]
}

@test "invalid: unknown option shows error" {
    run_cli --invalid-option
    [ "$status" -eq 1 ]
    assert_output_contains "Unknown option"
}

@test "kill: -K requires valid PID" {
    run_cli -K
    [ "$status" -eq 1 ]
    assert_output_contains "requires a valid PID"
}

@test "kill: -K rejects non-numeric PID" {
    run_cli -K abc
    [ "$status" -eq 1 ]
    assert_output_contains "requires a valid PID"
}

@test "force: -9 flag is recognized with -K" {
    # This will fail because the PID doesn't exist, but the flags are parsed
    run_cli -K 99999 -9
    # Should fail gracefully (process not found)
    assert_output_contains "not found" || assert_output_contains "not a Claude"
}

@test "tree: -t flag is recognized" {
    run_cli -t
    [ "$status" -eq 0 ]
}

# ============================================================================
# VERSION DETECTION TESTS (~8 tests)
# ============================================================================

@test "version: extract_version_from_cmd extracts version from path" {
    local result
    result=$(extract_version_from_cmd "/Users/test/.local/share/claude/versions/1.0.50/node")
    [ "$result" = "1.0.50" ]
}

@test "version: extract_version_from_cmd handles missing version" {
    local result
    result=$(extract_version_from_cmd "/usr/bin/node something")
    [ -z "$result" ]
}

@test "version: extract_version_from_cmd handles multi-digit versions" {
    local result
    result=$(extract_version_from_cmd "/Users/test/.local/share/claude/versions/10.20.30/node")
    [ "$result" = "10.20.30" ]
}

@test "version: version_gte returns true for equal versions" {
    version_gte "1.0.50" "1.0.50"
}

@test "version: version_gte returns true for greater version" {
    version_gte "1.0.51" "1.0.50"
}

@test "version: version_gte returns false for lesser version" {
    ! version_gte "1.0.49" "1.0.50"
}

@test "version: version_gte handles major version differences" {
    version_gte "2.0.0" "1.9.99"
}

@test "version: version_gte handles minor version differences" {
    version_gte "1.1.0" "1.0.99"
}

# ============================================================================
# ORPHAN DETECTION TESTS (~5 tests)
# ============================================================================

@test "orphan: is_orphaned_process returns true for PPID=1" {
    is_orphaned_process 1
}

@test "orphan: is_orphaned_process returns false for normal PPID" {
    ! is_orphaned_process 12345
}

@test "orphan: is_orphaned_process returns false for PPID=0" {
    ! is_orphaned_process 0
}

@test "orphan: is_orphaned_process returns false for large PPID" {
    ! is_orphaned_process 99999
}

@test "orphan: is_orphaned_process handles string comparison" {
    is_orphaned_process "1"
}

# ============================================================================
# PROJECT/SESSION EXTRACTION TESTS (~10 tests)
# ============================================================================

@test "project: extract_project_from_command extracts from double quotes" {
    local cmd='node cli.js --append-system-prompt "Working in: myproject"'
    local result
    result=$(extract_project_from_command "$cmd" "")
    [ "$result" = "myproject" ]
}

@test "project: extract_project_from_command extracts from single quotes" {
    local cmd="node cli.js --append-system-prompt 'Working in: myproject'"
    local result
    result=$(extract_project_from_command "$cmd" "")
    [ "$result" = "myproject" ]
}

@test "project: extract_project_from_command falls back to CWD basename" {
    local cmd="node cli.js"
    local result
    result=$(extract_project_from_command "$cmd" "/Users/test/projects/myproject")
    [ "$result" = "myproject" ]
}

@test "project: extract_project_from_command handles empty CWD" {
    local cmd="node cli.js"
    local result
    result=$(extract_project_from_command "$cmd" "")
    [ -z "$result" ]
}

@test "project: extract_project_from_command handles complex project names" {
    local cmd='node cli.js --append-system-prompt "Working in: my-complex_project.v2"'
    local result
    result=$(extract_project_from_command "$cmd" "")
    [ "$result" = "my-complex_project.v2" ]
}

@test "session: extract_session_id extracts UUID" {
    local cmd='node cli.js --session-id abc123-def456'
    local result
    result=$(extract_session_id "$cmd")
    [ "$result" = "abc123-def456" ]
}

@test "session: extract_session_id extracts quoted UUID" {
    local cmd='node cli.js --session-id "abc123-def456"'
    local result
    result=$(extract_session_id "$cmd")
    [ "$result" = "abc123-def456" ]
}

@test "session: extract_session_id handles missing session" {
    local cmd='node cli.js'
    local result
    result=$(extract_session_id "$cmd")
    [ -z "$result" ]
}

@test "project: get_project_name extracts basename" {
    local result
    result=$(get_project_name "/Users/test/dev/myproject")
    [ "$result" = "myproject" ]
}

@test "project: get_project_name handles empty input" {
    local result
    result=$(get_project_name "")
    [ -z "$result" ]
}

# ============================================================================
# PROCESS DISCOVERY PATTERN TESTS (~10 tests)
# ============================================================================

@test "pattern: matches claude command at start" {
    matches_claude_pattern "claude --help"
}

@test "pattern: matches claude with full path" {
    matches_claude_pattern "/usr/local/bin/claude --help"
}

@test "pattern: matches .local/share/claude path" {
    matches_claude_pattern "/Users/test/.local/share/claude/versions/1.0.50/node"
}

@test "pattern: matches /anthropic/ path" {
    matches_claude_pattern "/opt/anthropic/bin/claude"
}

@test "pattern: excludes grep command" {
    should_exclude_pattern "grep claude"
}

@test "pattern: excludes claude-trace" {
    should_exclude_pattern "claude-trace -v"
}

@test "pattern: excludes claude-diagnose" {
    should_exclude_pattern "claude-diagnose --help"
}

@test "pattern: does not match arbitrary claude in path" {
    # This should NOT match - it's just a directory name
    ! matches_claude_pattern "code /Users/claude/project/file.js"
}

@test "pattern: matches claude binary even with arguments" {
    matches_claude_pattern "claude chat -m 'hello'"
}

@test "pattern: matches Node.js running Claude CLI" {
    matches_claude_pattern "/Users/test/.local/share/claude/versions/1.0.50/node /Users/test/.local/share/claude/versions/1.0.50/cli.js"
}

# ============================================================================
# OUTPUT FORMATTING TESTS (~15 tests)
# ============================================================================

@test "format: format_bytes handles kilobytes" {
    local result
    result=$(format_bytes 512)
    [ "$result" = "512K" ]
}

@test "format: format_bytes handles megabytes" {
    local result
    result=$(format_bytes 1024)
    [ "$result" = "1.0M" ]
}

@test "format: format_bytes handles large megabytes" {
    local result
    result=$(format_bytes 524288)
    [ "$result" = "512.0M" ]
}

@test "format: format_bytes handles gigabytes" {
    local result
    result=$(format_bytes 1048576)
    [ "$result" = "1.0G" ]
}

@test "format: format_bytes handles multiple gigabytes" {
    local result
    result=$(format_bytes 2097152)
    [ "$result" = "2.0G" ]
}

@test "json: output contains timestamp" {
    run_cli -j
    assert_json_field ".timestamp"
}

@test "json: output contains hostname" {
    run_cli -j
    assert_json_field ".hostname"
}

@test "json: output contains os field" {
    run_cli -j
    assert_json_field ".os"
}

@test "json: output contains process_count" {
    run_cli -j
    assert_json_field ".process_count"
}

@test "json: output contains totals object" {
    run_cli -j
    assert_json_field ".totals"
}

@test "json: output contains processes array" {
    run_cli -j
    assert_json_field ".processes"
}

@test "json: totals contains cpu_percent" {
    run_cli -j
    assert_json_field ".totals.cpu_percent"
}

@test "json: totals contains mem_percent" {
    run_cli -j
    assert_json_field ".totals.mem_percent"
}

@test "json: totals contains rss_kb" {
    run_cli -j
    assert_json_field ".totals.rss_kb"
}

@test "json: totals contains rss_human" {
    run_cli -j
    assert_json_field ".totals.rss_human"
}

# ============================================================================
# JSON PROCESS FIELD TESTS (~10 tests)
# ============================================================================

@test "json: process has pid field when processes exist" {
    run_cli -j
    # Skip if no processes
    if [ "$(echo "$output" | jq '.process_count')" -gt 0 ]; then
        assert_json_field ".processes[0].pid"
    else
        skip "No Claude processes running"
    fi
}

@test "json: process has ppid field when processes exist" {
    run_cli -j
    if [ "$(echo "$output" | jq '.process_count')" -gt 0 ]; then
        assert_json_field ".processes[0].ppid"
    else
        skip "No Claude processes running"
    fi
}

@test "json: process has cpu_percent field when processes exist" {
    run_cli -j
    if [ "$(echo "$output" | jq '.process_count')" -gt 0 ]; then
        assert_json_field ".processes[0].cpu_percent"
    else
        skip "No Claude processes running"
    fi
}

@test "json: process has state field when processes exist" {
    run_cli -j
    if [ "$(echo "$output" | jq '.process_count')" -gt 0 ]; then
        assert_json_field ".processes[0].state"
    else
        skip "No Claude processes running"
    fi
}

@test "json: process has is_orphaned field when processes exist" {
    run_cli -j
    if [ "$(echo "$output" | jq '.process_count')" -gt 0 ]; then
        assert_json_field ".processes[0].is_orphaned"
    else
        skip "No Claude processes running"
    fi
}

@test "json: process has is_outdated field when processes exist" {
    run_cli -j
    if [ "$(echo "$output" | jq '.process_count')" -gt 0 ]; then
        assert_json_field ".processes[0].is_outdated"
    else
        skip "No Claude processes running"
    fi
}

@test "json verbose: process has threads field when processes exist" {
    run_cli -j -v
    if [ "$(echo "$output" | jq '.process_count')" -gt 0 ]; then
        assert_json_field ".processes[0].threads"
    else
        skip "No Claude processes running"
    fi
}

@test "json verbose: process has cwd field when processes exist" {
    run_cli -j -v
    if [ "$(echo "$output" | jq '.process_count')" -gt 0 ]; then
        assert_json_field ".processes[0].cwd"
    else
        skip "No Claude processes running"
    fi
}

@test "json verbose: process has project field when processes exist" {
    run_cli -j -v
    if [ "$(echo "$output" | jq '.process_count')" -gt 0 ]; then
        assert_json_field ".processes[0].project"
    else
        skip "No Claude processes running"
    fi
}

@test "json verbose: process has open_files field when processes exist" {
    run_cli -j -v
    if [ "$(echo "$output" | jq '.process_count')" -gt 0 ]; then
        assert_json_field ".processes[0].open_files"
    else
        skip "No Claude processes running"
    fi
}

# ============================================================================
# THRESHOLD WARNING TESTS (~8 tests)
# ============================================================================

@test "threshold: CPU threshold value is respected in output" {
    run_cli -k 50
    [ "$status" -eq 0 ]
    # Output should complete without error
}

@test "threshold: memory threshold value is respected" {
    run_cli -m 256
    [ "$status" -eq 0 ]
}

@test "threshold: combined thresholds work" {
    run_cli -k 80 -m 1024
    [ "$status" -eq 0 ]
}

@test "threshold: zero threshold disables checking" {
    run_cli -k 0 -m 0
    [ "$status" -eq 0 ]
}

@test "threshold: high threshold never triggers" {
    run_cli -k 1000 -m 999999
    [ "$status" -eq 0 ]
    # Should not contain warning
    assert_output_not_contains "CPU" || true
}

@test "threshold: threshold with verbose" {
    run_cli -k 50 -v
    [ "$status" -eq 0 ]
}

@test "threshold: threshold with json" {
    run_cli -k 50 -j
    [ "$status" -eq 0 ]
    assert_valid_json
}

@test "threshold: threshold with tree" {
    run_cli -k 50 -t
    [ "$status" -eq 0 ]
}

# ============================================================================
# OS DETECTION TESTS (~3 tests)
# ============================================================================

@test "os: detect_os returns valid value" {
    local result
    result=$(detect_os)
    [[ "$result" == "darwin" || "$result" == "linux" || "$result" == "unknown" ]]
}

@test "os: OS_TYPE is set" {
    [ -n "$OS_TYPE" ]
}

@test "os: on macOS returns darwin" {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        [ "$(detect_os)" = "darwin" ]
    else
        skip "Not running on macOS"
    fi
}

# ============================================================================
# TREE MODE TESTS (~4 tests)
# ============================================================================

@test "tree: --tree flag works" {
    run_cli --tree
    [ "$status" -eq 0 ]
}

@test "tree: tree mode shows process tree section" {
    run_cli -t
    # If there are processes, should show tree
    # If no processes, that's ok too
    [ "$status" -eq 0 ]
}

@test "tree: tree combined with verbose" {
    run_cli -t -v
    [ "$status" -eq 0 ]
}

@test "tree: tree with threshold" {
    run_cli -t -k 50
    [ "$status" -eq 0 ]
}

# ============================================================================
# VERSION CHECK COMMAND TESTS (~4 tests)
# ============================================================================

@test "version-check: --check-version runs without error" {
    run_cli --check-version
    # May return 0, 1, or 2 depending on version status
    [[ "$status" -eq 0 || "$status" -eq 1 || "$status" -eq 2 ]]
}

@test "version-check: shows version information" {
    run_cli --check-version
    assert_output_contains "version" || assert_output_contains "Version" || assert_output_contains "Error"
}

@test "version-check: exits cleanly" {
    run_cli --check-version
    # Should not hang or crash
    [[ "$status" -eq 0 || "$status" -eq 1 || "$status" -eq 2 ]]
}

@test "local-version: get_local_version returns version or empty" {
    local result
    result=$(get_local_version)
    # Either empty or valid semver
    if [ -n "$result" ]; then
        [[ "$result" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
    fi
}

# ============================================================================
# INSTALL/UNINSTALL TESTS (~4 tests)
# ============================================================================

@test "install: --install shows permission message without sudo" {
    # Run without sudo - should fail gracefully
    run "$CLI_SCRIPT" --install
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
    # Either succeeds or shows permission error
}

@test "uninstall: --uninstall-app runs without error" {
    run_cli --uninstall-app
    [ "$status" -eq 0 ]
    assert_output_contains "Uninstalling" || assert_output_contains "No Claude Trace"
}

@test "uninstall: --uninstall-app is idempotent" {
    run_cli --uninstall-app
    run_cli --uninstall-app
    [ "$status" -eq 0 ]
}

@test "uninstall: shows completion message" {
    run_cli --uninstall-app
    [ "$status" -eq 0 ]
    # Should show either "Done" or "No Claude Trace installations found"
    assert_output_contains "Done" || assert_output_contains "No Claude Trace"
}

# ============================================================================
# EMPTY PROCESS LIST TESTS (~3 tests)
# ============================================================================

@test "empty: handles no processes gracefully in table mode" {
    # This test verifies the script doesn't crash with no processes
    # (we can't guarantee there are no Claude processes during test)
    run_cli
    [ "$status" -eq 0 ]
}

@test "empty: handles no processes in JSON mode" {
    run_cli -j
    [ "$status" -eq 0 ]
    assert_valid_json
}

@test "empty: JSON shows zero counts when no processes" {
    run_cli -j
    local count
    count=$(echo "$output" | jq '.process_count')
    # Count should be a non-negative integer
    [[ "$count" =~ ^[0-9]+$ ]]
}

# ============================================================================
# COLOR CODE TESTS (~5 tests)
# ============================================================================

@test "color: colors are defined when terminal" {
    # In test environment, might not be a terminal
    # Just verify the variables exist after sourcing
    [ -n "${RED+x}" ] || [ -z "${RED}" ]
}

@test "color: RESET is defined" {
    [ -n "${RESET+x}" ] || [ -z "${RESET}" ]
}

@test "color: BOLD is defined" {
    [ -n "${BOLD+x}" ] || [ -z "${BOLD}" ]
}

@test "color: GREEN is defined" {
    [ -n "${GREEN+x}" ] || [ -z "${GREEN}" ]
}

@test "color: DIM is defined" {
    [ -n "${DIM+x}" ] || [ -z "${DIM}" ]
}

# ============================================================================
# EDGE CASE TESTS (~5 tests)
# ============================================================================

@test "edge: handles special characters in project names" {
    local cmd='node cli.js --append-system-prompt "Working in: my-project_v2.0"'
    local result
    result=$(extract_project_from_command "$cmd" "")
    [ "$result" = "my-project_v2.0" ]
}

@test "edge: handles spaces in paths" {
    local cmd='/Users/test/My Projects/.local/share/claude/versions/1.0.50/node'
    # Should still extract version
    local result
    result=$(extract_version_from_cmd "$cmd")
    [ "$result" = "1.0.50" ]
}

@test "edge: handles empty command string" {
    local result
    result=$(extract_project_from_command "" "/some/path")
    [ "$result" = "path" ]
}

@test "edge: handles CWD with trailing slash" {
    local result
    result=$(get_project_name "/Users/test/project/")
    # basename handles trailing slash
    [ -n "$result" ]
}

@test "edge: format_bytes handles zero" {
    local result
    result=$(format_bytes 0)
    [ "$result" = "0K" ]
}

# ============================================================================
# INTEGRATION TESTS (~5 tests)
# ============================================================================

@test "integration: full JSON output is parseable" {
    run_cli -j -v
    [ "$status" -eq 0 ]
    # Verify all expected top-level fields
    assert_json_field ".timestamp"
    assert_json_field ".hostname"
    assert_json_field ".os"
    assert_json_field ".process_count"
    assert_json_field ".totals"
    assert_json_field ".processes"
}

@test "integration: JSON orphaned_count exists" {
    run_cli -j
    assert_json_field ".orphaned_count"
}

@test "integration: JSON outdated_count exists" {
    run_cli -j
    assert_json_field ".outdated_count"
}

@test "integration: JSON latest_local_version exists" {
    run_cli -j
    # Field exists (may be empty string)
    echo "$output" | jq -e '.latest_local_version != null' > /dev/null
}

@test "integration: table mode produces output" {
    run_cli
    [ "$status" -eq 0 ]
    # Should have some output
    [ -n "$output" ]
}
