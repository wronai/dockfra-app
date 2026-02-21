# ═══════════════════════════════════════════════════════════════
# DOCKFRA APP — Isolated Testing Environment
# ═══════════════════════════════════════════════════════════════
# Run from app folder: make <target>
#
# This Makefile allows testing ssh-developer in isolation,
# without the full Dockfra management stack.
# ═══════════════════════════════════════════════════════════════

CONTAINER   ?= dockfra-ssh-developer
ROLE_USER   ?= developer
EXEC        := docker exec -u $(ROLE_USER) $(CONTAINER) bash -lc
EXEC_ROOT   := docker exec $(CONTAINER) bash -lc

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show available commands
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║         🧪 DOCKFRA APP — Isolated Testing                    ║"
	@echo "╠══════════════════════════════════════════════════════════════╣"
	@echo "║  Container Management:                                       ║"
	@echo "║    make up              — Start ssh-developer only           ║"
	@echo "║    make down            — Stop ssh-developer                ║"
	@echo "║    make shell           — Open interactive shell            ║"
	@echo "║    make logs            — Tail container logs               ║"
	@echo "║                                                              ║"
	@echo "║  Git Debug (inside container):                              ║"
	@echo "║    make git-status       — Show git status in /repo         ║"
	@echo "║    make git-remote       — Show configured remotes           ║"
	@echo "║    make git-log          — Show recent commits               ║"
	@echo "║    make git-init         — Initialize /repo if missing      ║"
	@echo "║    make git-set-remote   — Set origin remote URL=...        ║"
	@echo "║    make git-test-push    — Test push to remote              ║"
	@echo "║    make git-test-pull    — Test pull from remote            ║"
	@echo "║                                                              ║"
	@echo "║  LLM Debug:                                                  ║"
	@echo "║    make llm-test         — Test LLM connection              ║"
	@echo "║    make llm-config       — Show LLM config (key masked)     ║"
	@echo "║                                                              ║"
	@echo "║  Code Generation Debug:                                     ║"
	@echo "║    make gen-test         — Test file extraction from LLM    ║"
	@echo "║    make gen-where        — Show where files are written     ║"
	@echo "║                                                              ║"
	@echo "║  Full Pipeline Test:                                        ║"
	@echo "║    make test-pipeline T=T-0001  — Run full pipeline test    ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@echo ""

# ═══════════════════════════════════════════════════════════════
# CONTAINER MANAGEMENT
# ═══════════════════════════════════════════════════════════════

.PHONY: up
up: ## Start ssh-developer container only (minimal deps)
	@echo "🚀 Starting ssh-developer container..."
	docker compose up -d ssh-developer
	@echo "✅ Container started. Run 'make shell' to enter."

.PHONY: down
down: ## Stop ssh-developer container
	@echo "🛑 Stopping ssh-developer..."
	docker compose stop ssh-developer

.PHONY: shell
shell: ## Open interactive shell in container
	@docker exec -it -u $(ROLE_USER) $(CONTAINER) bash

.PHONY: logs
logs: ## Tail container logs
	@docker logs -f $(CONTAINER)

.PHONY: restart
restart: down up ## Restart container

# ═══════════════════════════════════════════════════════════════
# GIT DEBUG
# ═══════════════════════════════════════════════════════════════

.PHONY: git-status
git-status: ## Show git status in /repo
	@echo "📋 Git status in /repo:"
	@$(EXEC) "cd /repo && git status"

.PHONY: git-remote
git-remote: ## Show configured git remotes
	@echo "🔗 Git remotes in /repo:"
	@$(EXEC) "cd /repo && git remote -v || echo 'No remotes configured'"

.PHONY: git-log
git-log: ## Show recent commits
	@echo "📜 Recent commits in /repo:"
	@$(EXEC) "cd /repo && git log --oneline -10 || echo 'No commits yet'"

.PHONY: git-init
git-init: ## Initialize /repo if missing
	@echo "🔧 Initializing /repo..."
	@$(EXEC) "if [ ! -d /repo/.git ]; then git init /repo && echo 'Initialized'; else echo 'Already initialized'; fi"

.PHONY: git-set-remote
git-set-remote: ## Set origin remote: make git-set-remote URL=git@github.com:...
	@[ -n "$(URL)" ] || (echo "Usage: make git-set-remote URL=git@github.com:user/repo.git" && exit 1)
	@echo "🔗 Setting origin to $(URL)..."
	@$(EXEC) "cd /repo && git remote remove origin 2>/dev/null || true; git remote add origin $(URL) && git remote -v"

.PHONY: git-test-push
git-test-push: ## Test push to remote (dry-run)
	@echo "🧪 Testing git push..."
	@$(EXEC) "cd /repo && git push --dry-run origin HEAD 2>&1 || echo 'Push test failed - check remote/credentials'"

.PHONY: git-test-pull
git-test-pull: ## Test pull from remote
	@echo "🧪 Testing git pull..."
	@$(EXEC) "cd /repo && git fetch origin 2>&1 && git status || echo 'Pull test failed - check remote/credentials'"

.PHONY: git-config-debug
git-config-debug: ## Show full git config
	@echo "⚙️ Git config:"
	@$(EXEC) "git config --list --show-origin | grep -E '(user|remote|credential)' || echo 'No relevant config'"

# ═══════════════════════════════════════════════════════════════
# LLM DEBUG
# ═══════════════════════════════════════════════════════════════

