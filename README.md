# Open Terminal Code

Image Docker personnalisee pour le terminal **Code** d'Open WebUI, construite automatiquement sur GitHub.

**Image a utiliser :** `ghcr.io/gransam/open-terminal-code:latest`

## Contenu

La base est l'image complete officielle `ghcr.io/open-webui/open-terminal:latest` : Python, Node.js, Chromium, outils de compilation, Git, LibreOffice, FFmpeg, etc.

Outils ajoutes et partages entre toutes les instances :

| Famille | Paquets |
| --- | --- |
| Linux / DevOps | `ripgrep` (`rg`), `fd-find` (alias `fd`), `shellcheck`, `shfmt`, `git-lfs`, `yq` (Mike Farah v4), `jq` |
| Python | `pytest`, `pytest-cov`, `pytest-asyncio`, `httpx`, `playwright`, `ruff`, `yamllint` |
| Node.js | `typescript`, `tsx`, `playwright`, `eslint`, `prettier`, `html-validate` |
| Bases de donnees | `psql` (client PostgreSQL), `redis-cli` (client Redis) |
| Documents et images | `tesseract` (OCR anglais/francais), `exiftool` |
| PowerShell | `pwsh` (PowerShell 7), `Pester`, `PSScriptAnalyzer` |

Deux usages coexistent : le Chromium systeme `/usr/bin/chromium` reste disponible (notamment pour Browser), et les navigateurs Chromium officiels attendus par **Playwright Python et Node.js** sont telecharges **une fois pendant la construction de l'image** dans `/opt/playwright-browsers` (`PLAYWRIGHT_BROWSERS_PATH`). Cela inclut Chromium et son headless shell. Les conteneurs reutilisent les couches de l'image Docker : `chromium.launch(headless=True)` fonctionne normalement **sans `executable_path` ni installation supplementaire**. Si un projet installe une autre version de Playwright exigeant une revision differente, celle-ci peut toutefois necessiter une installation adaptee.

Pour tester PowerShell : `pwsh -NoProfile -Command '$PSVersionTable.PSVersion'`, `Invoke-Pester ./tests`, `Invoke-ScriptAnalyzer ./script.ps1`. PowerShell s'execute sous **Linux** : les modules propres a Windows, le Registre et les cmdlets Windows ne sont pas disponibles ici.

## Chromium et instructions automatiques pour les modeles IA

L'image configure deux descriptions **courtes** (`OPEN_TERMINAL_INFO` et `OPEN_TERMINAL_EXECUTE_DESCRIPTION`) : elles encouragent la decouverte des commandes et bibliotheques a la demande plutot que de figer un inventaire d'outils dans le prompt. Le modele choisit librement sa methode.

La commande `capture-web` pilote le Chromium Debian deja installe, sans telecharger un autre navigateur :

```bash
capture-web https://www.google.fr screenshots/google.png --width 1280 --height 800
```

Pour creer un screenshot avec Playwright Python ou Node.js, laisser Playwright choisir son navigateur preinstalle : aucune option `executable_path` ou `executablePath` n'est requise. Browser et Playwright restent tous deux disponibles, sans hierarchie imposee.

Une capture sauvegardee sur disque est distincte d'une image transmise en entree visuelle au modele. Le modele doit recevoir les pixels dans la reponse d'un outil compatible vision pour faire une vraie analyse visuelle.


### Live Preview et tests web automatiques

Pour rendre les ports visibles sous **Browser > Ports** dans Open WebUI, l'agent doit lancer un serveur web par `run_command` **au premier plan**, sans `&`, `nohup`, `setsid` ni `disown`. Open Terminal suit le processus de la commande. L'agent peut utiliser `get_process_status` pour l'interroger et `kill_process` pour l'arreter. Un serveur detache avec `PPID=1` peut rester accessible sur localhost mais ne plus apparaitre dans la liste des ports.

L'outil additionnel `check-web` teste une page reelle avec le Chromium systeme, sans telecharger de navigateur supplementaire :

```bash
check-web http://127.0.0.1:8080 --output-dir screenshots/audit
# Tests optionnels d'interactions reelles :
check-web http://127.0.0.1:8080 --hover "tbody tr:first-child" --click-mobile ".menu-toggle"
```

