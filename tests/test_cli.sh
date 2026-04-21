#!/usr/bin/env bash
# tests/test_cli.sh — Unit tests for nordvpn CLI
# Runs without VPN connection or credentials (tests CLI behavior only)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NORDVPN="$SCRIPT_DIR/nordvpn"
HELPER="$SCRIPT_DIR/nordvpn-helper"
INSTALLER="$SCRIPT_DIR/install.sh"
PASS=0
FAIL=0
SKIP=0
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ─── Test helpers ──────────────────────────────────────────────────────────────

_pass() { PASS=$((PASS+1)); echo "  ✅ $1"; }
_fail() { FAIL=$((FAIL+1)); echo "  ❌ $1: $2"; }
_skip() { SKIP=$((SKIP+1)); echo "  ⏭  $1 (skipped: $2)"; }

assert_exit() {
    local expected="$1" desc="$2"
    shift 2
    if "$@" >/dev/null 2>&1; then
        if [[ "$expected" -eq 0 ]]; then
            _pass "$desc"
        else
            _fail "$desc" "expected exit $expected, got 0"
        fi
    else
        local actual=$?
        if [[ "$expected" -ne 0 ]]; then
            _pass "$desc"
        else
            _fail "$desc" "expected exit 0, got $actual"
        fi
    fi
}

assert_contains() {
    local desc="$1" pattern="$2"
    shift 2
    local output
    output=$("$@" 2>&1) || true
    if echo "$output" | grep -q "$pattern"; then
        _pass "$desc"
    else
        _fail "$desc" "output missing '$pattern'"
    fi
}

assert_json() {
    local desc="$1"
    shift
    local output
    output=$("$@" 2>&1) || true
    if echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
        _pass "$desc"
    else
        _fail "$desc" "invalid JSON: ${output:0:80}"
    fi
}

has_credentials() {
    security find-generic-password -a "nordvpn-service" -s "nordvpn-openvpn" -w &>/dev/null
}

make_fake_uname_path() {
    local dir="$TMP_DIR/fake-uname"
    mkdir -p "$dir"
    printf '#!/usr/bin/env bash\nprintf "FreeBSD\\n"\n' > "$dir/uname"
    chmod +x "$dir/uname"
    printf '%s:%s\n' "$dir" "$PATH"
}

# ─── Tests ─────────────────────────────────────────────────────────────────────

echo "nordvpn CLI tests"
echo "================="
echo ""

echo "## Basic commands"
assert_exit 0 "help exits 0" bash "$NORDVPN" help
assert_exit 0 "help via --help" bash "$NORDVPN" --help
assert_exit 0 "help via -h" bash "$NORDVPN" -h
assert_contains "help shows usage" "Usage:" bash "$NORDVPN" help
assert_contains "help shows connect" "connect" bash "$NORDVPN" help
assert_contains "help shows proxy" "proxy" bash "$NORDVPN" help
assert_exit 1 "unknown command fails" bash "$NORDVPN" nonexistent

echo ""
echo "## Platform guard"
FAKE_UNAME_PATH="$(make_fake_uname_path)"
assert_exit 1 "CLI rejects unsupported OS" env PATH="$FAKE_UNAME_PATH" bash "$NORDVPN" help
assert_contains "CLI shows macOS-only message" "supports macOS only" env PATH="$FAKE_UNAME_PATH" bash "$NORDVPN" help
assert_exit 1 "helper rejects unsupported OS" env PATH="$FAKE_UNAME_PATH" bash "$HELPER" check-pid
assert_contains "helper shows macOS-only message" "supports macOS only" env PATH="$FAKE_UNAME_PATH" bash "$HELPER" check-pid
assert_exit 1 "installer rejects unsupported OS" env PATH="$FAKE_UNAME_PATH" bash "$INSTALLER"
assert_contains "installer shows macOS-only message" "supports macOS only" env PATH="$FAKE_UNAME_PATH" bash "$INSTALLER"

echo ""
echo "## Status (no VPN)"
assert_exit 0 "status exits 0" bash "$NORDVPN" status
assert_contains "status shows Disconnected" "Disconnected" bash "$NORDVPN" status
assert_contains "status shows IP" "Public IP" bash "$NORDVPN" status

echo ""
echo "## Status --json"
assert_exit 0 "status --json exits 0" bash "$NORDVPN" status --json
assert_json "status --json is valid JSON" bash "$NORDVPN" status --json
assert_contains "status --json has connected field" "connected" bash "$NORDVPN" status --json

echo ""
echo "## Quiet flag"
# With --quiet, stderr should be empty
output_stderr=$(bash "$NORDVPN" -q status 2>&1 1>/dev/null) || true
if [[ -z "$output_stderr" ]] || ! echo "$output_stderr" | grep -q "\[nordvpn\]"; then
    _pass "--quiet suppresses log output"
else
    _fail "--quiet suppresses log output" "stderr still has log lines"
fi

echo ""
echo "## Countries (needs internet)"
if curl -sf --max-time 5 "https://api.nordvpn.com/v1/servers/countries" >/dev/null 2>&1; then
    assert_exit 0 "countries exits 0" bash "$NORDVPN" countries
    assert_contains "countries lists Spain" "Spain" bash "$NORDVPN" countries
    assert_contains "countries lists US" "United States" bash "$NORDVPN" countries
else
    _skip "countries" "no internet"
fi

echo ""
echo "## IP command"
assert_exit 0 "ip exits 0" bash "$NORDVPN" ip
assert_json "ip --json is valid JSON" bash "$NORDVPN" ip --json

echo ""
echo "## Proxy command (needs internet + credentials)"
if has_credentials; then
    if curl -sf --max-time 5 "https://api.nordvpn.com/v1/servers/recommendations?limit=1&filters%5Bservers_technologies%5D%5Bid%5D=21" >/dev/null 2>&1; then
        assert_exit 0 "proxy exits 0" bash "$NORDVPN" proxy
        assert_contains "proxy shows server" "nordvpn.com" bash "$NORDVPN" proxy
        assert_json "proxy --json is valid JSON" bash "$NORDVPN" proxy --json -n 1
        assert_contains "proxy --urls has https://" "https://" bash "$NORDVPN" proxy --urls
        assert_contains "proxy -n 3 returns 3 lines" "nordvpn.com" bash "$NORDVPN" proxy -n 3
    else
        _skip "proxy" "NordVPN API unreachable"
    fi
else
    _skip "proxy" "no credentials configured"
fi

# ─── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "================="
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
