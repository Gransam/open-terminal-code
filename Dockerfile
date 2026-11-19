# Image Open Terminal complete, mise a jour automatiquement par GitHub Actions.
FROM ghcr.io/open-webui/open-terminal:latest

LABEL org.opencontainers.image.source="https://github.com/Gransam/open-terminal-code" \
      org.opencontainers.image.description="Open Terminal full + common development tools for Open WebUI"

USER root

# Recherche rapide dans le code et les fichiers.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ripgrep fd-find shellcheck \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# Tests et automatisation Python. On reutilise Chromium deja present dans l'image.
RUN python -m pip install --no-cache-dir pytest httpx playwright ruff

# CLI web / TypeScript. Pas de nouveau telechargement de navigateur.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
RUN npm install --global --prefix /usr/local typescript tsx playwright eslint prettier \
    && npm cache clean --force

# PowerShell 7 depuis le depot officiel Microsoft pour la version Debian de l'image.
# Cela evite de figer une version et suit les mises a jour lors du build hebdomadaire.
RUN set -eux; \
    . /etc/os-release; \
    curl -fsSLo /tmp/packages-microsoft-prod.deb \
      "https://packages.microsoft.com/config/debian/${VERSION_ID}/packages-microsoft-prod.deb"; \
    dpkg -i /tmp/packages-microsoft-prod.deb; \
    rm -f /tmp/packages-microsoft-prod.deb; \
    apt-get update; \
    apt-get install -y --no-install-recommends powershell; \
    rm -rf /var/lib/apt/lists/*; \
    pwsh -NoLogo -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()'

# Framework de tests PowerShell et analyse statique, disponibles pour chaque workspace.
RUN pwsh -NoLogo -NoProfile -NonInteractive -Command \
    '$ErrorActionPreference = "Stop"; Install-Module -Name Pester,PSScriptAnalyzer -Scope AllUsers -Force -SkipPublisherCheck -ErrorAction Stop; Import-Module Pester -ErrorAction Stop; Import-Module PSScriptAnalyzer -ErrorAction Stop; "PowerShell test modules ready"'

# Reprendre l'utilisateur non-root et le repertoire de travail de l'image officielle.
USER user
WORKDIR /home/user