Il genere `desktop.png`, `tablet.png`, `mobile.png` et `report.json`. Il teste notamment les codes HTTP, les exceptions JavaScript et le debordement horizontal (`scrollWidth > clientWidth`). Il peut capturer un etat apres survol ou clic. Exit code non nul si un probleme detecte est bloquant ; les erreurs console restent signalees dans le rapport pour permettre l'analyse (elles ne sont pas toutes fatales). Les tests sont une **aide**, pas une garantie de qualite visuelle ou fonctionnelle ; l'agent reste libre d'ecrire des tests Playwright complets adaptes au projet.

**Vision :** pour analyser les captures en pixels, employer `read_file`. `display_file` sert uniquement a les montrer a l'utilisateur.

**Philosophie :** aucun ordre de preference entre les outils Browser integres et Playwright. Browser permet d'interagir avec les onglets Open WebUI ; Playwright permet des automatisations et tests plus approfondis. Le modele explore les capacites installees et choisit librement. Le build execute `smoke-browser` **en tant que l'utilisateur non-root**, qui lance le Chromium Playwright preinstalle via Python et Node.js **sans chemin explicite et sans acces reseau**.

## Mises a jour automatiques

Le workflow [Build Open Terminal Code](.github/workflows/build.yml) :

- se declenche automatiquement a chaque modification du Dockerfile, des scripts `scripts/**` ou du workflow sur `main` ;
- se declenche chaque **dimanche a 04:00 UTC** pour prendre la derniere image officielle et reconstruire les outils ;
- peut etre lance manuellement dans **Actions > Build Open Terminal Code > Run workflow** ;
- publie le resultat dans GitHub Container Registry (GHCR) sous le tag `:latest` ;
- construit seulement `linux/amd64`, la plateforme du serveur Coolify actuel.

La construction tourne sur un runner GitHub : **aucune compilation sur le disque du LXC Coolify**.

Le premier build peut prendre du temps ; l'image de base pese plusieurs gigaoctets. Une etape libere de l'espace disque du runner GitHub. Si GitHub signale tout de meme un manque d'espace, il faudra ajuster le runner.

## Premiere mise en route

1. Dans **GitHub > Actions**, verifier que **Build Open Terminal Code** passe au vert. Si les Actions sont desactivees, les activer pour ce depot.
2. Dans le profil GitHub **Gransam > Packages**, ouvrir le package `open-terminal-code`. S'il est prive, aller dans ses **Package settings > Change visibility > Public** pour permettre au Docker de Coolify de le telecharger sans authentification.
3. Dans **Open WebUI**, modifier le terminal modele **Code** : **Image** = `ghcr.io/gransam/open-terminal-code:latest` ; conserver **Separate instances = Chat**.
4. Retirer, si elles avaient ete ajoutees dans le modele Code, les variables `OPEN_TERMINAL_PACKAGES`, `OPEN_TERMINAL_PIP_PACKAGES` et `OPEN_TERMINAL_NPM_PACKAGES` faisant doublon avec les paquets de cette image.
5. Tester sur une **nouvelle conversation**. Les instances existantes ne changent pas d'image automatiquement : les rafraichir via Open WebUI / l'orchestrateur si necessaire, en conservant le stockage persistant.

La configuration de Terminals Orchestrator peut laisser `TERMINALS_IMAGE_PULL_POLICY` non defini : dans ce cas, les images portant le tag `:latest` sont verifiees au demarrage. Le mode `Always` est egalement possible.

## Ajouter un outil

Modifier le `Dockerfile` (APT, Python ou npm), puis enregistrer les changements sur la branche `main`. GitHub Actions reconstruit et publie automatiquement la nouvelle image.

**Attention :** une nouvelle image ne change pas les conteneurs deja en cours d'execution. Une reconstruction peut aussi faire coexister momentanement plusieurs versions de l'image sur le serveur Docker.

Documentation officielle : [Open Terminal](https://github.com/open-webui/open-terminal) · [Images personnalisees pour Terminals](https://docs.openwebui.com/features/open-terminal/terminals/orchestration/custom-images/).
