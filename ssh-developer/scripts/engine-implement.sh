#!/bin/bash
# engine-implement.sh — Implement a ticket using the selected dev engine
# Usage: engine-implement <ENGINE_ID> <TICKET_ID>
# Engines: built_in, aider, claude_code
set -euo pipefail
export PYTHONPATH="/shared/lib:${PYTHONPATH:-}"

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
        python3 - "$TICKET_ID" << 'PYEOF'
import sys, os, re; sys.path.insert(0, '/shared/lib')
import ticket_system, llm_client

TICKET_ID = sys.argv[1]
t = ticket_system.get(TICKET_ID)
if not t: sys.exit(1)

prompt = f"""Implement this ticket:
Title: {t['title']}
Description: {t.get('description', '')}

Provide the code implementation. For each file you create or modify, specify the file path BEFORE the code block like this:
**File: `path/to/file.ext`**
```lang
...code...
```"""

system_prompt = "You are a senior developer. Write clean, tested code. Always provide the full absolute or relative file path immediately before the markdown code block so it can be automatically extracted and saved."

resp = llm_client.chat(prompt, system_prompt=system_prompt)
print(resp)

print('\n--- Extracting files ---')
lines = resp.split('\n')
current_file = None
in_code_block = False
code_lines = []

for i, line in enumerate(lines):
    if line.startswith('```'):
        if not in_code_block:
            in_code_block = True
            code_lines = []
            current_file = None
            
            # Look backwards for a file name up to 6 lines
            for j in range(i-1, max(-1, i-6), -1):
                m = re.search(r'(?:File|Path).*?[`\*]*([a-zA-Z0-9\_\-\.\/]+\.[a-zA-Z0-9]+)[`\*]*', lines[j], re.IGNORECASE)
                if m:
                    current_file = m.group(1)
                    break
            
            # fallback to just backticks
            if not current_file:
                for j in range(i-1, max(-1, i-6), -1):
                    m = re.search(r'`([a-zA-Z0-9\_\-\.\/]+\.[a-zA-Z0-9]+)`', lines[j])
                    if m:
                        current_file = m.group(1)
                        break
            
            if not current_file:
                current_file = 'generated_code.txt'
        else:
            in_code_block = False
            if current_file:
                # Remove leading slashes if absolute path is intended to be relative to /repo
                clean_path = current_file.lstrip('/')
                full_path = os.path.join('/repo', clean_path)
                print(f'Writing to {full_path}...')
                os.makedirs(os.path.dirname(full_path) or '.', exist_ok=True)
                with open(full_path, 'w') as f:
                    f.write('\n'.join(code_lines) + '\n')
            else:
                print('Found code block but no filename associated with it. Skipping.')
    elif in_code_block:
        code_lines.append(line)

ticket_system.add_comment(TICKET_ID, 'developer', 'AI implementation (built_in engine)')
PYEOF
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
