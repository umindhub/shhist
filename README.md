# shhist

**English** | [Deutsch](docs/i18n/README_de.md) | [Español](docs/i18n/README_es.md) | [Français](docs/i18n/README_fr.md) | [Italiano](docs/i18n/README_it.md) | [日本語](docs/i18n/README_ja.md) | [한국어](docs/i18n/README_ko.md) | [Nederlands](docs/i18n/README_nl.md) | [简体中文](docs/i18n/README_zh-Hans.md) | [繁體中文](docs/i18n/README_zh-Hant.md)

Pure-zsh shell history and frecency engine, backed by SQLite. No compiled
code -- just `zsh` + `sqlite3` + `fzf`.

shhist remembers three things: **every command** you run, **every directory**
you enter, and **every file** you touch. The last one is what makes it
different: once a file has appeared in any command, you can open it, run it,
or drop its path into a new command **from any directory**, without typing
the path again.

```sh
~/Downloads $ v zshrc          # opens ~/.zshrc in $EDITOR
/tmp        $ shf deploy       # runs ~/work/scripts/deploy.sh with sh
~           $ j youmind        # cd ~/Dropbox/Xcode/YouMindHub
anywhere    $ vim <Ctrl+G>     # pick any frecent file, its path is inserted
```

## Highlights

- **Files follow you everywhere** -- any existing file passed to any command
  (`vim`, `cat`, `cp`, `python3`, `open`, ...) is recorded by its absolute
  path. From then on, `v foo` opens it, `shf foo` runs it, and `Ctrl+G`
  inserts it into whatever you are typing -- no matter where you are.
- **Plays well with vim and sh** -- `v` launches `$EDITOR` (vim by default),
  `shf` launches `sh`, and `Ctrl+G` feeds paths to any other tool
  (`nvim -d`, `bash`, `zsh`, `source`, `tail -f`, ...).
- **Directory jump** -- `j proj x` jumps to the best directory matching
  `*proj*x*`, `fasd`/`z`-style.
- **Permanent history** -- every command saved to SQLite forever, with
  directory, timestamp, and exit code; `Ctrl+R` searches all of it, or just
  the commands run in the current directory.
- **Frecency** -- recent work and long-term habit are scored separately (two
  half-lives, habit counted logarithmically), so a new command or directory
  rises within minutes instead of sitting under years of history. Computed
  lazily at query time (no maintenance jobs); the algorithm is switchable
  per feature.
- **One-stroke execution** -- in `Ctrl+R` and `Ctrl+G`, Enter inserts, and
  `ctrl-]` inserts **and runs** in one stroke (can be mapped to Cmd+Enter).
- **Delete in place** -- `ctrl-x` inside any picker removes the highlighted
  directory, file, or command and keeps the picker open.
- **Built-in inline suggestions** -- gray ghost text from SQLite, ranked by
  frecency; replaces zsh-autosuggestions. Candidates whose program
  or file operands are missing right now are skipped.
- **Forgets broken commands** -- a command that fails because its program
  doesn't exist (`command not found`) or a file/directory operand is missing
  (`sh missing.sh`, `cd nope`) is removed from history right away.
- **History import** -- one-shot `shhist-import` of your existing zsh
  history, timestamps preserved.

## Requirements

