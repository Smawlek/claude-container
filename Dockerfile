FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# --- Layer 1: System packages ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    vim \
    nano \
    build-essential \
    openssh-client \
    jq \
    ripgrep \
    unzip \
    zip \
    sudo \
    ca-certificates \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    python3-venv \
    locales \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# --- Layer 2: Node.js 22.x ---
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# --- Layer 3: Docker CLI + compose plugin (no daemon) ---
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
       -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
       https://download.docker.com/linux/ubuntu \
       $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       docker-ce-cli \
       docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# --- Layer 4: Non-root user with passwordless sudo ---
RUN groupadd -f docker \
    && useradd -m -s /bin/bash -G sudo,docker claude \
    && echo "claude ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claude \
    && chmod 0440 /etc/sudoers.d/claude

# --- Layer 5: Claude CLI (native installer, must run as target user) ---
USER claude
WORKDIR /tmp
RUN curl -fsSL https://claude.ai/install.sh | bash

# --- Layer 6: Aliases, environment, entrypoint ---
USER root
RUN printf '#!/bin/bash\nexec claude --dangerously-skip-permissions "$@"\n' > /usr/local/bin/yolo-claude \
    && chmod +x /usr/local/bin/yolo-claude

USER claude
WORKDIR /workspace

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PATH="/home/claude/.local/bin:${PATH}" \
    DISABLE_AUTOUPDATER=1

COPY --chown=claude:claude entrypoint.sh /home/claude/entrypoint.sh
RUN chmod +x /home/claude/entrypoint.sh

ENTRYPOINT ["/home/claude/entrypoint.sh"]
CMD ["bash"]
