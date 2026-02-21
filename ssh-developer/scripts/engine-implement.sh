#!/bin/bash
# engine-implement.sh — Implement a ticket using the selected dev engine
# Usage: engine-implement <ENGINE_ID> <TICKET_ID>
# Engines: built_in, aider, claude_code
set -euo pipefail
export PYTHONPATH="/shared/lib:$PYTHONPATH"

ENGINE="${1:-built_in}"
TICKET_ID="${2:-}"

[ -z "$TICKET_ID" ] && { echo "Usage: engine-implement <engine_id> <ticket_id>"; exit 1; }

# Read ticket info
TICKET_JSON=$(python3 -c "
import sys, json; sys.path.insert(0, '/shared/lib')
import ticket_system
t = ticket_system.get('$TICKET_ID')
if not t: print('{}'); sys.exit(1)
print(json.dumps({'title': t['title'], 'description': t.get('description',''), 'status': t['status']}))
" 2>/dev/null) || { echo "Ticket $TICKET_ID not found"; exit 1; }

TITLE=$(echo "$TICKET_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))")
DESC=$(echo "$TICKET_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('description',''))")

echo "=== Engine: $ENGINE | Ticket: $TICKET_ID ==="
echo "Title: $TITLE"
echo "Description: $DESC"
echo ""

case "$ENGINE" in
    built_in)
        echo "[built_in] Using llm_client.py via OpenRouter..."
        python3 -c "
import sys, json; sys.path.insert(0, '/shared/lib')
import ticket_system, llm_client
t = ticket_system.get('$TICKET_ID')
if not t: print('Ticket not found'); sys.exit(1)
resp = llm_client.chat(
    f'Implement this ticket:\nTitle: {t[\"title\"]}\nDescription: {t.get(\"description\", \"\")}\n\nProvide the code implementation. Write actual files with their paths.',
    system_prompt='You are a senior developer. Write clean, tested code. Include file paths and complete implementations.'
)
print(resp)
ticket_system.add_comment('$TICKET_ID', 'developer', 'AI implementation (built_in engine)')
"
        ;;
    aider)
        echo "[aider] Using Aider autonomous CLI..."
        if ! command -v aider &>/dev/null; then
            echo "FAIL: aider not installed. Run: pip install aider-chat"
            exit 1
        fi
        cd /repo
        # Configure aider for OpenRouter
        export OPENAI_API_BASE="${OPENAI_API_BASE:-https://openrouter.ai/api/v1}"
        export OPENAI_API_KEY="${OPENROUTER_API_KEY:-}"
        MODEL="${LLM_MODEL:-openai/gpt-4o-mini}"
        aider --no-auto-commits --yes \
            --model "openrouter/$MODEL" \
            --message "Implement ticket $TICKET_ID: $TITLE. $DESC. Write actual code files, include tests." \
            2>&1
        python3 -c "
import sys; sys.path.insert(0, '/shared/lib'); import ticket_system
ticket_system.add_comment('$TICKET_ID', 'developer', 'AI implementation (aider engine)')
"
        ;;
    claude_code)
        echo "[claude_code] Using Claude Code CLI..."
        if ! command -v claude &>/dev/null; then
            echo "FAIL: claude not installed. Run: npm i -g @anthropic-ai/claude-code"
            exit 1
        fi
        cd /repo
        claude --print "Implement ticket $TICKET_ID: $TITLE. $DESC. Write actual code, create files, include tests." 2>&1
        python3 -c "
import sys; sys.path.insert(0, '/shared/lib'); import ticket_system
ticket_system.add_comment('$TICKET_ID', 'developer', 'AI implementation (claude_code engine)')
"
        ;;
    *)
        echo "Unknown engine: $ENGINE"
        echo "Available: built_in, aider, claude_code"
        exit 1
        ;;
esac

echo ""
echo "=== Implementation complete (engine: $ENGINE) ==="
