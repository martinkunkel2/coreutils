#!/bin/bash
# GNU Test Analysis Helper Script
# This script provides an easy interface to the GNU test artifact analysis tools.

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_LIMIT=100
DEFAULT_REPO="uutils/coreutils"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
GNU Test Analysis Helper Script

USAGE:
    $0 [OPTIONS] COMMAND

COMMANDS:
    download    Download artifacts and generate statistics
    report      Generate report from existing statistics
    both        Download artifacts and generate report (default)
    example     Run example with limited data
    install     Install Python dependencies

OPTIONS:
    -h, --help           Show this help message
    -l, --limit NUM      Number of workflow runs to analyze (default: $DEFAULT_LIMIT)
    -r, --repo REPO      Repository in format owner/repo (default: $DEFAULT_REPO)
    -t, --token TOKEN    GitHub token (or set GITHUB_TOKEN env var)
    -o, --output DIR     Output directory for artifacts (default: ./artifacts)
    -s, --stats FILE     Statistics output file (default: ./gnu-test-statistics.json)
    -f, --format FORMAT  Report format: markdown, html, json (default: markdown)
    -c, --charts         Generate charts (requires matplotlib)
    -v, --verbose        Enable verbose output

EXAMPLES:
    # Basic usage (requires GITHUB_TOKEN environment variable)
    $0

    # Download last 20 runs and generate HTML report with charts
    $0 -l 20 -f html -c

    # Use specific token and repository
    $0 -t your_token -r yourusername/coreutils -l 15

    # Just generate a report from existing statistics
    $0 report -c

    # Install dependencies
    $0 install

    # Run example with minimal data
    $0 example

SETUP:
    1. Get a GitHub token: https://github.com/settings/tokens
    2. Set environment variable: export GITHUB_TOKEN=your_token
    3. Install dependencies: $0 install
    4. Run analysis: $0

EOF
}

check_dependencies() {
    local missing_deps=()

    if ! python3 -c "import requests" 2>/dev/null; then
        missing_deps+=("requests")
    fi

    if [[ "$GENERATE_CHARTS" == "true" ]]; then
        if ! python3 -c "import matplotlib" 2>/dev/null; then
            missing_deps+=("matplotlib")
        fi
        if ! python3 -c "import seaborn" 2>/dev/null; then
            missing_deps+=("seaborn")
        fi
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing Python dependencies: ${missing_deps[*]}"
        info "Install with: $0 install"
        info "Or manually: pip install ${missing_deps[*]}"
        return 1
    fi

    return 0
}

install_dependencies() {
    info "Installing Python dependencies..."

    local requirements_file="$SCRIPT_DIR/requirements.txt"

    if [[ -f "$requirements_file" ]]; then
        python3 -m pip install -r "$requirements_file"
    else
        warning "Requirements file not found, installing basic dependencies"
        python3 -m pip install requests matplotlib seaborn
    fi

    success "Dependencies installed successfully"
}

download_artifacts() {
    info "Downloading artifacts and generating statistics..."

    local cmd="python3 '$SCRIPT_DIR/download.py'"
    cmd+=" --limit $LIMIT"
    cmd+=" --repo $REPO"
    cmd+=" --output-dir '$OUTPUT_DIR'"
    cmd+=" --stats-file '$STATS_FILE'"

    if [[ -n "$TOKEN" ]]; then
        cmd+=" --token '$TOKEN'"
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        cmd+=" --verbose"
    fi

    info "Running: $cmd"
    eval "$cmd"

    if [[ $? -eq 0 ]]; then
        success "Artifacts downloaded and statistics generated: $STATS_FILE"
    else
        error "Failed to download artifacts"
        return 1
    fi
}

generate_report() {
    if [[ ! -f "$STATS_FILE" ]]; then
        error "Statistics file not found: $STATS_FILE"
        info "Run download first or specify correct file with -s"
        return 1
    fi

    info "Generating report from $STATS_FILE..."

    local cmd="python3 '$SCRIPT_DIR/visualize.py'"
    cmd+=" '$STATS_FILE'"
    cmd+=" --format $FORMAT"
    cmd+=" --output-dir '$OUTPUT_DIR/reports'"

    if [[ "$GENERATE_CHARTS" == "true" ]]; then
        cmd+=" --charts"
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        cmd+=" --verbose"
    fi

    info "Running: $cmd"
    eval "$cmd"

    if [[ $? -eq 0 ]]; then
        success "Report generated in $OUTPUT_DIR/reports/"

        # Show generated files
        local report_dir="$OUTPUT_DIR/reports"
        if [[ -d "$report_dir" ]]; then
            info "Generated files:"
            find "$report_dir" -type f | sort | sed 's/^/  /'
        fi
    else
        error "Failed to generate report"
        return 1
    fi
}

run_example() {
    info "Running example with limited data..."
    python3 "$SCRIPT_DIR/example.py"
}

# Parse command line arguments
COMMAND="both"
LIMIT=$DEFAULT_LIMIT
REPO=$DEFAULT_REPO
TOKEN=""
OUTPUT_DIR="./artifacts"
STATS_FILE="./gnu-test-statistics.json"
FORMAT="markdown"
GENERATE_CHARTS="false"
VERBOSE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--limit)
            LIMIT="$2"
            shift 2
            ;;
        -r|--repo)
            REPO="$2"
            shift 2
            ;;
        -t|--token)
            TOKEN="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -s|--stats)
            STATS_FILE="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -c|--charts)
            GENERATE_CHARTS="true"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        download|report|both|example|install)
            COMMAND="$1"
            shift
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
case $COMMAND in
    install)
        install_dependencies
        exit $?
        ;;
    example)
        run_example
        exit $?
        ;;
    download)
        check_dependencies || exit 1
        download_artifacts
        exit $?
        ;;
    report)
        check_dependencies || exit 1
        generate_report
        exit $?
        ;;
    both)
        check_dependencies || exit 1
        download_artifacts && generate_report
        exit $?
        ;;
    *)
        error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
