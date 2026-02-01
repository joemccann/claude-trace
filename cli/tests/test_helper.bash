#!/usr/bin/env bash
#
# test_helper.bash - Shared fixtures and helper functions for bats tests
#

# Get the directory containing this helper
BATS_TEST_DIRNAME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_DIR="$(dirname "$BATS_TEST_DIRNAME")"
CLI_SCRIPT="$CLI_DIR/claude-trace"

# Export for subshells
export BATS_TEST_DIRNAME CLI_DIR CLI_SCRIPT

# MARK: - Test Mode Setup

# Source the CLI script functions without executing main
# We'll do this by setting a flag that main() checks
export CLAUDE_TRACE_TEST_MODE=1

# Source functions from the CLI script
# This creates a temporary copy with main() disabled for sourcing
setup_cli_functions() {
    # Create a temp file with the script minus the main execution
    local temp_script
    temp_script=$(mktemp)

    # Copy everything except the final 'main' call
    sed '/^main$/d' "$CLI_SCRIPT" > "$temp_script"

    # Add a return to prevent execution
    echo "return 0 2>/dev/null || true" >> "$temp_script"

    # Source it
    # shellcheck source=/dev/null
    source "$temp_script"

    rm -f "$temp_script"
}

# MARK: - Mock Data

# Mock ps output for normal Claude processes
MOCK_PS_OUTPUT_NORMAL='
12345 12300 25.5 1.2 524288 1048576 S+ 01:23:45 /Users/test/.local/share/claude/versions/1.0.50/node /Users/test/.local/share/claude/versions/1.0.50/cli.js --append-system-prompt "Working in: myproject" --session-id abc123
12346 12345 0.0 0.5 262144 524288 S 00:05:30 /Users/test/.local/share/claude/versions/1.0.50/node --claude-in-chrome-mcp
'

# Mock ps output with orphaned process (PPID=1)
MOCK_PS_OUTPUT_ORPHANED='
12345 1 15.0 2.0 1048576 2097152 S 02:00:00 /Users/test/.local/share/claude/versions/1.0.49/node /Users/test/.local/share/claude/versions/1.0.49/cli.js --append-system-prompt "Working in: oldproject"
12346 12300 5.0 0.8 262144 524288 S 00:10:00 /Users/test/.local/share/claude/versions/1.0.50/node /Users/test/.local/share/claude/versions/1.0.50/cli.js
'

# Mock ps output with no Claude processes
MOCK_PS_OUTPUT_EMPTY=''

# Mock versions directory content
MOCK_VERSIONS='1.0.48
1.0.49
1.0.50'

# MARK: - Helper Functions

# Create a mock versions directory
create_mock_versions_dir() {
    local mock_dir
    mock_dir=$(mktemp -d)
    echo "1.0.48" > /dev/null  # Just to use the var
    for version in 1.0.48 1.0.49 1.0.50; do
        mkdir -p "$mock_dir/$version"
    done
    echo "$mock_dir"
}

# Clean up mock directory
cleanup_mock_dir() {
    local dir=$1
    [[ -d "$dir" ]] && rm -rf "$dir"
}

# Run CLI and capture output
run_cli() {
    run "$CLI_SCRIPT" "$@"
}

# Assert output contains string
assert_output_contains() {
    local expected=$1
    if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
    fi
}

# Assert output does not contain string
assert_output_not_contains() {
    local unexpected=$1
    if [[ "$output" == *"$unexpected"* ]]; then
        echo "Expected output NOT to contain: $unexpected"
        echo "Actual output: $output"
        return 1
    fi
}

# Assert JSON output is valid
assert_valid_json() {
    if ! echo "$output" | jq . > /dev/null 2>&1; then
        echo "Expected valid JSON output"
        echo "Actual output: $output"
        return 1
    fi
}

# Assert JSON field exists
assert_json_field() {
    local field=$1
    local expected=${2:-}

    if [[ -n "$expected" ]]; then
        local actual
        actual=$(echo "$output" | jq -r "$field")
        if [[ "$actual" != "$expected" ]]; then
            echo "Expected $field to be: $expected"
            echo "Actual value: $actual"
            return 1
        fi
    else
        # Check if field exists (including false/null values)
        # Use 'has' or 'type' to verify field presence without evaluating truthiness
        local field_type
        field_type=$(echo "$output" | jq -r "$field | type" 2>/dev/null)
        if [[ -z "$field_type" || "$field_type" == "null" ]]; then
            # Field might still exist but be null - check parent
            local parent_field
            parent_field=$(echo "$field" | sed 's/\.[^.]*$//')
            local key_name
            key_name=$(echo "$field" | sed 's/.*\.//' | sed 's/\[.*\]//')
            if ! echo "$output" | jq -e "$parent_field | has(\"$key_name\")" > /dev/null 2>&1; then
                echo "Expected JSON field to exist: $field"
                return 1
            fi
        fi
    fi
}

# MARK: - Version Comparison Helpers

# Test version_gte function
test_version_comparison() {
    local v1=$1
    local v2=$2
    local expected=$3  # "gte" or "lt"

    if [[ "$expected" == "gte" ]]; then
        if ! version_gte "$v1" "$v2"; then
            echo "Expected $v1 >= $v2"
            return 1
        fi
    else
        if version_gte "$v1" "$v2"; then
            echo "Expected $v1 < $v2"
            return 1
        fi
    fi
}

# MARK: - Process Pattern Testing

# Test if a command matches Claude process patterns
matches_claude_pattern() {
    local cmd=$1
    # Match the same patterns as get_claude_pids()
    if echo "$cmd" | grep -qE '(^claude[[:space:]]|/.*claude[[:space:]]|\.local/share/claude/|/anthropic/)'; then
        return 0
    fi
    return 1
}

# Test if a command should be excluded
should_exclude_pattern() {
    local cmd=$1
    if echo "$cmd" | grep -qE '(grep|claude-trace|claude-diagnose)'; then
        return 0
    fi
    return 1
}

# MARK: - Extraction Testing

# Test extract_project_from_command
test_extract_project() {
    local cmd=$1
    local cwd=$2
    local expected=$3

    local result
    result=$(extract_project_from_command "$cmd" "$cwd")

    if [[ "$result" != "$expected" ]]; then
        echo "Expected project: $expected"
        echo "Got: $result"
        return 1
    fi
}

# Test extract_session_id
test_extract_session() {
    local cmd=$1
    local expected=$2

    local result
    result=$(extract_session_id "$cmd")

    if [[ "$result" != "$expected" ]]; then
        echo "Expected session: $expected"
        echo "Got: $result"
        return 1
    fi
}

# MARK: - Byte Formatting

# Test format_bytes function
test_format_bytes() {
    local kb=$1
    local expected=$2

    local result
    result=$(format_bytes "$kb")

    if [[ "$result" != "$expected" ]]; then
        echo "Expected: $expected"
        echo "Got: $result"
        return 1
    fi
}
