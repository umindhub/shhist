#!/bin/zsh
# shhist installer -- idempotent, safe to re-run.
#
#   git clone https://github.com/umindhub/shhist.git ~/.config/shhist
#   ~/.config/shhist/install.sh

set -e

REPO_DIR="${0:A:h}"
INSTALL_DIR="${SHHIST_DIR:-$HOME/.config/shhist}"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
SOURCE_LINE="source $INSTALL_DIR/widgets.zsh"

ok()   { print -P "%F{green}✓%f $1" }
warn() { print -P "%F{yellow}!%f $1" }
die()  { print -P "%F{red}✗%f $1" >&2; exit 1 }

# --- 1. Dependency checks ---------------------------------------------------
command -v fzf >/dev/null 2>&1 || die "fzf not found -- brew install fzf"
ok "fzf $(fzf --version | cut -d' ' -f1)"

# Need a sqlite3 built with math functions (pow) for the frecency queries.
# Same candidate order as core.zsh.
sqlite_bin=""
found_no_math=()   # binaries that exist but lack pow(), kept for the error message
sqlite_cands=()
[[ -n "$SHHIST_SQLITE" ]] && sqlite_cands+=("$SHHIST_SQLITE")   # user override first
sqlite_cands+=(/opt/homebrew/opt/sqlite/bin/sqlite3 /usr/local/opt/sqlite/bin/sqlite3 sqlite3)
for cand in "${sqlite_cands[@]}"; do
  [[ -x "$cand" ]] || cand="$(command -v "$cand" 2>/dev/null)" || continue
  [[ -x "$cand" ]] || continue
  if "$cand" :memory: 'SELECT pow(2,10);' >/dev/null 2>&1; then
    sqlite_bin="$cand"
    break
  fi
  found_no_math+=("$cand ($("$cand" --version 2>/dev/null | cut -d' ' -f1))")
done
if [[ -z "$sqlite_bin" ]]; then
  if (( ${#found_no_math} )); then
    # sqlite3 is installed, but built without SQLITE_ENABLE_MATH_FUNCTIONS
    # (or older than 3.35), so pow() is missing.
    warn "found sqlite3 but it has no math functions (pow): ${(j:, :)found_no_math}"
    warn "need sqlite >= 3.35 built with math functions."
    warn "build one from source:  $INSTALL_DIR/build-sqlite.sh"
    die  "or set SHHIST_SQLITE=/path/to/sqlite3 to use a different build"
  fi
  warn "sqlite3 not found in PATH."
  warn "build one from source:  $INSTALL_DIR/build-sqlite.sh"
  die  "or install it with your package manager (brew install sqlite)"
fi
ok "sqlite3 with math functions: $sqlite_bin"

# --- 2. Install files -------------------------------------------------------
if [[ "${REPO_DIR:A}" == "${INSTALL_DIR:A}" ]]; then
  # Cloned directly into the install dir -- nothing to copy, git pull updates
  # in place. The db and config.local.zsh are gitignored.
  ok "repo is the install dir ($INSTALL_DIR) -- in-place install, updates via git pull"
else
  mkdir -p "$INSTALL_DIR"
  cp "$REPO_DIR/core.zsh" "$REPO_DIR/widgets.zsh" "$REPO_DIR/suggest.zsh" "$REPO_DIR/match.sh" "$REPO_DIR/rows.sh" "$INSTALL_DIR/"
  ok "installed core.zsh, widgets.zsh, suggest.zsh, match.sh, rows.sh -> $INSTALL_DIR"
  # Optional helper that builds a sqlite3 with math functions from source.
  [[ -f "$REPO_DIR/build-sqlite.sh" ]] && cp "$REPO_DIR/build-sqlite.sh" "$INSTALL_DIR/"

  # config.zsh holds user edits: install once, never overwrite.
  if [[ -f "$INSTALL_DIR/config.zsh" ]]; then
    warn "config.zsh already exists -- kept yours (repo version: $REPO_DIR/config.zsh)"
  else
    cp "$REPO_DIR/config.zsh" "$INSTALL_DIR/"
    ok "installed config.zsh (edit it to customize)"
  fi
fi

# --- 3. Hook into .zshrc ----------------------------------------------------
if [[ -f "$ZSHRC" ]] && grep -qF "$SOURCE_LINE" "$ZSHRC"; then
  ok "$ZSHRC already sources shhist"
else
  {
    print ""
    print "# shhist -- load AFTER fzf keybindings and other plugins"
    print "$SOURCE_LINE"
  } >> "$ZSHRC"
  ok "added source line to $ZSHRC"
fi

# --- 4. Next steps ----------------------------------------------------------
print ""
print "Done. Next:"
print "  1. Open a new terminal (or: source $INSTALL_DIR/widgets.zsh)"
print "  2. Optionally import your existing zsh history once:  shhist-import"
print ""
if grep -qE '^[^#]*zsh-autosuggestions' "$ZSHRC" 2>/dev/null; then
  warn "zsh-autosuggestions is enabled in $ZSHRC -- remove it from plugins=(...) to use shhist's built-in suggestions"
  print ""
fi
if [[ "${REPO_DIR:A}" == "${INSTALL_DIR:A}" ]]; then
  print "To update later:  git -C $INSTALL_DIR pull"
else
  print "To update later:  git -C $REPO_DIR pull && $REPO_DIR/install.sh"
fi
