#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# QChain — Unified Test & Benchmark Orchestrator
#
# Provides an all-in-one runner for:
#   Option 1: Unit Tests & Go Benchmarks (via Docker Builder)
#   Option 2: Algo Cryptographic Benchmarks (ML-DSA-44/65/87)
#   Option 3: End-to-End API Test Suite (17 suites, 127 assertions)
#   Option 4: Statistical E2E Latency Benchmark (Verification & Workflow Time)
#   Option 5: Run EVERYTHING and output full presentation summary
#
# Usage:
#   bash tests/run_all_tests.sh [OPTION] [API_URL]
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
API_URL="${2:-http://localhost:3000}"

run_unit_and_benchmarks() {
    echo ""
    echo "==================================================================="
    echo "  Running Offchain Unit Tests & Benchmarks via Docker Builder"
    echo "==================================================================="
    cd "$REPO_ROOT/offchain"
    
    echo "Checking / building builder image..."
    docker build --target builder -t qchain-api:test .
    
    echo ""
    echo "--- 1. Running Unit Tests ---"
    docker run --rm qchain-api:test go test -v -count=1 ./...
    
    echo ""
    echo "--- 2. Running Verification & PQC Benchmarks ---"
    docker run --rm qchain-api:test go test -bench=. -benchmem -run=^$ ./...
}

run_algo_benchmarks() {
    echo ""
    echo "==================================================================="
    echo "  Running Algo Benchmarks (ML-DSA Speed & Workflow)"
    echo "==================================================================="
    if [ -d "$REPO_ROOT/algo-benchmarking/go-native" ] && command -v go >/dev/null 2>&1; then
        echo "Running pure Go native benchmarks (Cloudflare CIRCL)..."
        cd "$REPO_ROOT/algo-benchmarking/go-native"
        go test -bench=. -benchmem
    fi

    if [ -d "$REPO_ROOT/algo-benchmarking/go-bindings" ]; then
        echo "Running Docker liboqs-go benchmarks (Optimized C-Bindings)..."
        cd "$REPO_ROOT/algo-benchmarking/go-bindings"
        docker build -t qchain-algo-bench .
        docker run --rm --entrypoint go qchain-algo-bench test -bench=. -benchmem
    fi
}

run_e2e_tests() {
    echo ""
    echo "==================================================================="
    echo "  Running End-to-End API Test Suite against: $API_URL"
    echo "==================================================================="
    cd "$REPO_ROOT"
    bash "$SCRIPT_DIR/e2e_api_test.sh" "$API_URL"
}

run_e2e_benchmarks() {
    echo ""
    echo "==================================================================="
    echo "  Running Statistical E2E Latency Benchmark against: $API_URL"
    echo "==================================================================="
    cd "$REPO_ROOT"
    bash "$SCRIPT_DIR/benchmark_e2e.sh" "$API_URL" 10
}

show_menu() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo "                 QChain Test & Presentation Suite                  "
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  1) Run Unit Tests & PQC Benchmarks (Docker Builder)"
    echo "  2) Run Algo Benchmarks (ML-DSA-44/65/87 liboqs & CIRCL)"
    echo "  3) Run Full End-to-End API Test Suite (Pass/Fail Verification)"
    echo "  4) Run Statistical E2E Latency Benchmark (Verification & Workflow)"
    echo "  5) Run ALL Tests & Generate Presentation Metrics"
    echo "  q) Quit"
    echo "═══════════════════════════════════════════════════════════════════"
    read -r -p "Select an option [1-5]: " choice
    case "$choice" in
        1) run_unit_and_benchmarks ;;
        2) run_algo_benchmarks ;;
        3) run_e2e_tests ;;
        4) run_e2e_benchmarks ;;
        5)
           run_unit_and_benchmarks
           run_e2e_tests
           run_e2e_benchmarks
           ;;
        q|Q) exit 0 ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
}

CHOICE="${1:-}"
if [ -z "$CHOICE" ]; then
    show_menu
else
    case "$CHOICE" in
        1|unit) run_unit_and_benchmarks ;;
        2|algo) run_algo_benchmarks ;;
        3|e2e) run_e2e_tests ;;
        4|bench) run_e2e_benchmarks ;;
        5|all)
           run_unit_and_benchmarks
           run_e2e_tests
           run_e2e_benchmarks
           ;;
        *) echo "Unknown option: $CHOICE. Use: 1, 2, 3, 4, 5 or all"; exit 1 ;;
    esac
fi
