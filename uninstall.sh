#!/bin/zsh
# shhist uninstaller -- removes the install directory (code + config) and
# the .zshrc hook. History data is NOT touched by default -- it lives in
# $SHHIST_DATA_DIR, outside the install directory. Pass --purge-data to
# delete it too.
#
#   ~/.config/shhist/uninstall.sh               # asks for confirmation
#   ~/.config/shhist/uninstall.sh -f            # skip confirmation
#   ~/.config/shhist/uninstall.sh -f --purge-data   # also delete history.db

set -e

INSTALL_DIR="${SHHIST_DIR:-$HOME/.config/shhist}"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
SOURCE_LINE="source $INSTALL_DIR/widgets.zsh"
COMMENT_LINE="# shhist -- load AFTER fzf keybindings and zsh-autosuggestions"

ok()   { print -P "%F{green}✓%f $1" }
warn() { print -P "%F{yellow}!%f $1" }
die()  { print -P "%F{red}✗%f $1" >&2; exit 1 }

FORCE=0
PURGE_DATA=0
for arg in "$@"; do
  case "$arg" in
    -f) FORCE=1 ;;
    --purge-data) PURGE_DATA=1 ;;
  esac
done

# Pick up the real DB/data-dir paths from the installed config, if present,
# so this still works after users customize SHHIST_DATA_DIR/SHHIST_DB.
# Config files only export vars, so sourcing is safe even if shhist was
# never fully loaded (no fzf/zsh-autosuggestions dependency at this point).
if [[ -f "$INSTALL_DIR/config.zsh" ]]; then
  SHHIST_HOME="$INSTALL_DIR"
  source "$INSTALL_DIR/config.zsh" 2>/dev/null || true
  [[ -f "$INSTALL_DIR/config.local.zsh" ]] && source "$INSTALL_DIR/config.local.zsh" 2>/dev/null || true
fi
DATA_DIR="${SHHIST_DATA_DIR:-$HOME/.config/shhist-data}"
DB_PATH="${SHHIST_DB:-$DATA_DIR/history.db}"

# Legacy installs may still have the DB inside INSTALL_DIR (pre data-dir
# split). Detect that so the confirmation prompt is honest either way.
DB_INSIDE_INSTALL_DIR=0
[[ "${DB_PATH:A}" == "${INSTALL_DIR:A}"/* ]] && DB_INSIDE_INSTALL_DIR=1

# --- 1. Confirm ---------------------------------------------------------
if [[ -d "$INSTALL_DIR" ]]; then
  if (( ! FORCE )); then
    print -P "%F{yellow}This will permanently delete:%f"
    print "  $INSTALL_DIR  (code, config.zsh, config.local.zsh)"
    if (( DB_INSIDE_INSTALL_DIR )); then
      print "  including your history database ($DB_PATH)"
    elif (( PURGE_DATA )) && [[ -e "$DATA_DIR" ]]; then
      print "  $DATA_DIR  (--purge-data: your history database)"
    else
      print "  history database at $DB_PATH will be kept"
    fi
    print -n "Continue? [y/N] "
    read -r reply
    [[ "$reply" == [yY]* ]] || die "aborted"
  fi
else
  warn "$INSTALL_DIR not found -- nothing to remove there"
fi

# --- 2. Remove the .zshrc hook -------------------------------------------
if [[ -f "$ZSHRC" ]] && grep -qF "$SOURCE_LINE" "$ZSHRC"; then
  # Drop the source line and the comment line install.sh added above it;
  # a leftover blank line is harmless and left in place.
  tmp="${ZSHRC}.shhist-uninstall.tmp"
  grep -vF "$SOURCE_LINE" "$ZSHRC" | grep -vF "$COMMENT_LINE" > "$tmp"
  mv "$tmp" "$ZSHRC"
  ok "removed source line from $ZSHRC"
else
  warn "$ZSHRC does not source shhist -- nothing to remove there"
fi

# --- 3. Remove the install directory (code + config) ---------------------
if [[ -d "$INSTALL_DIR" ]]; then
  rm -rf -- "$INSTALL_DIR"
  ok "removed $INSTALL_DIR"
fi

# --- 4. Data dir: kept unless --purge-data was given ----------------------
if [[ -e "$DATA_DIR" ]] || [[ -e "$DB_PATH" ]]; then
  if (( PURGE_DATA )); then
    rm -rf -- "$DATA_DIR"
    ok "removed $DATA_DIR (--purge-data)"
  else
    ok "kept history database: $DB_PATH"
  fi
fi

# --- 5. Next steps ----------------------------------------------------------
print ""
print "Done. Open a new terminal so the removed widgets/hooks stop being active."
if (( ! PURGE_DATA )) && [[ -e "$DB_PATH" ]]; then
  print "Your history is still at $DB_PATH -- re-running install.sh will pick it right back up."
  print "Delete it manually, or re-run with --purge-data, if you don't want it."
fi
