# shhist - core: sqlite data layer + shell hooks.
# Sourced by widgets.zsh. Do not source directly.

# ---------------------------------------------------------------------------
# sqlite3 resolution
# ---------------------------------------------------------------------------
# Find a sqlite3 binary compiled with math functions (pow), which the
# frecency queries require. Homebrew's sqlite has it; the macOS system
# binary may not.
_shhist_resolve_sqlite() {
  local cand
  local -a candidates
  [[ -n "$SHHIST_SQLITE" ]] && candidates+=("$SHHIST_SQLITE")
  candidates+=(
    /opt/homebrew/opt/sqlite/bin/sqlite3   # Apple Silicon Homebrew
    /usr/local/opt/sqlite/bin/sqlite3      # Intel Homebrew
    sqlite3                                # whatever is on PATH
  )
  for cand in "${candidates[@]}"; do
    [[ -x "$cand" ]] || cand="${commands[$cand]:-}"
    [[ -x "$cand" ]] || continue
    "$cand" :memory: 'SELECT pow(2,10);' >/dev/null 2>&1 || continue
    typeset -g SHHIST_SQLITE="$cand"
    export SHHIST_SQLITE
    return 0
  done
  print -u2 "shhist: no sqlite3 with math functions found (brew install sqlite)"
  return 1
}

# Run a SQL script against the database. WAL + busy_timeout make
# concurrent shells safe.
_shhist_sql() {
  "$SHHIST_SQLITE" -batch -noheader -cmd '.timeout 300' "$SHHIST_DB" "$1"
}

# Escape a string for use inside a SQL single-quoted literal.
_shhist_q() {
  print -r -- "${1//\'/''}"
}

# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------
_shhist_init_db() {
  [[ -f "$SHHIST_DB" ]] && return 0
  # Create the DB's own directory (SHHIST_DATA_DIR), not SHHIST_DIR --
  # they're intentionally separate so the install dir can be wiped
  # without touching stored history.
  mkdir -p "${SHHIST_DB:h}"
  _shhist_sql "
    PRAGMA journal_mode = WAL;
    CREATE TABLE IF NOT EXISTS commands(
      id        INTEGER PRIMARY KEY,
      cmd       TEXT NOT NULL,
      dir       TEXT,
      ts        INTEGER NOT NULL,
      exit_code INTEGER
    );
    CREATE INDEX IF NOT EXISTS idx_commands_cmd ON commands(cmd);
    CREATE INDEX IF NOT EXISTS idx_commands_ts  ON commands(ts);
    CREATE INDEX IF NOT EXISTS idx_commands_dir ON commands(dir);
    -- kind: 'dir' | 'file'. score decays lazily at read/write time,
    -- so no periodic maintenance job is ever needed.
    CREATE TABLE IF NOT EXISTS frecency(
      kind    TEXT NOT NULL,
      path    TEXT NOT NULL,
      score   REAL NOT NULL,
      last_ts INTEGER NOT NULL,
      PRIMARY KEY(kind, path)
    );
  " >/dev/null
}

# ---------------------------------------------------------------------------
# Frecency primitives
# ---------------------------------------------------------------------------
# SQL fragment: effective (decayed) score of a row right now.
#   eff = score * 0.5 ^ (age / half_life)
_shhist_eff_sql() {  # $1 = half-life in seconds
  print -r -- "score * pow(0.5, (strftime('%s','now') - last_ts) / CAST($1 AS REAL))"
}

# Record one visit: decay the stored score to "now", then add 1.
_shhist_bump() {  # $1 = kind, $2 = absolute path, $3 = half-life
  _shhist_sql "
    INSERT INTO frecency(kind, path, score, last_ts)
    VALUES ('$1', '$(_shhist_q "$2")', 1.0, strftime('%s','now'))
    ON CONFLICT(kind, path) DO UPDATE SET
      score   = $(_shhist_eff_sql "$3") + 1.0,
      last_ts = strftime('%s','now');
  "
}

# Build the SQL for _shhist_frecent WITHOUT running it. Split out so the
# fzf-based pickers can hand the exact same query string to fzf's
# `reload(...)` action -- letting them refresh the candidate list in
# place after a delete instead of closing and relaunching fzf (which is
# what caused the list to visibly jump by one line).
_shhist_frecent_sql() {  # $1 = kind, $2 = half-life, $3 = LIKE pattern or ''
  local where=""
  [[ -n "$3" ]] && where="AND path LIKE '$(_shhist_q "$3")'"
  print -r -- "SELECT path FROM frecency WHERE kind = '$1' $where ORDER BY $(_shhist_eff_sql "$2") DESC;"
}

