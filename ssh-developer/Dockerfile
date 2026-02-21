# ssh-developer — extends shared/Dockerfile.ssh-base
FROM dockfra-ssh-base

# Developer-specific extras
RUN apt-get update && apt-get install -y --no-install-recommends \
    htop python3-venv python3-pytest make nodejs npm && \
    pip3 install --break-system-packages flask pytest httpx black flake8 && \
    rm -rf /var/lib/apt/lists/*

# Autonomous dev engines (installed best-effort — container works even if these fail)
RUN pip3 install --break-system-packages aider-chat || true
RUN npm install -g @anthropic-ai/claude-code || true
# OpenCode — Go binary CLI agent (https://github.com/opencode-ai/opencode)
RUN ARCH=$(dpkg --print-architecture) && \
    (curl -fsSL "https://github.com/opencode-ai/opencode/releases/latest/download/opencode_Linux_${ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin opencode 2>/dev/null && chmod +x /usr/local/bin/opencode) || \
    echo "OpenCode install skipped (binary not available for ${ARCH})"

# Role user
RUN echo "AllowUsers developer" >> /etc/ssh/sshd_config && \
    useradd -m -s /bin/bash -G sudo developer && \
    echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/developer

# Ensure pip-installed tools are on PATH for developer user
ENV PATH="/home/developer/.local/bin:/usr/local/bin:${PATH}"

COPY entrypoint.sh /entrypoint.sh
COPY motd /etc/motd
COPY scripts/ /home/developer/scripts/
RUN chmod +x /entrypoint.sh /home/developer/scripts/*.sh 2>/dev/null; \
    chown -R developer:developer /home/developer
