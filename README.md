# Open Terminal Code

Image Docker personnalisee pour le terminal **Code** d'Open WebUI, construite automatiquement sur GitHub.

**Image a utiliser :** `ghcr.io/gransam/open-terminal-code:latest`

## Contenu

La base est l'image complete officielle `ghcr.io/open-webui/open-terminal:latest` : Python, Node.js, Chromium, outils de compilation, Git, LibreOffice, FFmpeg, etc.

Outils ajoutes et partages entre toutes les instances :

| Famille | Paquets |
| --- | --- |
| Linux | `ripgrep` (`rg`), `fd-find` (alias `fd`) |
| Python | `pytest`, `httpx`, `playwright` |
| Node.js | `typescript`, `tsx`, `playwright` |

Chromium est **deja fourni par l'image officielle** : aucun second navigateur n'est telecharge lors du build. Pour Playwright, lancer Chromium avec `executablePath: '/usr/bin/chromium'` (Node.js) ou `executable_path='/usr/bin/chromium'` (Python). Dans cet environnement conteneurise, `--no-sandbox` peut etre necessaire.

## Mises a jour automatiques

Le workflow [Build Open Terminal Code](.github/workflows/build.yml) :

- se declenche automatiquement a chaque modification du Dockerfile ou du workflow sur `main` ;
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