# List paths of a kind, best-first. $3 is an optional LIKE pattern.
_shhist_frecent() {  # $1 = kind, $2 = half-life, $3 = LIKE pattern or ''
  _shhist_sql "$(_shhist_frecent_sql "$1" "$2" "$3")"
}

# ---------------------------------------------------------------------------
# Path maintenance: follow renames, prune stale rows
# ---------------------------------------------------------------------------
# Pending (old_a, old_A, new_a) triples captured in preexec, applied in
# precmd once the command has succeeded.
typeset -ga _SHHIST_MV_PLAN

# SQL: move every row at or under $1 to the same place under $2. Rows that
# already exist at the destination are merged (scores add up). Also
# rewrites the cwd column of command history so ctrl-t keeps working.
_shhist_rename_sql() {  # $1 = old abs path, $2 = new abs path
  local o="$(_shhist_q "$1")" n="$(_shhist_q "$2")"
  local pm="(path = '$o' OR substr(path, 1, length('$o') + 1) = '$o' || '/')"
  local dm="(dir = '$o' OR substr(dir, 1, length('$o') + 1) = '$o' || '/')"
  print -r -- "
    INSERT INTO frecency(kind, path, score, last_ts)
      SELECT kind, '$n' || substr(path, length('$o') + 1), score, last_ts
      FROM frecency WHERE $pm
    ON CONFLICT(kind, path) DO UPDATE SET
      score   = frecency.score + excluded.score,
      last_ts = max(frecency.last_ts, excluded.last_ts);
    DELETE FROM frecency WHERE $pm;
    UPDATE commands SET dir = '$n' || substr(dir, length('$o') + 1) WHERE $dm;
  "
}

