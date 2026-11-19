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

# Tests et automatisation Python. On reutilise Chromium deja present dans l'image.
RUN python -m pip install --no-cache-dir pytest httpx playwright ruff yamllint pytest-cov pytest-asyncio

# CLI web / TypeScript. Aucun telechargement de navigateur pendant npm install.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
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

# Capture standardisee avec Chromium systeme (aucun navigateur supplementaire).
COPY scripts/capture-web /usr/local/bin/capture-web
COPY scripts/check-web /usr/local/bin/check-web
RUN chmod +x /usr/local/bin/capture-web /usr/local/bin/check-web \
    && python -m py_compile /usr/local/bin/capture-web /usr/local/bin/check-web \
    && test -x /usr/bin/chromium

# Informations rendues visibles a Qwen via l'API /system d'Open Terminal.
# Ne pas redefinir OPEN_TERMINAL_SYSTEM_PROMPT : garder la description dynamique.
# Inform rather than constrain: the model is free to use any appropriate tools,
# custom code, frameworks, and workflows for the task at hand.
ENV OPEN_TERMINAL_INFO="You are working in a capable, persistent Linux Code environment. Be creative and choose the best tools, libraries and architecture for the user's goal; the following are capabilities and practical tips, NOT mandatory steps or limits. Already installed: Python, pytest, pytest-cov, pytest-asyncio, httpx, ruff, yamllint, pandas and document tools; Node.js, TypeScript (tsc), tsx, eslint, prettier, html-validate; shellcheck, shfmt, ripgrep (rg), fd, Git and git-lfs; Mike Farah yq v4, jq, Docker CLI, psql, redis-cli; PowerShell 7 (pwsh), Pester, PSScriptAnalyzer; Chromium, Python/Node Playwright, ffmpeg, pandoc, LibreOffice, Tesseract OCR (eng/fra), exiftool. Check command -v or --version before installing duplicates; install extra dependencies freely when the project genuinely needs them. Chromium already exists at /usr/bin/chromium: Playwright Python launch(executable_path='/usr/bin/chromium', headless=True), Node launch({executablePath:'/usr/bin/chromium',headless:true}); avoid downloading duplicate Playwright browsers unless needed. For one-off screenshots use capture-web URL screenshots/page.png; for a quick responsive audit use check-web URL --output-dir screenshots/audit (desktop, tablet, mobile PNG and report.json, with optional --hover or --click-mobile). More advanced behavior should use custom Playwright tests; check-web is just a convenience. For visual inspection, call Open Terminal read_file on the PNG to receive its pixels; display_file only opens the user viewer and never returns image pixels to the model. Never claim to have seen an image without receiving its image content. IMPORTANT FOR LIVE PREVIEW: start development web servers using run_command with the server in the foreground (no trailing &, nohup, setsid, disown, or daemonization); Open Terminal tracks the running command so Browser > Ports can detect it. Use get_process_status to check the process while keeping it alive, and kill_process when no longer needed. If a server is orphaned (PPID 1), restart it as a managed foreground process. Favor incremental changes and evidence-based checking (test output, HTTP, visual inspection when useful). If a command fails, inspect and retry intelligently rather than recreate work; avoid saying checks passed without running them. Preserve valuable workspace files and avoid destructive cleanup unless requested. These are pragmatic defaults, not creativity constraints."
ENV OPEN_TERMINAL_EXECUTE_DESCRIPTION="You have a full creative development environment. Existing tools: rg fd shfmt shellcheck yq jq git-lfs; pytest pytest-cov pytest-asyncio ruff yamllint; TypeScript/tsx/eslint/prettier/html-validate; psql redis-cli pwsh/Pester; OCR tesseract and exiftool. Web: use /usr/bin/chromium with Playwright, capture-web for screenshots, check-web URL for responsive/JS checks. read_file sends screenshot pixels to vision; display_file only shows the file to user. To make Browser > Ports detect web apps, use run_command with a foreground-running dev server (no & or nohup), keep it tracked and use get_process_status. Freely use other appropriate techniques when better."

# Reprendre l'utilisateur non-root et le repertoire de travail de l'image officielle.
USER user
WORKDIR /home/user
