# shhist - configuration
# Edit freely, then restart your shell (or `source ~/.config/shhist/widgets.zsh`).

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
# Program folder. Defaults to the directory this script lives in.
export SHHIST_DIR="${SHHIST_DIR:-${SHHIST_HOME:-$HOME/.config/shhist}}"
# Data folder for the SQLite database. Deliberately OUTSIDE $SHHIST_DIR so
# `rm -rf $SHHIST_DIR` (a `git pull` gone wrong, uninstall.sh, etc.) can
# never take your history with it.
export SHHIST_DATA_DIR="${SHHIST_DATA_DIR:-$HOME/.config/shhist-data}"
# SQLite database file.
export SHHIST_DB="${SHHIST_DB:-$SHHIST_DATA_DIR/history.db}"

# sqlite3 binary. Must be built with math functions (pow).
# Leave empty to auto-detect (Homebrew sqlite first, then system sqlite3).
export SHHIST_SQLITE="${SHHIST_SQLITE:-}"

# ---------------------------------------------------------------------------
# Frecency decay (fully customizable, per kind)
# ---------------------------------------------------------------------------
# Exponential half-life in SECONDS. A visit N seconds ago is worth
# 0.5 ^ (N / half_life) of a visit right now. Smaller = faster decay,
# i.e. recent items dominate more.
export SHHIST_HALFLIFE_DIR=$((7 * 24 * 3600))    # directory jump: 7 days
export SHHIST_HALFLIFE_FILE=$((3 * 24 * 3600))   # file ranking:   3 days
export SHHIST_HALFLIFE_CMD=$((14 * 24 * 3600))   # suggestions:    14 days

# ---------------------------------------------------------------------------
# Command names (customizable)
# ---------------------------------------------------------------------------
export SHHIST_JUMP_CMD="${SHHIST_JUMP_CMD:-j}"    # frecent directory jump
export SHHIST_EDIT_CMD="${SHHIST_EDIT_CMD:-v}"    # open frecent file in $EDITOR
export SHHIST_SH_CMD="${SHHIST_SH_CMD:-shf}"      # run frecent file with sh

# ---------------------------------------------------------------------------
# Key bindings
# ---------------------------------------------------------------------------
export SHHIST_BIND_HISTORY='^R'   # fzf command history search
export SHHIST_BIND_FILE='^G'      # insert a frecent file path at cursor
# Tab on a line starting with the jump/edit command opens fzf and jumps
# on Enter; any other line falls through to your normal completion.
# Set to '' to disable this feature entirely.
export SHHIST_BIND_TAB='^I'
# Used by BOTH the file picker (SHHIST_BIND_FILE) and the Ctrl+R history
# search: Enter inserts (path or command), this key inserts AND executes
# in one stroke. Must be an fzf key name. ctrl-] (byte 0x1D) is unbound in
# fzf by default, so nothing is lost.
# The Cmd key never reaches fzf -- macOS terminals intercept it -- so to
# trigger this with Cmd+Enter, map it in your terminal to send 0x1D:
#   iTerm2: Settings -> Profiles -> Keys -> Key Mappings -> [+]
#           shortcut: press Cmd+Enter, action: "Send Hex Codes", value: 0x1D
#           (confirm the override if it warns about the fullscreen shortcut)
#   kitty:  map cmd+enter send_text all \x1d
export SHHIST_FILE_RUN_KEY="${SHHIST_FILE_RUN_KEY:-ctrl-]}"
# Used inside ALL fzf pickers (j / v / shf / Tab / Ctrl+G / Ctrl+R) to
# delete the highlighted entry -- a directory, a file, or a command --
# from its underlying table. The picker stays open and refreshes right
# away so you can keep browsing/deleting. Must be an fzf key name, and
# should be different from SHHIST_FILE_RUN_KEY above. ctrl-x is one of
# the few emacs-style keys fzf does NOT bind by default (unlike ctrl-d,
# which deletes the character under the cursor in the search box).
export SHHIST_DELETE_KEY="${SHHIST_DELETE_KEY:-ctrl-x}"

# ---------------------------------------------------------------------------
# Autosuggestions source (zsh-autosuggestions)
# ---------------------------------------------------------------------------
#   A  = sqlite only
#   B  = zsh default history only (default)
#   AB = sqlite first, fall back to default history
export SHHIST_SUGGEST_MODE="${SHHIST_SUGGEST_MODE:-B}"

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------
# Bind a no-op to lone ESC (emacs keymap only). Without this, zle treats
# ESC as the Meta prefix and waits FOREVER for the next key, silently
# eating it (press ESC at the prompt, then any key: it's swallowed).
# With the no-op bound, zle waits only $KEYTIMEOUT (~0.4s) -- a lone ESC
# becomes harmless while arrow keys and real Alt-combos (whose bytes
# arrive within milliseconds) keep working. Set to 0 to disable.
# Never applied in vi mode, where ESC is meaningful.
export SHHIST_ESC_FIX=1
# How long (ms) after a lone ESC a following key still counts as an
# Alt-combo. Applied as zsh's KEYTIMEOUT (global: it also governs other
# ambiguous multi-key bindings). Escape sequences from the terminal
# (arrows, Alt keys) arrive as a single burst within ~1ms, so even low
# values are safe locally. Set to '' to leave your own KEYTIMEOUT alone.
export SHHIST_ESC_TIMEOUT_MS=10
# Record exit codes of commands (adds one tiny sqlite call per prompt).
export SHHIST_TRACK_EXIT=1
# Max rows fed into fzf for Ctrl+R.
export SHHIST_FZF_LIMIT=20000
# Extra fzf flags used by all shhist pickers.
export SHHIST_FZF_OPTS="--height=60% --reverse --border"
