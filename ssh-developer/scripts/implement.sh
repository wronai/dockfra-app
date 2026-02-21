#!/bin/bash
export PYTHONPATH="/shared/lib:${PYTHONPATH:-}"
TICKET_ID="${1:-}"
[ -z "$TICKET_ID" ] && { echo "Usage: implement <T-XXXX>"; exit 1; }

python3 - "$TICKET_ID" << 'PYEOF'
import sys, os, re, json; sys.path.insert(0, '/shared/lib')
import ticket_system, llm_client

TICKET_ID = sys.argv[1]
t = ticket_system.get(TICKET_ID)
if not t:
    print('Ticket not found')
    sys.exit(1)

print(f"Ticket: {t['title']}")
print(f"Description: {t.get('description', '')}\n")

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
            
            for j in range(i-1, max(-1, i-6), -1):
                m = re.search(r'(?:File|Path).*?[`\*]*([a-zA-Z0-9\_\-\.\/]+\.[a-zA-Z0-9]+)[`\*]*', lines[j], re.IGNORECASE)
                if m:
                    current_file = m.group(1)
                    break
            
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

ticket_system.add_comment(TICKET_ID, 'developer', 'AI-assisted implementation generated and files extracted.')
ticket_system.update(TICKET_ID, status='in_progress')
PYEOF
