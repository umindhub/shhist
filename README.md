# shhist

Pure-zsh shell history and frecency engine, backed by SQLite. No compiled
code -- just `zsh` + `sqlite3` + `fzf`.

## Features

- **Permanent history** -- every command saved to SQLite forever, with
  directory, timestamp, and exit code
- **Frecency** -- `fasd`/`z`-style ranking with exponential time decay,
  computed lazily at query time (no maintenance jobs), half-life fully
  configurable per kind (dirs / files / suggestions)
- **`j`** -- jump to frecent directories (`j youmind`, `j proj x`)
- **`v` / `shf`** -- open the best-matching frecent file in `$EDITOR` / run
  it with `sh`
- **Tab** -- `j youmind<Tab>` opens an fzf picker, Enter jumps immediately
- **Ctrl+R** -- fzf over the full SQLite history; Enter inserts,
  `ctrl-]` inserts and runs immediately; `ctrl-t` toggles all-dirs /
  current-dir; multi-line commands round-trip intact
- **Ctrl+G** -- insert a frecent file path into any half-typed command;
  Enter inserts, `ctrl-]` inserts and executes in one stroke
- **Delete entries** -- inside any picker (`j`/`v`/`shf`/Tab/Ctrl+G/Ctrl+R),
  `ctrl-x` removes the highlighted directory, file, or command and keeps
  the picker open
- **zsh-autosuggestions source** -- suggestions ranked by decayed frequency
  from SQLite; modes `A` (sqlite) / `B` (history, default) / `AB` (fallback)
- **History import** -- one-shot `shhist-import` of your existing zsh
  history, timestamps preserved

## Requirements

- zsh, [fzf](https://github.com/junegunn/fzf) >= 0.45,
  sqlite3 built with math functions (Homebrew's is)
- optional: [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
  for the suggestion source

```sh
brew install sqlite fzf zsh-autosuggestions
```

## Install

Clone straight into the install location, then run the installer (it
checks dependencies and adds one line to your `~/.zshrc`):

```sh
git clone https://github.com/umindhub/shhist.git ~/.config/shhist
~/.config/shhist/install.sh
```

shhist must load after fzf keybindings and zsh-autosuggestions; the
installer appends to the end of `.zshrc`, which normally satisfies that.
Updating is just:

```sh
git -C ~/.config/shhist pull
```

The database (`history.db`) and your local overrides
(`config.local.zsh`) are gitignored, so `git pull` never touches them.

If you prefer keeping the clone elsewhere, run `./install.sh` from it and
the files are copied to `~/.config/shhist` instead (re-run after each
pull; an existing `config.zsh` is never overwritten).

Then open a new terminal and optionally import your existing history once:

```sh
shhist-import
```

## Usage

| Action | What it does |
|---|---|
| `j foo`, `j foo bar` | cd to the best dir matching `*foo*bar*`; falls into fzf when ambiguous |
| `j` | fzf over all known dirs, frecency-ordered |
| `v foo` | open the best-matching file in `$EDITOR` |
| `shf foo` | run the best-matching file with `sh` |
| `j foo<Tab>` | fzf picker pre-filtered with `foo`; Enter jumps immediately (also works for `v`/`shf`) |
| `Ctrl+R` | fzf over SQLite history; Enter = insert, `ctrl-]` = insert + run, `ctrl-x` = delete; `ctrl-t` toggles all dirs / current dir |
| `Ctrl+G` | pick a frecent file into the current command line; Enter = insert, `ctrl-]` = insert + run, `ctrl-x` = delete |
| `ctrl-x` (inside any picker) | delete the highlighted dir/file/command; the picker stays open |
| `shhist-import` | one-shot import of existing zsh history |

To trigger the insert-and-run key with **Cmd+Enter**: terminals never
forward the Cmd key, so map it to send the byte `0x1D` -- in iTerm2:
Settings → Profiles → Keys → Key Mappings → `+` → Cmd+Enter →
"Send Hex Codes" → `0x1D`.

## Configuration

Defaults live in `config.zsh` (tracked). Put your overrides in
`~/.config/shhist/config.local.zsh` (gitignored, sourced after the
defaults) so `git pull` never conflicts -- just re-export whatever you
want to change:

```zsh
# ~/.config/shhist/config.local.zsh
export SHHIST_JUMP_CMD="z"
export SHHIST_ESC_TIMEOUT_MS=10
export SHHIST_HALFLIFE_DIR=$((14 * 24 * 3600))
```

Available settings: `SHHIST_DATA_DIR`/`SHHIST_DB` (where history lives),
command names, key bindings (including `SHHIST_FILE_RUN_KEY` and
`SHHIST_DELETE_KEY`), fzf options, autosuggestion mode (`A`/`B`/`AB`),
and the frecency half-lives:

```zsh
export SHHIST_HALFLIFE_DIR=$((7 * 24 * 3600))    # directory jump: 7 days
export SHHIST_HALFLIFE_FILE=$((3 * 24 * 3600))   # file ranking:   3 days
export SHHIST_HALFLIFE_CMD=$((14 * 24 * 3600))   # suggestions:    14 days
```

A visit N seconds ago is worth `0.5 ^ (N / half_life)` of a visit now.
Decay is computed at query time, so changing a half-life applies to all
existing data instantly.

The database is a single file, kept OUTSIDE the install directory on
purpose (default: `~/.config/shhist-data/history.db`, override with
`SHHIST_DATA_DIR` or `SHHIST_DB`) -- so removing/reinstalling shhist never
touches your history. Back it up, inspect it, or query it with plain
`sqlite3`.

## Uninstall

```sh
~/.config/shhist/uninstall.sh
```

Removes the install directory (`core.zsh`, `widgets.zsh`, `config.zsh`,
your `config.local.zsh`) and the source line in `~/.zshrc`. Your history
database is kept by default -- reinstalling later picks it right back up.
Pass `--purge-data` to delete it too, or `-f` to skip the confirmation
prompt:

```sh
~/.config/shhist/uninstall.sh -f --purge-data   # remove everything, no db kept
```
