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
for cand in /opt/homebrew/opt/sqlite/bin/sqlite3 /usr/local/opt/sqlite/bin/sqlite3 sqlite3; do
  [[ -x "$cand" ]] || cand="$(command -v "$cand" 2>/dev/null)" || continue
  [[ -x "$cand" ]] || continue
  if "$cand" :memory: 'SELECT pow(2,10);' >/dev/null 2>&1; then
    sqlite_bin="$cand"
    break
  fi
done
[[ -n "$sqlite_bin" ]] || die "no sqlite3 with math functions found -- brew install sqlite"
ok "sqlite3 with math functions: $sqlite_bin"

# --- 2. Install files -------------------------------------------------------
if [[ "${REPO_DIR:A}" == "${INSTALL_DIR:A}" ]]; then
  # Cloned directly into the install dir -- nothing to copy, git pull updates
  # in place. The db and config.local.zsh are gitignored.
  ok "repo is the install dir ($INSTALL_DIR) -- in-place install, updates via git pull"
else
  mkdir -p "$INSTALL_DIR"
  cp "$REPO_DIR/core.zsh" "$REPO_DIR/widgets.zsh" "$INSTALL_DIR/"
  ok "installed core.zsh, widgets.zsh -> $INSTALL_DIR"

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
    print "# shhist -- load AFTER fzf keybindings and zsh-autosuggestions"
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
if [[ "${REPO_DIR:A}" == "${INSTALL_DIR:A}" ]]; then
  print "To update later:  git -C $INSTALL_DIR pull"
else
  print "To update later:  git -C $REPO_DIR pull && $REPO_DIR/install.sh"
fi
