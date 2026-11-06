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
# PRAGMA user_version: 0/1 = original, 2 = frecency has score_s + runs.
_shhist_init_db() {
  if [[ ! -f "$SHHIST_DB" ]]; then
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
      -- kind: 'dir' | 'file'. score / score_s are the long / short
      -- half-life scores, decayed lazily at read/write time, so no
      -- periodic maintenance job is ever needed. runs = total visits.
      CREATE TABLE IF NOT EXISTS frecency(
        kind    TEXT NOT NULL,
        path    TEXT NOT NULL,
        score   REAL NOT NULL,
        score_s REAL NOT NULL DEFAULT 0,
        runs    INTEGER NOT NULL DEFAULT 0,
        last_ts INTEGER NOT NULL,
        PRIMARY KEY(kind, path)
      );
      PRAGMA user_version = 2;
    " >/dev/null
    return 0
  fi
  local v
  v="$(_shhist_sql 'PRAGMA user_version;' 2>/dev/null)"
  (( ${v:-0} >= 2 )) && return 0
  _shhist_migrate_v2
}

# Add score_s / runs to an old frecency table. The history of each row is
# unknown, so: score_s = the last visit only, runs = rounded long score.
# Safe if two shells race: a duplicate ALTER just fails, the rest repeats.
_shhist_migrate_v2() {
  local hs_dir hs_file
  _shhist_halflives dir;  hs_dir="${reply[1]}"
  _shhist_halflives file; hs_file="${reply[1]}"
  _shhist_sql "
    ALTER TABLE frecency ADD COLUMN score_s REAL NOT NULL DEFAULT 0;
    ALTER TABLE frecency ADD COLUMN runs INTEGER NOT NULL DEFAULT 0;
    UPDATE frecency SET
      score_s = pow(0.5, (strftime('%s','now') - last_ts)
                / (CASE kind WHEN 'dir' THEN ${hs_dir}.0 ELSE ${hs_file}.0 END)),
      runs    = max(1, CAST(round(score) AS INTEGER));
    PRAGMA user_version = 2;
  " >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Ranking (shared by suggestions, Ctrl+R, j, v / shf, Ctrl+G)
# ---------------------------------------------------------------------------
# Config values get spliced into SQL, so they are validated first.
_shhist_num() {  # $1 = value, $2 = default -> REPLY
  [[ "$1" == (<->|<->.<->|.<->) ]] && REPLY="$1" || REPLY="$2"
}
_shhist_pos_int() {  # $1 = value, $2 = default -> REPLY
  [[ "$1" == <-> ]] && (( $1 > 0 )) && REPLY="$1" || REPLY="$2"
}

# reply = (short half-life, long half-life) in seconds.
_shhist_halflives() {  # $1 = cmd | dir | file
  local s l d hs
  case "$1" in
    (dir)  s="$SHHIST_HALFLIFE_DIR_SHORT"  l="$SHHIST_HALFLIFE_DIR"  d=604800 ;;
    (file) s="$SHHIST_HALFLIFE_FILE_SHORT" l="$SHHIST_HALFLIFE_FILE" d=259200 ;;
    (*)    s="$SHHIST_HALFLIFE_CMD_SHORT"  l="$SHHIST_HALFLIFE_CMD"  d=1209600 ;;
  esac
  _shhist_pos_int "$s" 21600; hs="$REPLY"
  _shhist_pos_int "$l" "$d"
  reply=("$hs" "$REPLY")
}

# REPLY = algorithm for a feature: SHHIST_<feature>_RANK, else SHHIST_RANK.
_shhist_algo() {  # $1 = SUGGEST | HISTORY | JUMP | FILE
  local var="SHHIST_${1}_RANK"
  REPLY="${${(P)var}:-${SHHIST_RANK:-duallog}}"
  [[ "$REPLY" == (duallog|dual|single|seg|recent) ]] || REPLY=duallog
}

# REPLY = SQL score expression, higher = better.
#   duallog  W * S_short + log2(1 + S_long)
#   dual     W * S_short + S_long
#   single   S_long
#   seg      runs * weight of the newest visit's age bucket
#   recent   newest visit
_shhist_rank_expr() {  # $1 = algo, $2 = S_short, $3 = S_long, $4 = runs, $5 = newest age, $6 = newest ts
  local w
  _shhist_num "$SHHIST_RANK_SHORT_WEIGHT" 2; w="$REPLY"
  case "$1" in
    (dual)   REPLY="($w * $2 + $3)" ;;
    (single) REPLY="$3" ;;
    (recent) REPLY="$6" ;;
    (seg)
      # Rules "max_age:weight" checked in order; a bare weight is the fallback.
      local r lim wt cases="" last=0.25
      for r in "${SHHIST_RANK_SEGS[@]}"; do
        if [[ "$r" == *:* ]]; then
          _shhist_pos_int "${r%%:*}" 3600; lim="$REPLY"
          _shhist_num "${r#*:}" 1; wt="$REPLY"
          cases+=" WHEN $5 < $lim THEN $wt"
        else
          _shhist_num "$r" 0.25; last="$REPLY"
        fi
      done
      if [[ -n "$cases" ]]; then
        REPLY="($4 * CASE$cases ELSE $last END)"
      else
        REPLY="($4 * $last)"
      fi ;;
    (*)      REPLY="($w * $2 + log2(1 + $3))" ;;
  esac
}

# REPLY = score of one GROUP BY cmd group of the commands table.
_shhist_cmd_score_sql() {  # $1 = algorithm
  local age="(strftime('%s','now') - ts)"
  _shhist_halflives cmd
  _shhist_rank_expr "$1" \
    "SUM(pow(0.5, $age / ${reply[1]}.0))" \
    "SUM(pow(0.5, $age / ${reply[2]}.0))" \
    "COUNT(*)" "MIN($age)" "MAX(ts)"
}

# REPLY = score of one frecency row, decayed to now.
_shhist_path_score_sql() {  # $1 = kind, $2 = algorithm
  local age="(strftime('%s','now') - last_ts)"
  _shhist_halflives "$1"
  _shhist_rank_expr "$2" \
    "score_s * pow(0.5, $age / ${reply[1]}.0)" \
    "score * pow(0.5, $age / ${reply[2]}.0)" \
    "runs" "$age" "last_ts"
}

# REPLY = WHERE condition: cmd starts with $1 (index-friendly, no LIKE escaping).
_shhist_prefix_cond() {  # $1 = prefix
  local q="${1//\'/''}"
  REPLY="cmd > '$q' AND cmd < '$q' || char(1114111)"
}

# SQL for Ctrl+R: one row per command, "id<sep>display", best-first.
_shhist_history_sql() {  # $1 = dir to restrict to, '' = all dirs
  local where=""
  [[ -n "$1" ]] && where="WHERE dir = '${1//\'/''}'"
  _shhist_algo HISTORY
  _shhist_cmd_score_sql "$REPLY"
  print -r -- "
    SELECT MAX(id), replace(cmd, char(10), ' ⏎ ')
    FROM commands $where GROUP BY cmd
    ORDER BY $REPLY DESC, MAX(ts) DESC LIMIT ${SHHIST_FZF_LIMIT:-20000};"
}

# Inspect ranking on real data, e.g. to compare algorithms before switching.
#   shhist-rank [-k cmd|dir|file] [-a algo] [-n N] [WORDS...]
# cmd: WORDS = command prefix (empty = whole history, i.e. Ctrl+R order).
# dir/file: WORDS match like `j foo bar` (*foo*bar*).
shhist-rank() {
  emulate -L zsh
  local kind=cmd algo="" n=10 opt OPTARG OPTIND usage
  usage="usage: shhist-rank [-k cmd|dir|file] [-a duallog|dual|single|seg|recent] [-n N] [WORDS...]"
  while getopts 'k:a:n:' opt; do
    case "$opt" in
      (k) kind="$OPTARG" ;;
      (a) algo="$OPTARG" ;;
      (n) _shhist_pos_int "$OPTARG" 10; n="$REPLY" ;;
      (*) print -u2 "$usage"; return 2 ;;
    esac
  done
  shift $(( OPTIND - 1 ))
  if [[ "$kind" != (cmd|dir|file) ]] || [[ -n "$algo" && "$algo" != (duallog|dual|single|seg|recent) ]]; then
    print -u2 "$usage"
    return 2
  fi
  if [[ -z "$algo" ]]; then
    case "$kind" in
      (dir)  _shhist_algo JUMP ;;
      (file) _shhist_algo FILE ;;
      (*)    _shhist_algo SUGGEST ;;
    esac
    algo="$REPLY"
  fi

  local sql score where=""
  if [[ "$kind" == cmd ]]; then
    _shhist_cmd_score_sql "$algo"; score="$REPLY"
    if (( $# )); then
      _shhist_prefix_cond "$*"; where="WHERE $REPLY"
    fi
    sql="SELECT printf('%12.3f', $score) AS score, COUNT(*) AS runs,
           datetime(MAX(ts), 'unixepoch', 'localtime') AS last,
           replace(cmd, char(10), ' ⏎ ') AS cmd
         FROM commands $where GROUP BY cmd
         ORDER BY $score DESC, MAX(ts) DESC LIMIT $n;"
  else
    _shhist_path_score_sql "$kind" "$algo"; score="$REPLY"
    if (( $# )); then
      local pat="%${(j:%:)@}%"
      where="AND path LIKE '${pat//\'/''}'"
    fi
    sql="SELECT printf('%12.3f', $score) AS score, runs,
           datetime(last_ts, 'unixepoch', 'localtime') AS last, path
         FROM frecency WHERE kind = '$kind' $where
         ORDER BY $score DESC, last_ts DESC LIMIT $n;"
  fi
  print -r -- "kind: $kind  algorithm: $algo"
  "$SHHIST_SQLITE" -batch -header -column -cmd '.timeout 300' "$SHHIST_DB" "$sql"
}

# ---------------------------------------------------------------------------
# Frecency primitives
# ---------------------------------------------------------------------------
# REPLY = SQL recording one visit: decay both scores to now, add 1 to each.
_shhist_bump_sql() {  # $1 = kind, $2 = absolute path
  local now="strftime('%s','now')" age="(strftime('%s','now') - last_ts)"
  _shhist_halflives "$1"
  REPLY="
    INSERT INTO frecency(kind, path, score, score_s, runs, last_ts)
    VALUES ('$1', '${2//\'/''}', 1.0, 1.0, 1, $now)
    ON CONFLICT(kind, path) DO UPDATE SET
      score   = score   * pow(0.5, $age / ${reply[2]}.0) + 1.0,
      score_s = score_s * pow(0.5, $age / ${reply[1]}.0) + 1.0,
      runs    = runs + 1,
      last_ts = $now;"
}

# Record one visit.
_shhist_bump() {  # $1 = kind, $2 = absolute path
  _shhist_bump_sql "$1" "$2"
  _shhist_sql "$REPLY"
}

# Build the SQL for _shhist_frecent WITHOUT running it. Split out so the
# fzf-based pickers can hand the exact same query string to fzf's
# `reload(...)` action -- letting them refresh the candidate list in
# place after a delete instead of closing and relaunching fzf (which is
# what caused the list to visibly jump by one line).
_shhist_frecent_sql() {  # $1 = kind, $2 = LIKE pattern or ''
  local where=""
  [[ -n "$2" ]] && where="AND path LIKE '${2//\'/''}'"
  if [[ "$1" == dir ]]; then _shhist_algo JUMP; else _shhist_algo FILE; fi
  _shhist_path_score_sql "$1" "$REPLY"
  print -r -- "SELECT path FROM frecency WHERE kind = '$1' $where ORDER BY $REPLY DESC, last_ts DESC;"
}

# List paths of a kind, best-first. $2 is an optional LIKE pattern.
_shhist_frecent() {  # $1 = kind, $2 = LIKE pattern or ''
  _shhist_sql "$(_shhist_frecent_sql "$1" "$2")"
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
    INSERT INTO frecency(kind, path, score, score_s, runs, last_ts)
      SELECT kind, '$n' || substr(path, length('$o') + 1), score, score_s, runs, last_ts
      FROM frecency WHERE $pm
    ON CONFLICT(kind, path) DO UPDATE SET
      score   = frecency.score + excluded.score,
      score_s = frecency.score_s + excluded.score_s,
      runs    = frecency.runs + excluded.runs,
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
# Broken commands: program not found, file/dir operand missing
# ---------------------------------------------------------------------------
# Is $1 (a raw (z)-split word) a path that does not exist? Relative paths
# resolve against $2; with $3=1, cdpath entries count too (cd/pushd).
# On success REPLY = abs | rel. Returns 1 when present or not checkable.
_shhist_path_missing() {  # $1 = raw word, $2 = base dir, $3 = use cdpath
  local w="$1" base="$2" p full d
  # Expansions, globs, brace/process substitution: unknowable at rest.
  [[ "$w" == *[\$\`\*\?\[\{\(]* ]] && return 1
  p="${(Q)w}"
  [[ -n "$p" && "$p" != (.|..) ]] || return 1
  if [[ "$p" == '~' || "$p" == '~/'* ]]; then
    p="${HOME}${p#\~}"
  elif [[ "$p" == '~'* ]]; then
    return 1                                   # ~user / named dirs
  fi
  if [[ "$p" == /* ]]; then
    full="$p"; REPLY=abs
  else
    [[ -n "$base" ]] || return 1
    full="$base/$p"; REPLY=rel
  fi
  [[ -e "$full" || -L "$full" ]] && return 1
  _shhist_offline "${full:a}" && return 1
  if (( ${3:-0} )) && [[ "$REPLY" == rel ]]; then
    for d in "${cdpath[@]}"; do
      [[ -d "$d/$p" ]] && return 1
    done
  fi
  return 0
}

# Inspect one command line for things that can't work right now.
#   REPLY = cmd -> a command word resolves to nothing (alias, function,
#                  builtin, PATH, directory for auto_cd)
#           abs -> an absolute or ~ path operand is missing
#           rel -> a relative path operand is missing (relative to $3)
#           ''  -> nothing wrong found
# Modes: strict = only operands that are certainly paths (used to filter
# suggestions); fail = also guess paths from shape (used after a non-zero
# exit, where a wrong guess costs little).
_shhist_cmd_scan() {  # $1 = strict | fail, $2 = command line, $3 = its dir
  emulate -L zsh
  setopt extendedglob
  REPLY=""
  local mode="$1" base="$3" found="" w p name kind
  local -i at_cmd=1 skip_seg=0 skip_next=0 opts=0 operand=0 dd=0 chdir=0 cdp=0
  local -a words
  words=(${(z)2})

  for w in "${words[@]}"; do
    if (( skip_next )); then
      skip_next=0
      continue
    fi
    # Separators start a new simple command.
    if [[ "$w" == ('&&'|'||'|';'|'|'|'|&'|'&'|'&!'|'&|'|';;'|$'\n'|'('|')'|'{'|'}') ]]; then
      at_cmd=1 skip_seg=0 kind=""
      # After a directory change, relative paths no longer mean $base.
      (( chdir )) && base=""
      chdir=0
      continue
    fi
    # Redirection operator: skip it and its target.
    if [[ "$w" == [0-9]#[\<\>]* || "$w" == '&>'* ]]; then
      skip_next=1
      continue
    fi
    (( skip_seg )) && continue

    if (( at_cmd )); then
      [[ "$w" == [A-Za-z_][A-Za-z0-9_]#=* ]] && continue          # VAR=val
      p="${(Q)w}"
      case "$p" in
        (if|then|else|elif|while|until|do|'!'|time|sudo|doas|command|builtin|exec|nocorrect|noglob|nohup|env)
          continue ;;
        (for|foreach|case|select|repeat|function|coproc|'[['|'['|test|'(('*)
          skip_seg=1; continue ;;
        (-*)
          # Precommand option of unknown arity (sudo -u x ...): give up.
          skip_seg=1; continue ;;
      esac
      at_cmd=0 opts=0 operand=0 dd=0 cdp=0
      if [[ -z "$p" || "$w" == *[\$\`\*\?\[\(]* ]]; then
        skip_seg=1
        continue
      fi
      if [[ "$p" == */* ]]; then
        # Script/program given by path.
        if _shhist_path_missing "$w" "$base"; then
          [[ "$REPLY" == abs ]] && found=abs || { [[ -z "$found" ]] && found=rel }
        fi
        name="${p:t}"
      elif whence -- "$p" >/dev/null 2>&1; then
        name="$p"
      elif [[ -n "$base" && -d "$base/$p" ]]; then
        name="$p"; chdir=1                                          # auto_cd
        kind=nocheck
        continue
      else
        REPLY=cmd
        return 0
      fi
      [[ "$name" == (cd|pushd|popd|"$SHHIST_JUMP_CMD") ]] && chdir=1
      [[ "$name" == (cd|pushd) ]] && cdp=1
      if (( ${SHHIST_NOCHECK_CMDS[(Ie)$name]} )); then
        kind=nocheck
      elif (( ${SHHIST_INTERP_CMDS[(Ie)$name]} )); then
        kind=interp
      elif (( ${SHHIST_PATH_CMDS[(Ie)$name]} )); then
        kind=paths
      else
        kind=generic
      fi
      continue
    fi

    # Operand of the current command.
    [[ "$kind" == nocheck ]] && continue
    if (( ! dd )) && [[ "$w" == -* ]]; then
      [[ "$w" == -- ]] && dd=1
      opts=1
      continue
    fi
    p="${(Q)w}"
    [[ -z "$p" || "$p" == +* || "$p" == <-> || "$p" == *=* ]] && continue

    case "$kind" in
      (interp)
        # Only a first operand with no option before it is surely the
        # script; everything after it belongs to the script.
        skip_seg=1
        (( opts )) && continue
        ;;
      (paths) ;;
      (generic)
        [[ "$p" == *:* ]] && continue                               # URL, host:path, a:b
        if [[ "$p" != (/|'~'|./|../)* ]]; then
          # Shape guess, fail mode only: a/b where a/ exists but b doesn't.
          [[ "$mode" == fail && "$p" == */* && -n "$base" && -d "$base/${p:h}" ]] || continue
        fi
        ;;
    esac
    if _shhist_path_missing "$w" "$base" $cdp; then
      [[ "$REPLY" == abs ]] && found=abs || { [[ -z "$found" ]] && found=rel }
    fi
  done
  REPLY="$found"
}

# Delete a broken command. A missing program or absolute path is broken
# everywhere, so every row of that command goes; a missing relative path
# only drops the rows recorded in that same directory.
_shhist_forget_sql() {  # $1 = reason (cmd|abs|rel), $2 = command line, $3 = dir
  local where="cmd = '$(_shhist_q "$2")'"
  [[ "$1" == rel ]] && where+=" AND dir = '$(_shhist_q "$3")'"
  print -r -- "DELETE FROM commands WHERE $where;"
}

# Batch version of the post-command check, for history recorded before
# it existed (or imported). Rows with a failing exit code get the fail
# scan, all others the strict one.
#   shhist-clean -n   list what would be removed
#   shhist-clean      remove it
shhist-clean() {
  emulate -L zsh
  local dry=0
  [[ "$1" == -n ]] && dry=1
  local fs=$'\x1f' rs=$'\x1e' row cmd dir code mode key sql="" n=0
  local -A seen
  local -a rows
  rows=("${(@ps:$rs:)$("$SHHIST_SQLITE" -batch -noheader -cmd '.timeout 300' \
           -separator "$fs" -newline "$rs" "$SHHIST_DB" "
    SELECT cmd, ifnull(dir, ''), ifnull(exit_code, '') FROM commands
    WHERE id IN (SELECT MAX(id) FROM commands GROUP BY cmd, dir);")}")

  for row in "${rows[@]}"; do
    [[ -n "$row" ]] || continue
    cmd="${row%%$fs*}"; row="${row#*$fs}"
    dir="${row%%$fs*}"; code="${row#*$fs}"
    mode=strict
    [[ "$code" == <-> ]] && (( code != 0 && code < 128 )) && mode=fail
    _shhist_cmd_scan "$mode" "$cmd" "$dir"
    [[ -n "$REPLY" ]] || continue
    key="$cmd"
    [[ "$REPLY" == rel ]] && key+="$fs$dir"
    (( ${+seen[$key]} || ${+seen[$cmd]} )) && continue
    seen[$key]=1
    (( n++ ))
    if (( dry )); then
      print -r -- "[$REPLY] ${cmd//$'\n'/ ⏎ }${dir:+   ($dir)}"
    else
      sql+="$(_shhist_forget_sql "$REPLY" "$cmd" "$dir")"$'\n'
    fi
  done

  if (( dry )); then
    print "shhist-clean: $n commands would be removed (run without -n to remove)"
    return 0
  fi
  # Feed via stdin: the script can exceed the argv size limit.
  if (( n )); then
    print -r -- "BEGIN; $sql COMMIT;" \
      | "$SHHIST_SQLITE" -batch -noheader -cmd '.timeout 300' "$SHHIST_DB" >/dev/null
  fi
  print "shhist-clean: removed $n commands"
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
    _shhist_bump_sql file "$p"
    sql+="$REPLY"
    (( n++ ))
  done

  typeset -g _SHHIST_LAST_ID="$(_shhist_sql "$sql")"
  typeset -g _SHHIST_LAST_CMD="$cmdline" _SHHIST_LAST_DIR="$PWD"
}

# precmd: attach the exit code to the command we just logged. A failed
# command whose program or file operand doesn't exist is forgotten instead
# (signals, i.e. exit >= 128 such as Ctrl+C, never count as failures).
_shhist_precmd() {
  local code=$?
  _shhist_apply_mv $code
  local id="$_SHHIST_LAST_ID" cmd="$_SHHIST_LAST_CMD" dir="$_SHHIST_LAST_DIR"
  _SHHIST_LAST_ID="" _SHHIST_LAST_CMD="" _SHHIST_LAST_DIR=""
  [[ "$id" == <-> ]] || return 0

  if (( ${SHHIST_PRUNE_FAILED:-1} && code != 0 && code < 128 )); then
    _shhist_cmd_scan fail "$cmd" "$dir"
    if [[ -n "$REPLY" ]]; then
      _shhist_sql "$(_shhist_forget_sql "$REPLY" "$cmd" "$dir")" >/dev/null
      return 0
    fi
  fi

  (( SHHIST_TRACK_EXIT )) || return 0
  _shhist_sql "UPDATE commands SET exit_code = $code WHERE id = $id;"
}

# chpwd: every directory change feeds the jump database.
_shhist_chpwd() {
  _shhist_bump dir "$PWD"
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