# Recognize a simple `mv` / `git mv` line and record what will move where.
# Lists, pipes and subshells are ignored (the target can't be known
# reliably). Must run BEFORE the command, while sources still exist and
# we can still tell whether the destination is an existing directory.
_shhist_plan_mv() {  # $@ = (z)-split words of the command line
  _SHHIST_MV_PLAN=()
  local -a w=("$@")
  local t
  for t in "${w[@]}"; do
    [[ "$t" == ('&&'|'||'|';'|'|'|'&'|'|&'|'('|')'|'{'|'}'|$'\n') ]] && return 0
  done
  while [[ "${w[1]:-}" == (sudo|command|nocorrect|noglob) ]]; do shift w; done
  if [[ "${w[1]:-}" == git && "${w[2]:-}" == mv ]]; then
    shift 2 w
  elif [[ "${w[1]:-}" == mv ]]; then
    shift w
  else
    return 0
  fi

  # Collect operands; unquoted globs are expanded like the shell would.
  local -a ops ex
  local a p opts_done=0
  for a in "${w[@]}"; do
    if (( ! opts_done )); then
      [[ "$a" == -- ]] && { opts_done=1; continue }
      [[ "$a" == (-t|--target-directory*) ]] && return 0
      [[ "$a" == -* ]] && continue
    fi
    p="${(Q)a}"
    [[ "$p" == "~"* ]] && p="${HOME}${p#\~}"
    if [[ "$a" == "${(Q)a}" && "$p" == *[\*\?\[]* ]]; then
      ex=(${~p}(N))
      ops+=("${ex[@]}")
    else
      ops+=("$p")
    fi
  done
  (( ${#ops} >= 2 )) || return 0

  local dst="${ops[-1]}" src target
  [[ "$dst" != / ]] && dst="${dst%/}"
  local -a srcs=("${(@)ops[1,-2]}")
  local dst_dir=0
  [[ -d "$dst" ]] && dst_dir=1
  (( ${#srcs} > 1 && ! dst_dir )) && return 0

  for src in "${srcs[@]}"; do
    [[ "$src" != / ]] && src="${src%/}"
    [[ -n "$src" && "$src" != / ]] || continue
    [[ -e "$src" || -L "$src" ]] || continue
    # Case-only rename on a case-insensitive FS: dst "is" the source dir.
    if (( dst_dir )) && ! [[ "$src" -ef "$dst" ]]; then
      target="$dst/${src:t}"
    else
      target="$dst"
    fi
    _SHHIST_MV_PLAN+=("${src:a}" "${src:A}" "${target:a}")
  done
}

# Apply the plan if the command succeeded and each move really happened.
_shhist_apply_mv() {  # $1 = exit code of the last command
  if (( $1 != 0 || ${#_SHHIST_MV_PLAN} == 0 )); then
    _SHHIST_MV_PLAN=()
    return 0
  fi
  local i old_a old_A new_a new_A sql=""
  for (( i = 1; i + 2 <= ${#_SHHIST_MV_PLAN}; i += 3 )); do
    old_a="${_SHHIST_MV_PLAN[i]}"
    old_A="${_SHHIST_MV_PLAN[i+1]}"
    new_a="${_SHHIST_MV_PLAN[i+2]}"
    [[ -e "$new_a" || -L "$new_a" ]] || continue
    # Source still there and not the same file -> nothing moved (git mv -n, mv -n).
    [[ -e "$old_a" ]] && ! [[ "$old_a" -ef "$new_a" ]] && continue
    new_A="${new_a:A}"
    [[ "$old_a" != "$new_a" ]] && sql+="$(_shhist_rename_sql "$old_a" "$new_a")"
    [[ "$old_A" != "$old_a" && "$old_A" != "$new_A" ]] && sql+="$(_shhist_rename_sql "$old_A" "$new_A")"
  done
  _SHHIST_MV_PLAN=()
  [[ -n "$sql" ]] && _shhist_sql "BEGIN; $sql COMMIT;" >/dev/null
}

# Manual migration for renames done outside this shell (Finder, IDE, ...).
shhist-mv() {
  emulate -L zsh
  if (( $# != 2 )); then
    print -u2 "usage: shhist-mv OLD NEW"
    return 2
  fi
  local old="${1%/}" new="${2%/}"
  old="${old:a}" new="${new:a}"
  _shhist_sql "BEGIN; $(_shhist_rename_sql "$old" "$new") COMMIT;" >/dev/null \
    && print -r -- "shhist-mv: $old -> $new"
}

# A missing path under /Volumes/<disk> whose disk is not mounted right now
# is offline, not gone -- keep it.
_shhist_offline() {  # $1 = abs path
  [[ "$1" == /Volumes/?* ]] || return 1
  [[ ! -d "/Volumes/${${1#/Volumes/}%%/*}" ]]
}

# Delete frecency rows whose path no longer exists.
#   shhist-prune [-q] [dir|file]
shhist-prune() {
  emulate -L zsh
  local quiet=0
  [[ "$1" == -q ]] && { quiet=1; shift }
  local where=""
  [[ -n "${1:-}" ]] && where="WHERE kind = '$(_shhist_q "$1")'"

  local sep=$'\x1f' k p sql="" n=0
  while IFS="$sep" read -r k p; do
    if [[ "$k" == dir ]]; then
      [[ -d "$p" ]] && continue
    else
      [[ -f "$p" ]] && continue
    fi
    _shhist_offline "$p" && continue
    sql+="DELETE FROM frecency WHERE kind = '$(_shhist_q "$k")' AND path = '$(_shhist_q "$p")';"$'\n'
    (( n++ ))
  done < <("$SHHIST_SQLITE" -batch -noheader -cmd '.timeout 300' -separator "$sep" \
             "$SHHIST_DB" "SELECT kind, path FROM frecency $where;")

  # Feed via stdin: the script can exceed the argv size limit.
  if (( n )); then
    print -r -- "BEGIN; $sql COMMIT;" \
      | "$SHHIST_SQLITE" -batch -noheader -cmd '.timeout 300' "$SHHIST_DB" >/dev/null
  fi
  (( quiet )) || print "shhist-prune: removed $n stale entries"
}

# ---------------------------------------------------------------------------
# Shell hooks
# ---------------------------------------------------------------------------
# preexec: log the command line, and bump frecency for any existing file
# mentioned in its arguments (this is what makes `v`/Ctrl+F work with any
# command: vim, cat, cp, ...). Everything is batched into ONE sqlite call.
_shhist_preexec() {
  local cmdline="$1"
  # Respect the "leading space = private" convention; skip blank lines.
  [[ "$cmdline" == \ * || -z "${cmdline//[[:space:]]/}" ]] && return 0

  local sql="
    INSERT INTO commands(cmd, dir, ts)
    VALUES ('$(_shhist_q "$cmdline")', '$(_shhist_q "$PWD")', strftime('%s','now'));
    SELECT last_insert_rowid();
  "

  # File frecency: scan up to 8 non-option arguments for existing files.
  local -a words
  words=(${(z)cmdline})
  (( ${SHHIST_TRACK_MV:-1} )) && _shhist_plan_mv "${words[@]}"
  local w p n=0
  for w in "${words[@]:1}"; do
    (( n >= 8 )) && break
    [[ "$w" == -* || "$w" == *=* ]] && continue
    p="${(Q)w}"                                  # strip shell quoting
    [[ "$p" == "~"* ]] && p="${HOME}${p#\~}"     # expand leading tilde
    [[ -f "$p" ]] || continue
    p="${p:A}"                                   # absolute, symlinks resolved
    sql+="
      INSERT INTO frecency(kind, path, score, last_ts)
      VALUES ('file', '$(_shhist_q "$p")', 1.0, strftime('%s','now'))
      ON CONFLICT(kind, path) DO UPDATE SET
        score   = $(_shhist_eff_sql "$SHHIST_HALFLIFE_FILE") + 1.0,
        last_ts = strftime('%s','now');
    "
    (( n++ ))
  done

  typeset -g _SHHIST_LAST_ID="$(_shhist_sql "$sql")"
}

# precmd: attach the exit code to the command we just logged.
_shhist_precmd() {
  local code=$?
  _shhist_apply_mv $code
  (( SHHIST_TRACK_EXIT )) || { _SHHIST_LAST_ID=""; return 0 }
  [[ "$_SHHIST_LAST_ID" == <-> ]] || { _SHHIST_LAST_ID=""; return 0 }
  _shhist_sql "UPDATE commands SET exit_code = $code WHERE id = $_SHHIST_LAST_ID;"
  _SHHIST_LAST_ID=""
}

# chpwd: every directory change feeds the jump database.
_shhist_chpwd() {
  _shhist_bump dir "$PWD" "$SHHIST_HALFLIFE_DIR"
}

# ---------------------------------------------------------------------------
# One-time import of existing zsh history
# ---------------------------------------------------------------------------
# Command text comes from zsh's $history association, which is already
# un-metafied (multibyte text and embedded newlines are exact). Timestamps
# are read from $HISTFILE's extended-history headers (': <ts>:<dur>;') and
# paired with events in order; without EXTENDED_HISTORY, entries fall back
# to the current time. Amount imported is bounded by $HISTSIZE.
shhist-import() {
  emulate -L zsh
  zmodload -F zsh/parameter p:history 2>/dev/null

  local count
  count="$(_shhist_sql 'SELECT count(*) FROM commands;')"
  if (( count > 0 )) && [[ "$1" != "-f" ]]; then
    print -u2 "shhist-import: database already has $count commands; use 'shhist-import -f' to import anyway"
    return 1
  fi

  # Timestamps in file order (digits are ASCII, never metafied).
  local -a tss
  local line
  if [[ -r "${HISTFILE:-}" ]]; then
    while IFS= read -r line; do
      [[ "$line" =~ '^: ([0-9]+):[0-9]+;' ]] && tss+=("${match[1]}")
    done < "$HISTFILE"
  fi

  # Loaded events, oldest first. Align with the LAST N timestamps,
  # since zsh loads only the most recent $HISTSIZE entries.
  # Quirk: ${(k)history} does not enumerate the newest event (the current
  # ring slot), but direct subscripting reaches it -- append it manually.
  local -a keys
  keys=(${(kno)history})
  if [[ -n "${history[$HISTCMD]:-}" ]] && (( ${keys[-1]:-0} != HISTCMD )); then
    keys+=($HISTCMD)
  fi
  local offset=$(( ${#tss} - ${#keys} ))
  (( offset < 0 )) && offset=0

  local i=0 n=0 k ts cmd sql="BEGIN;"
  for k in "${keys[@]}"; do
    (( i++ ))
    ts="${tss[offset + i]:-$(date +%s)}"
    cmd="${history[$k]}"
    [[ -z "${cmd//[[:space:]]/}" ]] && continue
    sql+="INSERT INTO commands(cmd, dir, ts) VALUES('$(_shhist_q "$cmd")', NULL, $ts);"$'\n'
    (( n++ ))
  done
  sql+="COMMIT;"

  # Feed via stdin: the script can exceed the argv size limit.
  print -r -- "$sql" \
    | "$SHHIST_SQLITE" -batch -noheader -cmd '.timeout 300' "$SHHIST_DB" >/dev/null \
    && print "shhist-import: imported $n commands"
}
