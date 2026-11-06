#!/usr/bin/env bash
set -e

# Extract and evaluate resolve_client_name from x-ui-pro.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

eval "$(sed -n '/^resolve_client_name()/,/^}/p' "$REPO_ROOT/x-ui-pro.sh")"

if ! declare -f resolve_client_name >/dev/null; then
    echo "ERROR: resolve_client_name not found in x-ui-pro.sh!"
    exit 1
fi

FAILED=0

run_test() {
    local desc="$1"
    local input="$2"
    local ip="$3"
    local host="$4"
    local expected="$5"

    local actual
    actual=$(resolve_client_name "$input" "$ip" "$host")

    if [[ "$actual" == "$expected" ]]; then
        echo "PASS: $desc (got: $actual)"
    else
        echo "FAIL: $desc (expected: $expected, got: $actual)"
        FAILED=$((FAILED + 1))
    fi
}

echo "=== Running client name resolution tests ==="

# 1. Default fallback to hostname when input is empty
run_test "Default from hostname" "" "13.143.163.236" "play2go" "play2go-236"
run_test "Default from FQDN hostname" "" "13.143.163.236" "play2go.domain.com" "play2go-236"

# 2. Manual input gets IP appended
run_test "Manual input appends IP" "ivan" "13.143.163.236" "play2go" "ivan-236"
run_test "Manual input with uppercase" "MyClient" "13.143.163.236" "play2go" "myclient-236"

# 3. Manual input with IP already appended does NOT duplicate
run_test "No duplicate suffix when already present" "ivan-236" "13.143.163.236" "play2go" "ivan-236"

# 4. Sanitization of spaces and special symbols
run_test "Sanitize spaces and special chars" "ivan @ vpn #1" "13.143.163.236" "play2go" "ivanvpn1-236"

# 5. Fallback if hostname is empty or special
run_test "Empty host and empty input fallback to srv" "" "10.0.0.15" "" "srv-15"

if [[ $FAILED -gt 0 ]]; then
    echo "=== $FAILED tests failed! ==="
    exit 1
else
    echo "=== All tests passed! ==="
    exit 0
fi
