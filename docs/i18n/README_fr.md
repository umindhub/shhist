# shhist

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | **Français** | [Italiano](README_it.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

Moteur d'historique shell et de frecency en zsh pur, adossé à SQLite. Aucun code
compilé : juste `zsh` + `sqlite3` + `fzf`.

shhist retient trois choses : **chaque commande** que vous lancez, **chaque
répertoire** dans lequel vous entrez et **chaque fichier** que vous touchez. C'est
ce dernier point qui fait la différence : dès qu'un fichier est apparu dans une
commande, vous pouvez l'ouvrir, l'exécuter ou insérer son chemin dans une
nouvelle commande **depuis n'importe quel répertoire**, sans retaper le chemin.

```sh
~/Downloads $ v zshrc          # ouvre ~/.zshrc dans $EDITOR
/tmp        $ shf deploy       # exécute ~/work/scripts/deploy.sh avec sh
~           $ j youmind        # cd ~/Dropbox/Xcode/YouMindHub
partout     $ vim <Ctrl+G>     # choisir un fichier fréquent, son chemin est inséré
```

## Points forts

- **Vos fichiers vous suivent partout** : tout fichier existant passé à
  n'importe quelle commande (`vim`, `cat`, `cp`, `python3`, `open`, ...) est
  enregistré avec son chemin absolu. Ensuite, `v foo` l'ouvre, `shf foo`
  l'exécute et `Ctrl+G` l'insère dans ce que vous tapez, où que vous soyez.
- **S'accorde avec vim et sh** : `v` lance `$EDITOR` (vim par défaut), `shf`
  lance `sh`, et `Ctrl+G` transmet des chemins à n'importe quel autre outil
  (`nvim -d`, `bash`, `zsh`, `source`, `tail -f`, ...).
- **Saut de répertoire** : `j proj x` va dans le meilleur répertoire
  correspondant à `*proj*x*`, à la manière de `fasd`/`z`.
- **Historique permanent** : chaque commande est conservée pour toujours dans
  SQLite, avec répertoire, horodatage et code de sortie ; `Ctrl+R` cherche dans
  tout l'historique ou seulement dans les commandes lancées dans le répertoire
  courant.
- **Frecency** : décroissance temporelle exponentielle calculée paresseusement à
  la requête (aucune tâche de maintenance), demi-vie réglable par type
  (répertoires / fichiers / suggestions).
- **Exécution en une touche** : dans `Ctrl+R` et `Ctrl+G`, Entrée insère et
  `ctrl-]` insère **et exécute** d'un seul geste (peut être associé à Cmd+Entrée).
- **Suppression sur place** : `ctrl-x` dans n'importe quel sélecteur supprime le
  répertoire, le fichier ou la commande en surbrillance, sans fermer le sélecteur.
- **Source pour zsh-autosuggestions** : suggestions classées par fréquence
  amortie depuis SQLite.
- **Import de l'historique** : `shhist-import` importe une seule fois votre
  historique zsh existant, horodatages conservés.

## Prérequis

- zsh, [fzf](https://github.com/junegunn/fzf) >= 0.45,
  sqlite3 compilé avec les fonctions mathématiques (celui de Homebrew l'est)
- optionnel : [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
  pour la source de suggestions

```sh
brew install sqlite fzf zsh-autosuggestions
```

## Installation

Clonez directement à l'emplacement d'installation, puis lancez l'installeur (il
vérifie les dépendances et ajoute une ligne à votre `~/.zshrc`) :

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist doit être chargé après les raccourcis de fzf et zsh-autosuggestions ;
l'installeur ajoute la ligne à la fin de `.zshrc`, ce qui suffit normalement.
Pour mettre à jour :

```sh
git -C ~/.config/shhist pull
```

La base de données se trouve hors du répertoire d'installation et vos réglages
locaux (`config.local.zsh`) sont dans le gitignore : `git pull` n'y touche
jamais.

Si vous préférez garder le clone ailleurs, lancez `./install.sh` depuis celui-ci
et les fichiers seront copiés dans `~/.config/shhist` (à relancer après chaque
pull ; un `config.zsh` existant n'est jamais écrasé).

Ouvrez ensuite un nouveau terminal et, si vous le souhaitez, importez une fois
votre historique :

```sh
shhist-import
```

## Utilisation

### Des fichiers depuis n'importe quel répertoire

| Action | Effet |
|---|---|
| `v` | fzf sur tous les fichiers connus, triés par frecency ; Entrée ouvre dans `$EDITOR` |
| `v foo`, `v foo bar` | ouvre dans `$EDITOR` le meilleur fichier correspondant à `*foo*bar*` ; sans résultat, bascule dans fzf |
| `shf` / `shf foo` | mêmes règles de sélection, mais exécute le fichier avec `sh` |
| `v foo<Tab>` / `shf foo<Tab>` | fzf pré-filtré avec `foo` ; une seule correspondance s'ouvre/s'exécute aussitôt, sinon avec Entrée |
| `Ctrl+G` | choisir un fichier fréquent et insérer son chemin (échappé) au curseur de **n'importe quelle** commande ; Entrée = insérer, `ctrl-]` = insérer + exécuter |

La recherche est une correspondance de sous-chaîne insensible à la casse sur le
**chemin complet** : `v xcode main` trouve donc
`~/Dropbox/Xcode/App/main.swift`. Les fichiers qui n'existent plus sont retirés
de la base dès qu'ils sont ignorés pendant la recherche.

### Répertoires

| Action | Effet |
|---|---|
| `j` | fzf sur tous les répertoires connus, triés par frecency |
| `j foo`, `j foo bar` | cd dans le meilleur répertoire correspondant à `*foo*bar*` ; sans résultat, bascule dans fzf |
| `j foo<Tab>` | fzf pré-filtré avec `foo` ; une seule correspondance saute aussitôt, sinon avec Entrée |

### Historique des commandes

| Action | Effet |
|---|---|
| `Ctrl+R` | fzf sur l'historique SQLite, prérempli avec ce que vous avez tapé ; Entrée = insérer, `ctrl-]` = insérer + exécuter |
| `ctrl-t` (dans `Ctrl+R`) | bascule entre tous les répertoires et les commandes lancées dans le **répertoire courant** |
| `shhist-import` | import unique de l'historique zsh existant (`-f` si la base n'est pas vide) |

Les doublons sont regroupés et triés par dernière utilisation. Les commandes
multilignes s'affichent sur une ligne (`⏎`) mais sont réinsérées telles quelles.

### Dans chaque sélecteur

| Touche | Effet |
|---|---|
| `Entrée` | sélectionner |
| `ctrl-x` | supprime de la base le répertoire / fichier / commande en surbrillance ; le sélecteur reste ouvert |

Dans `Ctrl+R`, `ctrl-x` supprime toutes les occurrences de cette commande.

## Recettes

### Avec vim

```sh
v vimrc                  # éditer ~/.vimrc depuis n'importe où (après un `vim ~/.vimrc`)
v                        # parcourir les fichiers récents, Entrée ouvre celui voulu
vim -d <Ctrl+G> <Ctrl+G> # comparer deux fichiers récents (tapez l'espace entre les deux)
vim -O <Ctrl+G> <Ctrl+G> # ouvrir deux fichiers récents côte à côte
v myapp main             # correspondance sur le chemin : le fichier main dans myapp
```

`v` lance `${EDITOR:-vim}`. Pour Neovim, mettez `export EDITOR=nvim` dans votre
`.zshrc` (`$EDITOR` est appelé comme une seule commande ; pour un éditeur qui
demande des options comme `code --wait`, pointez-le vers un petit script
enveloppe). Si `v` entre en conflit avec autre chose, renommez-le via
`SHHIST_EDIT_CMD`.

### Avec sh et des scripts

```sh
shf deploy               # exécuter ~/work/scripts/deploy.sh depuis n'importe où
shf                      # parcourir les fichiers récents, Entrée exécute la sélection
bash <Ctrl+G> --prod     # autre interpréteur, arguments supplémentaires
python3 <Ctrl+G>         # pareil pour Python, Node, Ruby, ...
source <Ctrl+G>          # charger un fichier d'env/alias dans le shell courant
sh <Ctrl+G>, ctrl-]      # choisir et exécuter d'un seul geste
```

`shf` exécute toujours le fichier avec `sh` (POSIX sh ; le shebang est ignoré)
dans votre répertoire **courant**, sans argument supplémentaire : chaque mot fait
partie de la recherche. Pour les scripts propres à bash/zsh, les arguments ou
d'autres interpréteurs, utilisez `Ctrl+G` après la commande de votre choix.

### Combinaisons du quotidien

```sh
cp <Ctrl+G> .            # copier un fichier récent dans le répertoire courant
tail -f <Ctrl+G>         # suivre un log consulté plus tôt
open <Ctrl+G>            # ouvrir avec l'app macOS par défaut
less <Ctrl+G>            # parcourir un fichier récent page par page
cd ~/project; <Ctrl+R> ctrl-t   # retrouver les commandes lancées dans ce dossier
```

`Ctrl+G` insère au curseur sans toucher au reste de la ligne : vous pouvez donc
l'utiliser plusieurs fois dans une même commande.

## Fonctionnement de l'enregistrement

- **Commandes** : chaque ligne de commande est enregistrée avec son répertoire,
  son horodatage et son code de sortie. Une commande qui commence par une
  **espace** est privée : ni la commande ni ses fichiers ne sont enregistrés.
- **Répertoires** : chaque changement de répertoire (`cd`, `pushd`, `j`,
  auto_cd) augmente le score de ce répertoire.
- **Fichiers** : pour chaque commande, jusqu'à 8 arguments qui ne sont ni des
  options (`-x`) ni des affectations (`a=b`) sont examinés ; ceux qui sont des
  fichiers ordinaires existants sont enregistrés par chemin absolu (guillemets
  retirés, `~` développé, liens symboliques résolus). Les globs non développés et
  les répertoires ne comptent pas comme fichiers.
- **Import** : `shhist-import` charge uniquement le texte des commandes et leurs
  horodatages ; il ne remplit pas les classements de répertoires/fichiers, et les
  commandes importées n'ont pas de répertoire, elles n'apparaissent donc que dans
  la vue « tous les répertoires » de `ctrl-t`.

Une visite d'il y a N secondes vaut `0.5 ^ (N / half_life)` d'une visite
actuelle. La décroissance étant calculée à la requête, modifier une demi-vie
s'applique instantanément à toutes les données existantes.

## Configuration

Les valeurs par défaut sont dans `config.zsh` (versionné). Placez vos réglages
dans `~/.config/shhist/config.local.zsh` (dans le gitignore, chargé après les
valeurs par défaut) pour que `git pull` n'entre jamais en conflit ; il suffit de
réexporter ce que vous voulez changer :

```zsh
# ~/.config/shhist/config.local.zsh
export SHHIST_JUMP_CMD="z"
export SHHIST_EDIT_CMD="e"
export SHHIST_ESC_TIMEOUT_MS=10
export SHHIST_HALFLIFE_DIR=$((14 * 24 * 3600))
```

| Réglage | Défaut | Signification |
|---|---|---|
| `SHHIST_DATA_DIR` / `SHHIST_DB` | `~/.config/shhist-data/history.db` | emplacement de l'historique |
| `SHHIST_SQLITE` | détection auto | binaire sqlite3 avec fonctions mathématiques |
| `SHHIST_JUMP_CMD` / `SHHIST_EDIT_CMD` / `SHHIST_SH_CMD` | `j` / `v` / `shf` | noms des commandes |
| `SHHIST_BIND_HISTORY` / `SHHIST_BIND_FILE` | `^R` / `^G` | raccourcis des widgets |
| `SHHIST_BIND_TAB` | `^I` | sélecteur Tab sur les lignes `j`/`v`/`shf` (`''` le désactive) |
| `SHHIST_FILE_RUN_KEY` | `ctrl-]` | touche insérer + exécuter dans `Ctrl+R` / `Ctrl+G` |
| `SHHIST_DELETE_KEY` | `ctrl-x` | touche de suppression dans tous les sélecteurs |
| `SHHIST_SUGGEST_MODE` | `B` | autosuggestions : `A` sqlite / `B` historique zsh / `AB` sqlite puis historique |
| `SHHIST_HALFLIFE_DIR` / `_FILE` / `_CMD` | 7 / 3 / 14 jours | demi-vies de frecency (secondes) |
| `SHHIST_TRACK_EXIT` | `1` | enregistrer les codes de sortie |
| `SHHIST_FZF_LIMIT` | `20000` | nombre max. de lignes pour `Ctrl+R` |
| `SHHIST_FZF_OPTS` | `--height=60% --reverse --border` | options fzf supplémentaires pour tous les sélecteurs |
| `SHHIST_ESC_FIX` / `SHHIST_ESC_TIMEOUT_MS` | `1` / `10` | rendre inoffensif un ESC isolé en mode emacs |

### Cmd+Entrée comme touche d'exécution

Les terminaux ne transmettent jamais la touche Cmd ; associez-la donc à l'envoi
de l'octet `0x1D` (`ctrl-]`) :

- **iTerm2** : Settings → Profiles → Keys → Key Mappings → `+` → Cmd+Enter →
  « Send Hex Codes » → `0x1D`
- **kitty** : `map cmd+enter send_text all \x1d`

## Données

La base est un unique fichier SQLite, volontairement placé EN DEHORS du
répertoire d'installation (par défaut : `~/.config/shhist-data/history.db`) :
supprimer ou réinstaller shhist ne touche donc jamais à votre historique.
Sauvegardez-la, inspectez-la ou interrogez-la directement avec `sqlite3` :

```sh
sqlite3 ~/.config/shhist-data/history.db \
  "SELECT cmd FROM commands WHERE exit_code != 0 ORDER BY ts DESC LIMIT 20;"
```

## Désinstallation

```sh
~/.config/shhist/uninstall.sh
```

Supprime le répertoire d'installation (`core.zsh`, `widgets.zsh`, `config.zsh`,
votre `config.local.zsh`) et la ligne source de `~/.zshrc`. La base de
l'historique est conservée par défaut : une réinstallation ultérieure la
retrouve telle quelle. Passez `--purge-data` pour la supprimer aussi, ou `-f`
pour sauter la confirmation :

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # tout supprimer, sans garder la DB
```
