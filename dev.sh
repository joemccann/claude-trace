#!/usr/bin/env bash
#
# dev.sh - Build and run claude-trace tools locally
#
# Usage:
#   ./dev.sh              # Build all and show status
#   ./dev.sh build        # Build Rust binary only
#   ./dev.sh trace        # Run the Bash monitor (claude-trace)
#   ./dev.sh diagnose     # Run the Rust diagnostics (claude-diagnose)
#   ./dev.sh watch        # Run trace in watch mode
#   ./dev.sh test         # Run all tests
#   ./dev.sh clean        # Clean build artifacts
#   ./dev.sh help         # Show this help
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_BINARY="$PROJECT_DIR/target/release/claude-diagnose"
BASH_SCRIPT="$PROJECT_DIR/claude-trace"

# Print colored status message
info() { echo -e "${CYAN}▸${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET} $*"; }
error() { echo -e "${RED}✗${RESET} $*" >&2; }

show_help() {
    cat << 'EOF'
claude-trace Development Script

USAGE:
    ./dev.sh [COMMAND] [OPTIONS]

COMMANDS:
    build           Build the Rust binary (release mode)
    trace [opts]    Run the Bash monitor (claude-trace)
    diagnose [opts] Run the Rust diagnostics (claude-diagnose)
    watch [secs]    Run trace in watch mode (default: 2s interval)
    test            Run Rust tests and validate scripts
    clean           Remove build artifacts
    help            Show this help message

EXAMPLES:
    ./dev.sh                    # Build all, show status
    ./dev.sh build              # Build Rust binary
    ./dev.sh trace              # One-shot process list
    ./dev.sh trace -v           # Verbose mode
    ./dev.sh trace -j | jq      # JSON output
    ./dev.sh watch 5            # Watch mode, 5s refresh
    ./dev.sh diagnose --help    # Show diagnose options
    ./dev.sh diagnose -d -s     # Run diagnostics with sampling

NOTES:
    - The Bash script (claude-trace) requires no build step
    - The Rust binary requires 'cargo' to build
    - Some diagnose features require sudo (DTrace, dtruss)
EOF
}

# Check prerequisites
check_prereqs() {
    local missing=()

    if ! command -v cargo &>/dev/null; then
        missing+=("cargo (install via rustup: https://rustup.rs)")
    fi

    if ! command -v bash &>/dev/null; then
        missing+=("bash")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing prerequisites:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

# Build the Rust binary
build_rust() {
    info "Building Rust binary (release mode)..."
    cd "$PROJECT_DIR"

    if cargo build --release; then
        success "Built: $RUST_BINARY"
        ls -lh "$RUST_BINARY" 2>/dev/null | awk '{print "  Size: " $5}'
    else
        error "Rust build failed"
        exit 1
    fi
}

# Show project status
show_status() {
    echo -e "\n${BOLD}claude-trace Development Status${RESET}"
    echo -e "${DIM}$(printf '─%.0s' {1..50})${RESET}\n"

    # Bash script status
    if [[ -x "$BASH_SCRIPT" ]]; then
        success "claude-trace (Bash): Ready"
        echo -e "  ${DIM}$BASH_SCRIPT${RESET}"
    else
        warn "claude-trace (Bash): Not executable"
        echo -e "  ${DIM}Run: chmod +x $BASH_SCRIPT${RESET}"
    fi

    # Rust binary status
    if [[ -x "$RUST_BINARY" ]]; then
        local size
        size=$(ls -lh "$RUST_BINARY" 2>/dev/null | awk '{print $5}')
        local mtime
        mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$RUST_BINARY" 2>/dev/null || stat -c "%y" "$RUST_BINARY" 2>/dev/null | cut -d. -f1)
        success "claude-diagnose (Rust): Ready"
        echo -e "  ${DIM}$RUST_BINARY${RESET}"
        echo -e "  ${DIM}Size: $size | Built: $mtime${RESET}"
    else
        warn "claude-diagnose (Rust): Not built"
        echo -e "  ${DIM}Run: ./dev.sh build${RESET}"
    fi

    echo ""
}

# Run the Bash trace script
run_trace() {
    if [[ ! -x "$BASH_SCRIPT" ]]; then
        warn "Making claude-trace executable..."
        chmod +x "$BASH_SCRIPT"
    fi

    exec "$BASH_SCRIPT" "$@"
}

# Run the Rust diagnose binary
run_diagnose() {
    if [[ ! -x "$RUST_BINARY" ]]; then
        warn "Rust binary not found, building..."
        build_rust
    fi

    exec "$RUST_BINARY" "$@"
}

# Run in watch mode
run_watch() {
    local interval="${1:-2}"
    run_trace -w "$interval"
}

# Run tests
run_tests() {
    info "Running Rust tests..."
    cd "$PROJECT_DIR"
    cargo test

    info "Validating Bash script syntax..."
    if bash -n "$BASH_SCRIPT"; then
        success "Bash syntax OK"
    else
        error "Bash syntax check failed"
        exit 1
    fi

    info "Testing Bash script help..."
    if "$BASH_SCRIPT" --help >/dev/null 2>&1; then
        success "Bash --help works"
    else
        error "Bash --help failed"
        exit 1
    fi

    info "Testing Rust binary help..."
    if [[ -x "$RUST_BINARY" ]]; then
        if "$RUST_BINARY" --help >/dev/null 2>&1; then
            success "Rust --help works"
        else
            error "Rust --help failed"
            exit 1
        fi
    else
        warn "Skipping Rust help test (binary not built)"
    fi

    echo ""
    success "All tests passed"
}

# Clean build artifacts
run_clean() {
    info "Cleaning build artifacts..."
    cd "$PROJECT_DIR"
    cargo clean
    success "Clean complete"
}

# Main command dispatch
main() {
    cd "$PROJECT_DIR"

    case "${1:-}" in
        build)
            check_prereqs
            build_rust
            ;;
        trace)
            shift || true
            run_trace "$@"
            ;;
        diagnose)
            check_prereqs
            shift || true
            run_diagnose "$@"
            ;;
        watch)
            shift || true
            run_watch "$@"
            ;;
        test)
            check_prereqs
            run_tests
            ;;
        clean)
            run_clean
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            # Default: build and show status
            check_prereqs
            build_rust
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
