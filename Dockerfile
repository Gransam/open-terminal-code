# Image Open Terminal complete, mise a jour automatiquement par GitHub Actions.
FROM ghcr.io/open-webui/open-terminal:latest

LABEL org.opencontainers.image.source="https://github.com/Gransam/open-terminal-code" \
      org.opencontainers.image.description="Open Terminal full + common development tools for Open WebUI"

USER root

# Recherche rapide dans le code et les fichiers.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ripgrep fd-find \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# Tests et automatisation Python. On reutilise Chromium deja present dans l'image.
RUN python -m pip install --no-cache-dir pytest httpx playwright

# CLI web / TypeScript. Pas de nouveau telechargement de navigateur.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
RUN npm install --global --prefix /usr/local typescript tsx playwright \
    && npm cache clean --force

# Reprendre l'utilisateur non-root et le repertoire de travail de l'image officielle.
USER user
WORKDIR /home/user
