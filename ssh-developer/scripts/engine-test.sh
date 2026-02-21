#!/bin/bash
# engine-test.sh — Test which dev engines are available and working
# Usage: engine-test [engine_id]
# Without args: tests all engines
# With arg: tests specific engine (built_in, aider, claude_code)
set -euo pipefail
export PYTHONPATH="/shared/lib:$PYTHONPATH"

ENGINE="${1:-all}"

test_builtin() {
    echo "=== built_in: Wbudowany LLM (OpenRouter) ==="
    if ! python3 -c "import sys; sys.path.insert(0,'/shared/lib'); import llm_client; print('module OK')" 2>/dev/null; then
        echo "FAIL: llm_client.py not found"
        return 1
    fi
    if [ -z "${OPENROUTER_API_KEY:-}" ]; then
        echo "FAIL: OPENROUTER_API_KEY not set"
        return 1
    fi
    RESP=$(python3 -c "
import sys; sys.path.insert(0,'/shared/lib'); import llm_client
r = llm_client.chat('Say OK in one word', system_prompt='Reply with one word only.')
print(r)
if '[LLM] Error' in r: exit(1)
" 2>&1) || { echo "FAIL: $RESP"; return 1; }
    echo "OK: $RESP"
    return 0
}

test_aider() {
    echo "=== aider: Aider CLI ==="
    if ! command -v aider &>/dev/null; then
        echo "FAIL: aider not installed (pip install aider-chat)"
        return 1
    fi
    VER=$(aider --version 2>&1) || { echo "FAIL: aider broken"; return 1; }
    echo "OK: $VER"
    return 0
}

test_claude() {
    echo "=== claude_code: Claude Code CLI ==="
    if ! command -v claude &>/dev/null; then
        echo "FAIL: claude not installed (npm i -g @anthropic-ai/claude-code)"
        return 1
    fi
    VER=$(claude --version 2>&1) || { echo "FAIL: claude broken"; return 1; }
    echo "OK: $VER"
    return 0
}

RESULTS=""
PASS=0
TOTAL=0

run_test() {
    local name="$1"
    TOTAL=$((TOTAL + 1))
    if "$name" 2>&1; then
        PASS=$((PASS + 1))
        RESULTS="${RESULTS}  ✅ $name\n"
    else
        RESULTS="${RESULTS}  ❌ $name\n"
    fi
    echo ""
}

if [ "$ENGINE" = "all" ]; then
    run_test test_builtin
    run_test test_aider
    run_test test_claude
    echo "=== Podsumowanie ==="
    echo -e "$RESULTS"
    echo "$PASS/$TOTAL silników działa"
elif [ "$ENGINE" = "built_in" ]; then
    test_builtin
elif [ "$ENGINE" = "aider" ]; then
    test_aider
elif [ "$ENGINE" = "claude_code" ]; then
    test_claude
else
    echo "Unknown engine: $ENGINE"
    echo "Available: built_in, aider, claude_code"
    exit 1
fi
