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

# CLI web / TypeScript. Aucun telechargement de navigateur pendant npm install.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
# Eviter un prefixe npm force et exposer le vrai diagnostic en cas d'echec.
RUN set -eux; \
    node --version; \
    npm --version; \
    npm install -g --no-audit --no-fund --fetch-retries=3 \
      typescript tsx playwright eslint prettier \
    || { \
      echo "==== npm install failed: debug logs ===="; \
      find /root/.npm/_logs -type f -name '*debug-0.log' -exec tail -n 90 {} \; || true; \
      exit 1; \
    }; \
    npm cache clean --force; \
    tsc --version; \
    playwright --version

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
RUN chmod +x /usr/local/bin/capture-web \
    && python -m py_compile /usr/local/bin/capture-web \
    && test -x /usr/bin/chromium

# Informations rendues visibles a Qwen via l'API /system d'Open Terminal.
# Ne pas redefinir OPEN_TERMINAL_SYSTEM_PROMPT : garder la description dynamique.
ENV OPEN_TERMINAL_INFO="This is the Code development container. Chromium is already installed at /usr/bin/chromium; use that existing executable with Playwright (Python: chromium.launch(executable_path='/usr/bin/chromium', headless=True); Node: chromium.launch({executablePath:'/usr/bin/chromium',headless:true})). NEVER run playwright install, npx playwright install, or download another browser unless the user explicitly requests it. For screenshots, prefer: capture-web https://www.google.fr screenshots/google.png --width 1280 --height 800 ; then use Open Terminal file display tools to show the saved image. Installed tools include Python/pytest/httpx/ruff, Node.js/TypeScript/Playwright, Chromium, PowerShell 7 (pwsh), Pester and PSScriptAnalyzer, git, jq, ffmpeg, pandoc, LibreOffice. Check with command -v before suggesting an installation. Screenshots saved on disk are NOT automatically given to the vision model; only claim visual inspection if image content was actually returned to model."
ENV OPEN_TERMINAL_EXECUTE_DESCRIPTION="Use the installed system Chromium /usr/bin/chromium rather than downloading Playwright browsers. For a webpage screenshot use capture-web URL output.png. PowerShell 7 is available as pwsh."

# Reprendre l'utilisateur non-root et le repertoire de travail de l'image officielle.
USER user
WORKDIR /home/user
