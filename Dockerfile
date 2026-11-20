# Image Open Terminal complete, mise a jour automatiquement par GitHub Actions.
FROM ghcr.io/open-webui/open-terminal:latest

LABEL org.opencontainers.image.source="https://github.com/Gransam/open-terminal-code" \
      org.opencontainers.image.description="Open Terminal full + common development tools for Open WebUI"

USER root

# Recherche rapide dans le code et les fichiers.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ripgrep fd-find shellcheck shfmt git-lfs postgresql-client redis-tools \
      tesseract-ocr tesseract-ocr-eng tesseract-ocr-fra libimage-exiftool-perl \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# Tests et automatisation Python.
RUN python -m pip install --no-cache-dir pytest httpx playwright ruff yamllint pytest-cov pytest-asyncio

# Navigateurs Playwright preinstalles dans une couche commune de l'image.
# Les telechargements implicites pendant npm install restent desactives.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers \
    PLAYWRIGHT_SKIP_BROWSER_GC=1
# Eviter un prefixe npm force et exposer le vrai diagnostic en cas d'echec.
RUN set -eux; \
    node --version; \
    npm --version; \
    npm install -g --no-audit --no-fund --fetch-retries=3 \
      typescript tsx playwright eslint prettier html-validate \
    || { \
      echo "==== npm install failed: debug logs ===="; \
      find /root/.npm/_logs -type f -name '*debug-0.log' -exec tail -n 90 {} \; || true; \
      exit 1; \
    }; \
    npm cache clean --force; \
    tsc --version; \
    playwright --version

# Installer les revisions officielles Chromium attendues par Playwright Python et Node.
# Inclut le navigateur complet et le headless shell pour launch() sans executablePath.
# Le cache appartient a l'image et reste lisible par l'utilisateur non-root.
RUN set -eux; \
    mkdir -p "$PLAYWRIGHT_BROWSERS_PATH"; \
    python -m playwright --version; \
    playwright --version; \
    env -u PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD python -m playwright install chromium; \
    env -u PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD playwright install chromium; \
    chmod -R a+rX "$PLAYWRIGHT_BROWSERS_PATH"


# Mike Farah yq (Go CLI, not Debian/Python yq).
ARG YQ_VERSION=v4.54.3
RUN set -eux; \
    curl -fL --retry 3 --retry-delay 2 \
      "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
      -o /usr/local/bin/yq; \
    chmod +x /usr/local/bin/yq; \
    yq --version

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

# Capture standardisee avec Chromium systeme, puis test Playwright avec ses navigateurs preinstalles.
COPY scripts/capture-web /usr/local/bin/capture-web
COPY scripts/check-web /usr/local/bin/check-web
COPY scripts/smoke-browser /usr/local/bin/smoke-browser
RUN chmod +x /usr/local/bin/capture-web /usr/local/bin/check-web /usr/local/bin/smoke-browser \
    && python -m py_compile /usr/local/bin/capture-web /usr/local/bin/check-web /usr/local/bin/smoke-browser \
    && test -x /usr/bin/chromium \
    && runuser -u user -- /usr/local/bin/smoke-browser

# Contexte minimal pour tous les modeles IA ; les logiciels restent decouvrables a la demande.
# Garder le prompt systeme dynamique officiel (ne pas definir OPEN_TERMINAL_SYSTEM_PROMPT).
ENV OPEN_TERMINAL_INFO="You have a capable, persistent Linux development environment. Discover available tools and libraries as needed; verify before claiming anything is missing. Choose freely between integrated Browser tools (when available), Playwright, shell commands, and other methods based on the task. Playwright supports deeper scripted browser automation; neither option is mandatory. Verify results, adapt to failures, and preserve existing work. For image analysis, read actual pixels with read_file; display_file only opens the user viewer."
ENV OPEN_TERMINAL_EXECUTE_DESCRIPTION="Explore the environment and inspect command results. For Open Terminal Browser > Ports live previews, run development servers as managed foreground processes and track them with get_process_status."

# Reprendre l'utilisateur non-root et le repertoire de travail de l'image officielle.
USER user
WORKDIR /home/user
