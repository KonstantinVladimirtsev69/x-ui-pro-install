#!/usr/bin/env bash
set -e

# Test install.sh client name input logic in simulated subshell

simulate_input() {
    local input="$1"
    local ip="13.143.163.236"
    local host="play2go"

    local IP4="$ip"
    local IP_LAST="${IP4##*.}"
    local HOST_SHORT="$host"
    local DEFAULT_CLIENT="${HOST_SHORT}-${IP_LAST}"

    local INPUT_CLIENT=$(echo "$input" | tr -dc 'a-zA-Z0-9_-' | tr '[:upper:]' '[:lower:]')

    local CLIENT_NAME
    if [[ -z "$INPUT_CLIENT" ]]; then
        CLIENT_NAME="$DEFAULT_CLIENT"
    else
        if [[ "$INPUT_CLIENT" =~ -${IP_LAST}$ ]]; then
            CLIENT_NAME="$INPUT_CLIENT"
        else
            CLIENT_NAME="${INPUT_CLIENT}-${IP_LAST}"
        fi
    fi
    echo "$CLIENT_NAME"
}

res1=$(simulate_input "")
[[ "$res1" == "play2go-236" ]] || { echo "Test 1 failed: $res1"; exit 1; }

res2=$(simulate_input "konstantin")
[[ "$res2" == "konstantin-236" ]] || { echo "Test 2 failed: $res2"; exit 1; }

res3=$(simulate_input "konstantin-236")
[[ "$res3" == "konstantin-236" ]] || { echo "Test 3 failed: $res3"; exit 1; }

echo "Install wrapper simulation tests passed!"
