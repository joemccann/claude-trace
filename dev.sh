#!/usr/bin/env bash
#
# dev.sh - Build, deploy, and test claude-trace
#
# Usage:
#   ./dev.sh              # Show status
#   ./dev.sh deploy       # Build and deploy everything (CLI + app)
#   ./dev.sh trace        # Run claude-trace
#   ./dev.sh test         # Run all tests (CLI + app)
#   ./dev.sh test-cli     # Run CLI tests only
#   ./dev.sh test-app     # Run Swift app tests only
#   ./dev.sh clean        # Clean build artifacts

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_DIR="$PROJECT_DIR/cli"
APP_DIR="$PROJECT_DIR/apps/ClaudeTraceMenuBar"
APP_PROJECT="$APP_DIR/ClaudeTraceMenuBar.xcodeproj"

info() { echo -e "${CYAN}▸${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
error() { echo -e "${RED}✗${RESET} $*" >&2; }

show_help() {
    cat << 'EOF'
claude-trace Development Script

USAGE:
    ./dev.sh [COMMAND]

COMMANDS:
    deploy      Build CLI + app, install to /Applications, launch
    trace       Run claude-trace (pass any flags after)
    test        Run all tests (CLI + app)
    test-cli    Run CLI tests only (bats)
    test-app    Run Swift app tests only (XCTest)
    clean       Remove build artifacts
    help        Show this help

EXAMPLES:
    ./dev.sh deploy         # Full build and deploy
    ./dev.sh trace          # One-shot process list
    ./dev.sh trace -v       # Verbose mode
    ./dev.sh trace -w       # Watch mode
    ./dev.sh test           # Run all tests
    ./dev.sh test-cli       # Run CLI tests only
EOF
}

# Deploy everything: CLI to /usr/local/bin, app to /Applications
deploy() {
    info "Installing CLI to /usr/local/bin..."
    sudo "$CLI_DIR/claude-trace" --install

    info "Building menu bar app..."
    xcodebuild -project "$APP_PROJECT" \
        -scheme ClaudeTraceMenuBar \
        -configuration Debug \
        build -quiet

    info "Installing to /Applications..."
    pkill -f "Claude Trace" 2>/dev/null || true
    rm -rf "/Applications/Claude Trace.app"
    cp -R ~/Library/Developer/Xcode/DerivedData/ClaudeTraceMenuBar-*/Build/Products/Debug/"Claude Trace.app" /Applications/

    info "Launching..."
    open "/Applications/Claude Trace.app"

    success "Deployed Claude Trace"
}

# Show status
show_status() {
    echo -e "\n${BOLD}claude-trace${RESET}"
    echo -e "${DIM}$(printf '─%.0s' {1..40})${RESET}\n"

    if [[ -x "$CLI_DIR/claude-trace" ]]; then
        success "CLI ready: $CLI_DIR/claude-trace"
    fi

    if [[ -d "/Applications/Claude Trace.app" ]]; then
        success "App installed: /Applications/Claude Trace.app"
    else
        echo -e "  ${DIM}Run ./dev.sh deploy to install${RESET}"
    fi

    # Check for tests
    if [[ -f "$CLI_DIR/tests/claude-trace.bats" ]]; then
        success "CLI tests: $CLI_DIR/tests/claude-trace.bats"
    fi

    if [[ -d "$APP_DIR/ClaudeTraceMenuBarTests" ]]; then
        success "App tests: $APP_DIR/ClaudeTraceMenuBarTests"
    fi

    echo ""
}

# Run trace
run_trace() {
    exec "$CLI_DIR/claude-trace" "$@"
}

# Run CLI tests (bats)
test_cli() {
    info "Running CLI tests..."

    # Check if bats is installed
    if ! command -v bats &>/dev/null; then
        error "bats-core not installed. Install with: brew install bats-core"
        return 1
    fi

    # Run bats tests
    if bats "$CLI_DIR/tests/claude-trace.bats"; then
        success "CLI tests passed"
    else
        error "CLI tests failed"
        return 1
    fi
}

# Run Swift app tests (Swift Package)
test_app() {
    info "Running Swift app tests..."

    local test_dir="$APP_DIR/ClaudeTraceMenuBarTests"

    # Check if test directory exists
    if [[ ! -d "$test_dir" ]]; then
        echo -e "${YELLOW}⚠ Swift test directory not found: $test_dir${RESET}"
        return 0
    fi

    # Run tests via Swift Package Manager
    if (cd "$test_dir" && swift test 2>&1 | grep -E '(Test Suite|Test Case|passed|failed|error:|Executed)'); then
        success "Swift app tests passed"
    else
        error "Swift app tests failed"
        return 1
    fi
}

# Run all tests
test_all() {
    local failed=0

    echo -e "\n${BOLD}Running All Tests${RESET}"
    echo -e "${DIM}$(printf '─%.0s' {1..40})${RESET}\n"

    # CLI tests
    if ! test_cli; then
        failed=1
    fi

    echo ""

    # App tests
    if ! test_app; then
        failed=1
    fi

    echo ""

    if [[ $failed -eq 0 ]]; then
        success "All tests passed"
    else
        error "Some tests failed"
        return 1
    fi
}

# Clean
run_clean() {
    info "Cleaning..."
    rm -rf "$PROJECT_DIR/build" 2>/dev/null || true
    cd "$CLI_DIR" && cargo clean 2>/dev/null || true
    success "Clean complete"
}

# Main
main() {
    cd "$PROJECT_DIR"

    case "${1:-}" in
        deploy)
            deploy
            ;;
        trace)
            shift || true
            run_trace "$@"
            ;;
        test)
            test_all
            ;;
        test-cli)
            test_cli
            ;;
        test-app)
            test_app
            ;;
        clean)
            run_clean
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            show_status
            ;;
        *)
            error "Unknown command: $1"
            echo "Run './dev.sh help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