- zsh, [fzf](https://github.com/junegunn/fzf) >= 0.45,
  sqlite3 built with math functions (Homebrew's is)
```sh
brew install sqlite fzf
```

shhist has its own inline suggestions, so remove `zsh-autosuggestions` from
oh-my-zsh `plugins=(...)`. While it is still loaded, shhist only feeds it
(`SHHIST_SUGGEST_MODE`) and prints a reminder at startup.

## Install

Clone straight into the install location, then run the installer (it
checks dependencies and adds one line to your `~/.zshrc`):

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist must load after fzf keybindings and other plugins; the
installer appends to the end of `.zshrc`, which normally satisfies that.
Updating is just:

```sh
git -C ~/.config/shhist pull
```

The database lives outside the install directory, and your local overrides
(`config.local.zsh`) are gitignored, so `git pull` never touches them.

If you prefer keeping the clone elsewhere, run `./install.sh` from it and
the files are copied to `~/.config/shhist` instead (re-run after each
pull; an existing `config.zsh` is never overwritten).

Then open a new terminal and optionally import your existing history once:

```sh
shhist-import
```

## Usage

### Files from any directory

| Action | What it does |
|---|---|
| `v` | fzf over all known files, frecency-ordered; Enter opens in `$EDITOR` |
| `v foo`, `v foo bar` | open the best file matching `*foo*bar*` in `$EDITOR`; falls into fzf when nothing matches |
| `shf` / `shf foo` | same picking rules, but run the file with `sh` |
| `v foo<Tab>` / `shf foo<Tab>` | fzf pre-filtered with `foo`; a single match opens/runs immediately, otherwise Enter does |
| `Ctrl+G` | pick a frecent file and insert its (quoted) path at the cursor of **any** command; Enter = insert, `ctrl-]` = insert + run |

Matching is a case-insensitive substring match on the **full path**, so
`v xcode main` finds `~/Dropbox/Xcode/App/main.swift`. Files that no longer
exist are pruned from the database the moment they are skipped.

### Directories

| Action | What it does |
|---|---|
| `j` | fzf over all known dirs, frecency-ordered |
| `j foo`, `j foo bar` | cd to the best dir matching `*foo*bar*`; falls into fzf when nothing matches |
| `j foo<Tab>` | fzf pre-filtered with `foo`; a single match jumps immediately, otherwise Enter does |

### Command history

| Action | What it does |
|---|---|
| `Ctrl+R` | fzf over the SQLite history, pre-filled with what you have typed; Enter = insert, `ctrl-]` = insert + run |
| `Ctrl+T` | open the history picker directly on commands run in the **current directory** |
| `ctrl-t` (inside the picker) | toggle between all directories and commands run in the **current directory** |
| `shhist-import` | one-shot import of existing zsh history (`-f` to import into a non-empty db) |

Duplicates are collapsed and ranked by frecency (see Ranking below). Multi-line commands are
shown on one line (`⏎`) but inserted back exactly as typed.

### Inside every picker

| Key | What it does |
|---|---|
| `Enter` | select |
| `ctrl-x` | delete the highlighted dir / file / command from the db; the picker stays open |

In `Ctrl+R`, `ctrl-x` deletes every occurrence of that command.

## Recipes

### With vim

```sh
v vimrc                  # edit ~/.vimrc from anywhere (after any `vim ~/.vimrc`)
v                        # browse recent files, Enter opens the one you want
vim -d <Ctrl+G> <Ctrl+G> # diff two recent files (type the space in between)
vim -O <Ctrl+G> <Ctrl+G> # open two recent files side by side
v myapp main            # full-path match: the main file inside myapp
```

`v` runs `${EDITOR:-vim}`. To use Neovim, set `export EDITOR=nvim` in your
`.zshrc` (`$EDITOR` is called as a single command, so for an editor that
needs flags such as `code --wait`, point it at a small wrapper script). If
`v` clashes with something else, rename it via `SHHIST_EDIT_CMD`.

### With sh and scripts

```sh
shf deploy               # run ~/work/scripts/deploy.sh from anywhere
shf                      # browse recent files, Enter runs the selection
bash <Ctrl+G> --prod     # other interpreter, extra arguments
python3 <Ctrl+G>         # same for Python, Node, Ruby, ...
source <Ctrl+G>          # load an env/alias file into the current shell
sh <Ctrl+G>, ctrl-]      # pick and execute in a single stroke
```

`shf` always runs the file with `sh` (POSIX sh; the shebang is ignored) in
your **current** directory, and takes no extra arguments -- every word is
part of the search. For bash/zsh-only scripts, arguments, or other
interpreters, use `Ctrl+G` after the command of your choice.

### Everyday combos

```sh
cp <Ctrl+G> .            # copy a recent file into the current directory
tail -f <Ctrl+G>         # follow a log you looked at earlier
open <Ctrl+G>            # open in the default macOS app
less <Ctrl+G>            # page through a recent file
cd ~/project; <Ctrl+R> ctrl-t   # recall commands you ran in this folder
```

`Ctrl+G` appends at the cursor and leaves the rest of the line intact, so
you can call it several times in one command.

## How tracking works

- **Commands** -- every command line is stored with its directory, timestamp
  and exit code. A command starting with a **space** is private: neither the
  command nor its files are recorded.
- **Directories** -- every directory change (`cd`, `pushd`, `j`, auto_cd)
  bumps that directory.
- **Files** -- for each command, up to 8 arguments that are not options
  (`-x`) or assignments (`a=b`) are checked; those that are existing regular
  files are stored by absolute path (quotes stripped, `~` expanded, symlinks
  resolved). Unexpanded globs and directories are not counted as files.
- **Import** -- `shhist-import` loads command text and timestamps only; it
  does not fill the directory/file rankings, and imported commands have no
  directory, so they show up in `ctrl-t`'s all-dirs view only.

### Ranking

Every run or visit is worth `0.5 ^ (age / half_life)` of one right now.
Each command, directory and file keeps two such sums: **S_short** (half-life
6 hours: what you're working on now) and **S_long** (half-life 7 / 3 / 14
days for dirs / files / commands: long-term habit). The default score is
`2 × S_short + log2(1 + S_long)`.

Recent work counts fully, habit only logarithmically: a command run 200
times last month scores about 7, one run 3 times in the past hour about 8.
Habits still beat one-off commands, but no longer bury new ones.

| Algorithm | Score |
|---|---|
| `duallog` (default) | `W × S_short + log2(1 + S_long)` |
| `dual` | `W × S_short + S_long` |
| `single` | `S_long` (previous behavior) |
| `seg` | runs × weight of the newest visit's age bucket (zoxide-style, `SHHIST_RANK_SEGS`) |
| `recent` | newest first (zsh-autosuggestions / classic `Ctrl+R`) |

`SHHIST_RANK` picks the algorithm everywhere; `SHHIST_SUGGEST_RANK`,
`SHHIST_HISTORY_RANK` (`Ctrl+R`), `SHHIST_JUMP_RANK` (`j`) and
`SHHIST_FILE_RANK` (`v`, `shf`, `Ctrl+G`) override it per feature. Compare
them on your own data before switching:

```sh
shhist-rank git                  # suggestion order for "git..."
shhist-rank -a single git        # same prefix, previous algorithm
shhist-rank                      # whole history, i.e. Ctrl+R order
shhist-rank -k dir -a seg proj   # what `j proj` would pick with seg
```

Decay is computed at query time, so changing a half-life or the algorithm
applies to all existing data instantly. Databases from older versions are
upgraded on first start; their short-term directory/file scores and visit
counts are estimated and become exact as you keep using shhist.

## Inline suggestions

As you type, the best matching past command appears as gray text after the
cursor. Right arrow / End accepts all of it, Ctrl+F or Alt+Right
(`forward-word`) accepts the next word; elsewhere in the line these keys
work as usual (Ctrl+F still moves one character).
History navigation (Up, `Ctrl+R`) shows no suggestion until you type again.
A candidate is skipped (not deleted) when its program can't be resolved or
a path operand is missing in the current directory -- it may work again
later, e.g. after activating a venv.

## Forgetting broken commands

When a command exits with 1-127, shhist checks why:

- **program not found** (`gti status`, a missing `./build.sh`) -- every row
  of that command is deleted;
- **missing absolute / `~` path** (`cat ~/gone.txt`) -- every row is deleted;
- **missing relative path** (`sh missing.sh`, `cd nope`) -- only the rows
  recorded in that directory are deleted.

Paths are recognized conservatively: the script of an interpreter (`sh`,
`python3`, `node`, ... -- `SHHIST_INTERP_CMDS`), every operand of a file
command (`cd`, `cat`, `vim`, ... -- `SHHIST_PATH_CMDS`), and words starting
with `/`, `~/`, `./`, `../`. Tools whose operands are patterns, URLs or
not-yet-created targets (`git`, `grep`, `mkdir`, `cp`, ... --
`SHHIST_NOCHECK_CMDS`) are never path-checked. Ctrl+C and other signals
(exit >= 128) never count as failures.

For history recorded earlier (or imported), run the same check in bulk:

```sh
shhist-clean -n    # preview
shhist-clean       # remove
```

## Configuration

Defaults live in `config.zsh` (tracked). Put your overrides in
`~/.config/shhist/config.local.zsh` (gitignored, sourced after the
defaults) so `git pull` never conflicts -- just re-export whatever you
want to change:

```zsh
# ~/.config/shhist/config.local.zsh
export SHHIST_JUMP_CMD="z"
export SHHIST_EDIT_CMD="e"
export SHHIST_ESC_TIMEOUT_MS=10
export SHHIST_HALFLIFE_DIR=$((14 * 24 * 3600))
```

| Setting | Default | Meaning |
|---|---|---|
| `SHHIST_DATA_DIR` / `SHHIST_DB` | `~/.config/shhist-data/history.db` | where history lives |
| `SHHIST_SQLITE` | auto-detect | sqlite3 binary with math functions |
| `SHHIST_JUMP_CMD` / `SHHIST_EDIT_CMD` / `SHHIST_SH_CMD` | `j` / `v` / `shf` | command names |
| `SHHIST_BIND_HISTORY` / `SHHIST_BIND_FILE` | `^R` / `^G` | widget key bindings |
| `SHHIST_BIND_HISTORY_CWD` | `^T` | history picker starting in the current dir (`''` disables) |
| `SHHIST_BIND_TAB` | `^I` | Tab picker on `j`/`v`/`shf` lines (`''` disables) |
| `SHHIST_FILE_RUN_KEY` | `ctrl-]` | insert + run key in `Ctrl+R` / `Ctrl+G` |
| `SHHIST_DELETE_KEY` | `ctrl-x` | delete key in all pickers |
| `SHHIST_SUGGEST` | `1` | built-in inline suggestions (`0` disables) |
| `SHHIST_SUGGEST_STYLE` | `fg=8` | highlight of the suggestion text |
| `SHHIST_BIND_ACCEPT_WORD` | `^F` | accept the next word of the suggestion (`''` disables) |
| `SHHIST_SUGGEST_CANDIDATES` | `20` | top candidates checked per lookup |
| `SHHIST_SUGGEST_ACCEPT_WIDGETS` / `_PARTIAL_WIDGETS` | `forward-char` ... / `forward-word` ... | widgets accepting all / one word |
| `SHHIST_SUGGEST_MODE` | `B` | only while zsh-autosuggestions is loaded: `A` sqlite / `B` zsh history / `AB` both |
| `SHHIST_PRUNE_FAILED` | `1` | forget failed commands with a missing program or path |
| `SHHIST_INTERP_CMDS` / `SHHIST_PATH_CMDS` / `SHHIST_NOCHECK_CMDS` | see `config.zsh` | how operands are path-checked |
| `SHHIST_RANK` | `duallog` | ranking algorithm (see Ranking) |
| `SHHIST_SUGGEST_RANK` / `_HISTORY_RANK` / `_JUMP_RANK` / `_FILE_RANK` | `''` | per-feature override (`''` = `SHHIST_RANK`) |
| `SHHIST_RANK_SHORT_WEIGHT` | `2` | W in `duallog` / `dual` |
| `SHHIST_RANK_SEGS` | `(3600:4 86400:2 604800:0.5 0.25)` | buckets for `seg` (`max_age:weight`, then the fallback weight) |
| `SHHIST_HALFLIFE_DIR` / `_FILE` / `_CMD` | 7 / 3 / 14 days | long-term half-lives (seconds) |
| `SHHIST_HALFLIFE_DIR_SHORT` / `_FILE_SHORT` / `_CMD_SHORT` | 6 hours | short-term half-lives (seconds) |
| `SHHIST_TRACK_EXIT` | `1` | record exit codes |
| `SHHIST_FZF_LIMIT` | `20000` | max rows fed to `Ctrl+R` |
| `SHHIST_FZF_OPTS` | `--height=60% --reverse --border` | extra fzf flags for all pickers |
| `SHHIST_ESC_FIX` / `SHHIST_ESC_TIMEOUT_MS` | `1` / `10` | make a lone ESC harmless in emacs mode |

### Cmd+Enter as the run key

Terminals never forward the Cmd key, so map it to send the byte `0x1D`
(`ctrl-]`):

- **iTerm2**: Settings → Profiles → Keys → Key Mappings → `+` → Cmd+Enter →
  "Send Hex Codes" → `0x1D`
- **kitty**: `map cmd+enter send_text all \x1d`

## Data

The database is a single SQLite file, kept OUTSIDE the install directory on
purpose (default: `~/.config/shhist-data/history.db`) -- so removing or
reinstalling shhist never touches your history. Back it up, inspect it, or
query it with plain `sqlite3`:

```sh
sqlite3 ~/.config/shhist-data/history.db \
  "SELECT cmd FROM commands WHERE exit_code != 0 ORDER BY ts DESC LIMIT 20;"
```

## Uninstall

```sh
~/.config/shhist/uninstall.sh
```

Removes the install directory (`core.zsh`, `widgets.zsh`, `suggest.zsh`, `config.zsh`,
your `config.local.zsh`) and the source line in `~/.zshrc`. Your history
database is kept by default -- reinstalling later picks it right back up.
Pass `--purge-data` to delete it too, or `-f` to skip the confirmation
prompt:

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # remove everything, no db kept
```