.PHONY: llm-test
llm-test: ## Test LLM connection with simple prompt
	@echo "🧪 Testing LLM connection..."
	@$(EXEC) "python3 -c 'import sys; sys.path.insert(0, \"/shared/lib\"); import llm_client; print(llm_client.chat(\"Say OK\"))'"

.PHONY: llm-config
llm-config: ## Show LLM config (key masked)
	@echo "⚙️ LLM Configuration:"
	@$(EXEC) "python3 -c 'import sys; sys.path.insert(0, \"/shared/lib\"); import llm_client; c=llm_client.get_config(); print(f\"Model: {c[\\\"model\\\"]}\"); print(f\"API Key: {c[\\\"api_key\\\"][:12]}...{c[\\\"api_key\\\"][-4:] if len(c[\\\"api_key\\\"])>16 else \\\"(too short)\\\"}\"); print(f\"Max tokens: {c[\\\"max_tokens\\\"]}\"); print(f\"Temperature: {c[\\\"temperature\\\"]}\")'"

.PHONY: llm-models
llm-models: ## List available models
	@echo "📋 Available LLM models:"
	@$(EXEC) "python3 -c 'import sys; sys.path.insert(0, \"/shared/lib\"); import llm_client; print(\"\\n\".join(llm_client.list_models()))'"

# ═══════════════════════════════════════════════════════════════
# CODE GENERATION DEBUG
# ═══════════════════════════════════════════════════════════════

.PHONY: gen-test
gen-test: ## Test file extraction from LLM response
	@echo "🧪 Testing file extraction..."
	@$(EXEC) "python3 << 'PYEOF'\nimport sys, os, re; sys.path.insert(0, '/shared/lib')\ntest_response = '''Here is the implementation:\n\n**File: `src/test.py`**\n```python\ndef hello():\n    print(\"Hello\")\n```\n\n**File: `src/other.js`**\n```javascript\nconsole.log(\"test\");\n```\n'''\nlines = test_response.split('\\n')\ncurrent_file = None\nin_code_block = False\ncode_lines = []\nfor i, line in enumerate(lines):\n    if line.startswith('```'):\n        if not in_code_block:\n            in_code_block = True\n            code_lines = []\n            current_file = None\n            for j in range(i-1, max(-1, i-6), -1):\n                m = re.search(r'(?:File|Path).*?[`*]*([a-zA-Z0-9_\\-\\./]+\\.[a-zA-Z0-9]+)[`*]*', lines[j], re.IGNORECASE)\n                if m:\n                    current_file = m.group(1)\n                    break\n        else:\n            in_code_block = False\n            if current_file:\n                print(f'Would write: /repo/{current_file} ({len(code_lines)} lines)')\n            else:\n                print('Code block without filename')\n    elif in_code_block:\n        code_lines.append(line)\nPYEOF"

.PHONY: gen-where
gen-where: ## Show where generated files are written
	@echo "📁 File write destinations:"
	@echo "  engine-implement.sh → /repo/"
	@echo "  implement.sh        → /workspace/app/"
	@echo ""
	@echo "  /repo contents:"
	@$(EXEC) "ls -la /repo/ 2>/dev/null || echo '/repo not found or empty'"
	@echo ""
	@echo "  /workspace/app contents:"
	@$(EXEC) "ls -la /workspace/app/ 2>/dev/null || echo '/workspace/app not found'"

.PHONY: gen-fix-paths
gen-fix-paths: ## Fix implement.sh to use /repo instead of /workspace/app
	@echo "🔧 Fixing implement.sh path..."
	@$(EXEC_ROOT) "sed -i 's|/workspace/app|/repo|g' /home/developer/scripts/implement.sh"
	@echo "✅ Fixed. Verify with: make gen-where"

# ═══════════════════════════════════════════════════════════════
# FULL PIPELINE TEST
# ═══════════════════════════════════════════════════════════════

.PHONY: test-pipeline
test-pipeline: ## Run full pipeline test: make test-pipeline T=T-0001
	@[ -n "$(T)" ] || (echo "Usage: make test-pipeline T=T-0001" && exit 1)
	@echo "🧪 Running pipeline test for $(T)..."
	@$(EXEC) "engine-implement built_in $(T)"
	@echo ""
	@echo "📋 Checking generated files..."
	@$(EXEC) "ls -la /repo/"
	@echo ""
	@echo "📝 Git status:"
	@$(EXEC) "cd /repo && git status"

.PHONY: test-commit
test-commit: ## Test commit-push script
	@echo "🧪 Testing commit-push..."
	@$(EXEC) "cd /repo && git status"
	@echo ""
	@$(EXEC) "commit-push 'test: pipeline check'"

# ═══════════════════════════════════════════════════════════════
# ENVIRONMENT DEBUG
# ═══════════════════════════════════════════════════════════════

.PHONY: env-show
env-show: ## Show relevant environment variables (masked)
	@echo "🔐 Environment variables:"
	@$(EXEC) "env | grep -E '(LLM|OPENROUTER|GIT|DEVELOPER)' | sed 's/\\(API_KEY=....\\).*/\\1****/' | sed 's/\\(KEY=....\\).*/\\1****/'"

.PHONY: ssh-keys
ssh-keys: ## Show SSH keys status
	@echo "🔑 SSH keys:"
	@$(EXEC) "ls -la ~/.ssh/ 2>/dev/null || echo 'No .ssh directory'"
	@$(EXEC) "ls -la ~/.ssh/extra/ 2>/dev/null || echo 'No extra keys'"
