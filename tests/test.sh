#!/usr/bin/env bash
# tests/test.sh — Simple test framework for nordvpn-cli
# shellcheck disable=SC2155

set -euo pipefail

###############################################################################
# Configuration
###############################################################################
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NORDVPN="${REPO_ROOT}/nordvpn"
TESTS_PASSED=0
TESTS_FAILED=0

###############################################################################
# Test utilities
###############################################################################

_assert_exit_0() {
    local cmd="$1" desc="${2:-}"
    if eval "$cmd" > /tmp/test.out 2>&1; then
        _pass "$desc ($cmd)"
        return 0
    else
        _fail "$desc ($cmd)"
        return 1
    fi
}

_assert_exit_nonzero() {
    local cmd="$1" desc="${2:-}"
    if ! eval "$cmd" > /tmp/test.out 2>&1; then
        _pass "$desc ($cmd)"
        return 0
    else
        _fail "$desc ($cmd)"
        return 1
    fi
}

_assert_contains() {
    local cmd="$1" pattern="$2" desc="${3:-}"
    local output
    output=$(eval "$cmd" 2>&1 || true)
    if echo "$output" | grep -q "$pattern"; then
        _pass "$desc ($cmd contains $pattern)"
        return 0
    else
        _fail "$desc ($cmd contains $pattern)"
        echo "  Output: $output" >&2
        return 1
    fi
}

_assert_json() {
    local cmd="$1" desc="${2:-}"
    local output
    output=$(eval "$cmd" 2>&1 || true)
    if echo "$output" | python3 -m json.tool >/dev/null 2>&1; then
        _pass "$desc ($cmd outputs valid JSON)"
        return 0
    else
        _fail "$desc ($cmd outputs valid JSON)"
        echo "  Output: $output" >&2
        return 1
    fi
}

_pass() {
    echo "✓ $1"
    ((TESTS_PASSED++))
}

_fail() {
    echo "✗ $1"
    ((TESTS_FAILED++))
}

_section() {
    echo ""
    echo "━━━ $1 ━━━"
}

###############################################################################
# Tests (no VPN tunnel required)
###############################################################################

test_help() {
    _section "Help and usage"
    _assert_exit_0 "$NORDVPN help" "help command exits 0"
    _assert_contains "$NORDVPN help" "Usage:" "help shows usage"
    _assert_contains "$NORDVPN help" "connect" "help mentions connect command"
}

test_status_disconnected() {
    _section "Status (disconnected state)"
    _assert_exit_0 "$NORDVPN -q status" "status exits 0"
    _assert_contains "$NORDVPN -q status" "VPN Status:" "status shows status line"
}

test_status_json() {
    _section "Status JSON output"
    _assert_json "$NORDVPN status --json" "status --json outputs valid JSON"
}

test_countries() {
    _section "Countries listing"
    _assert_exit_0 "$NORDVPN -q countries" "countries exits 0"
    _assert_contains "$NORDVPN -q countries" "ES" "countries lists ES"
    _assert_contains "$NORDVPN -q countries" "US" "countries lists US"
}

test_cities() {
    _section "Cities listing"
    _assert_exit_0 "$NORDVPN -q cities ES" "cities ES exits 0"
    _assert_contains "$NORDVPN -q cities ES" "Madrid" "cities ES lists Madrid"
}

test_ip() {
    _section "IP lookup (requires internet, no VPN)"
    # This test requires real internet access
    _assert_exit_0 "$NORDVPN -q ip" "ip exits 0" || true
}

test_ip_json() {
    _section "IP JSON output"
    _assert_json "$NORDVPN ip --json" "ip --json outputs valid JSON" || true
}

test_unknown_command() {
    _section "Error handling"
    _assert_exit_nonzero "$NORDVPN invalid-command" "unknown command exits non-zero"
}

test_quiet_flag() {
    _section "Quiet flag"
    local output
    output=$($NORDVPN -q help 2>&1 || true)
    if [[ -z "$output" ]]; then
        _pass "quiet flag suppresses output"
        ((TESTS_PASSED++))
    else
        _fail "quiet flag should suppress output"
        echo "  Got output: $output" >&2
        ((TESTS_FAILED++))
    fi
}

###############################################################################
# Run all tests
###############################################################################

main() {
    echo "═══════════════════════════════════════"
    echo "  nordvpn-cli test suite"
    echo "═══════════════════════════════════════"
    echo ""
    echo "Note: Tests that require credentials or VPN are skipped."
    echo "Run: nordvpn setup  to configure credentials first."
    echo ""

    test_help
    test_status_disconnected
    test_status_json
    test_countries
    test_cities
    test_ip || true
    test_ip_json || true
    test_unknown_command
    test_quiet_flag

    echo ""
    echo "═══════════════════════════════════════"
    echo "  Results"
    echo "═══════════════════════════════════════"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "All tests passed! ✓"
        exit 0
    else
        echo "Some tests failed. ✗"
        exit 1
    fi
}

main "$@"
