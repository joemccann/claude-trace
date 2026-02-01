#!/usr/bin/env bash
#
# dev.sh - Build and deploy claude-trace
#
# Usage:
#   ./dev.sh              # Show status
#   ./dev.sh deploy       # Build and deploy everything (CLI + app)
#   ./dev.sh trace        # Run claude-trace
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
APP_PROJECT="$PROJECT_DIR/apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar.xcodeproj"

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
    clean       Remove build artifacts
    help        Show this help

EXAMPLES:
    ./dev.sh deploy         # Full build and deploy
    ./dev.sh trace          # One-shot process list
    ./dev.sh trace -v       # Verbose mode
    ./dev.sh trace -w       # Watch mode
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
    echo ""
}

# Run trace
run_trace() {
    exec "$CLI_DIR/claude-trace" "$@"
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
