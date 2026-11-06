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
export SHHIST_HALFLIFE_CMD=$((14 * 24 * 3600))   # suggestions:    14 days (long-term habit)

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
# Inline suggestions (replaces zsh-autosuggestions)
# ---------------------------------------------------------------------------
# Gray "ghost text" completing the line from the sqlite history, ranked by
# SHHIST_SUGGEST_RANK (below). Right arrow / End accepts it all,
# Alt+Right (forward-word) accepts the next word. A candidate whose program
# or file operands are missing right now is skipped.
# Remove zsh-autosuggestions from oh-my-zsh plugins=(...) to use this; while
# that plugin is still loaded, shhist only feeds it (SHHIST_SUGGEST_MODE
# below) and prints a reminder. 0 = no built-in suggestions, no reminder.
export SHHIST_SUGGEST=1
# zle highlight spec for the ghost text (e.g. 'fg=8', 'fg=#666666').
export SHHIST_SUGGEST_STYLE="${SHHIST_SUGGEST_STYLE:-fg=8}"
# Key that accepts the suggestion one word at a time (same as Alt+Right).
# Ctrl+F is normally forward-char, which does nothing at the end of the
# line -- exactly where a suggestion shows -- so anywhere else in the line
# it still moves one character. Right arrow keeps accepting everything.
# '' = leave the key alone.
export SHHIST_BIND_ACCEPT_WORD="${SHHIST_BIND_ACCEPT_WORD-^F}"
# Ranking algorithm for suggestions. Compare them on your own history with
# `shhist-rank -a <algo> PREFIX` before switching.
#   duallog  W*S(short) + log2(1 + S(long))   recent work counts fully, long
#            habit only logarithmically -> new commands can rise (default)
#   dual     W*S(short) + S(long)             both linear
#   single   S(long)                          one half-life (old behavior)
#   seg      runs * weight of newest run's age bucket (SHHIST_SUGGEST_SEGS)
#   recent   newest matching command (zsh-autosuggestions behavior)
# S(h) = sum over runs of 0.5 ^ (age / h); long h = SHHIST_HALFLIFE_CMD.
export SHHIST_SUGGEST_RANK="${SHHIST_SUGGEST_RANK:-duallog}"
# Short-term half-life (seconds) and its weight W, for duallog / dual.
export SHHIST_HALFLIFE_CMD_SHORT=$((6 * 3600))   # 6 hours
export SHHIST_SUGGEST_SHORT_WEIGHT=2
# Buckets for `seg`: "max_age_seconds:weight" in order, then a bare
# fallback weight. Default = zoxide-style 4 buckets (1h x4, 1d x2,
# 1w x0.5, older x0.25); drop one rule for 3 buckets.
typeset -ga SHHIST_SUGGEST_SEGS=(3600:4 86400:2 604800:0.5 0.25)
# Top-ranked candidates checked per lookup; the first sound one is shown.
export SHHIST_SUGGEST_CANDIDATES=20
# Widgets that accept the whole suggestion / up to the next word when the
# cursor is at the end of the line (otherwise they behave as usual).
typeset -ga SHHIST_SUGGEST_ACCEPT_WIDGETS=(forward-char end-of-line vi-forward-char vi-end-of-line)
typeset -ga SHHIST_SUGGEST_PARTIAL_WIDGETS=(forward-word emacs-forward-word vi-forward-word
  vi-forward-word-end vi-forward-blank-word vi-forward-blank-word-end)

# Legacy: source used when zsh-autosuggestions is still loaded.
#   A  = sqlite only
#   B  = zsh default history only (default)
#   AB = sqlite first, fall back to default history
export SHHIST_SUGGEST_MODE="${SHHIST_SUGGEST_MODE:-B}"

# ---------------------------------------------------------------------------
# Forget broken commands
# ---------------------------------------------------------------------------
# When a command fails (exit 1-127), drop it from history if the reason is
# visible: its program doesn't exist (`gti status` -> command not found), or
# a file/directory operand doesn't (`sh missing.sh`, `cd nope`, `cat ./x`).
# A missing program or absolute path removes every row of that command; a
# missing relative path only the rows recorded in that same directory.
# Older history: `shhist-clean -n` previews, `shhist-clean` removes.
export SHHIST_PRUNE_FAILED=1
# Interpreters: the first operand (with no option before it) is a script.
typeset -ga SHHIST_INTERP_CMDS=(sh bash zsh dash ksh fish source . python python2 python3
  node deno bun ruby perl php lua osascript swift)
# Every operand is a path.
typeset -ga SHHIST_PATH_CMDS=(cd pushd ls cat less more head tail bat vim vi nvim nano code rmdir)
# Operands are patterns, URLs, or targets that don't exist yet: never checked.
typeset -ga SHHIST_NOCHECK_CMDS=(git curl wget ssh scp rsync open echo printf print tee
  grep egrep fgrep rg ag sed awk find jq mkdir touch cp mv ln tar zip unzip ditto install mktemp)

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
# Follow `mv` / `git mv` run in this shell: once the command succeeds,
# frecency rows for the old path (and everything under it) move to the
# new path, keeping their scores; the cwd column of command history is
# rewritten too. For renames done elsewhere (Finder): `shhist-mv OLD NEW`.
export SHHIST_TRACK_MV=1
# Drop entries whose path no longer exists each time a picker opens
# (j / v / shf / Tab / Ctrl+G). Missing paths under an unmounted
# /Volumes/<disk> are kept. On demand: `shhist-prune [dir|file]`.
export SHHIST_PRUNE_ON_PICK=1
# Record exit codes of commands (adds one tiny sqlite call per prompt).
export SHHIST_TRACK_EXIT=1
# Max rows fed into fzf for Ctrl+R.
export SHHIST_FZF_LIMIT=20000
# Extra fzf flags used by all shhist pickers.
export SHHIST_FZF_OPTS="--height=60% --reverse --border"
