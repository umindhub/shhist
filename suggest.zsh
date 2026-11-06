# shhist - inline suggestions (zsh-autosuggestions replacement).
# Sourced by widgets.zsh, last. Do not source directly.

# ---------------------------------------------------------------------------
# Ranking
# ---------------------------------------------------------------------------
# Number-or-default helpers: config values are spliced into SQL.
_shhist_num() {  # $1 = value, $2 = default
  [[ "$1" == (<->|<->.<->|.<->) ]] && print -r -- "$1" || print -r -- "$2"
}
_shhist_pos_int() {  # $1 = value, $2 = default
  [[ "$1" == <-> ]] && (( $1 > 0 )) && print -r -- "$1" || print -r -- "$2"
}

# SQL score of one cmd group (aggregate over its rows' ts), higher = better.
# Algorithms (SHHIST_SUGGEST_RANK):
#   duallog  W * S(short) + log2(1 + S(long))       (default)
#   dual     W * S(short) + S(long)
#   single   S(long)                                 (previous behavior)
#   seg      runs * weight of the newest run's age bucket (SHHIST_SUGGEST_SEGS)
#   recent   newest run wins (zsh-autosuggestions behavior)
# where S(h) = SUM(0.5 ^ (age / h)), short = SHHIST_HALFLIFE_CMD_SHORT,
# long = SHHIST_HALFLIFE_CMD, W = SHHIST_SUGGEST_SHORT_WEIGHT.
_shhist_cmd_score_sql() {  # $1 = algorithm (optional, default from config)
  local algo="${1:-${SHHIST_SUGGEST_RANK:-duallog}}"
  local age="(strftime('%s','now') - ts)"
  local hs hl w
  hs="$(_shhist_pos_int "$SHHIST_HALFLIFE_CMD_SHORT" 21600)"
  hl="$(_shhist_pos_int "$SHHIST_HALFLIFE_CMD" 1209600)"
  w="$(_shhist_num "$SHHIST_SUGGEST_SHORT_WEIGHT" 2)"
  local ss="SUM(pow(0.5, $age / ${hs}.0))"
  local sl="SUM(pow(0.5, $age / ${hl}.0))"
  case "$algo" in
    (dual)   print -r -- "($w * $ss + $sl)" ;;
    (single) print -r -- "$sl" ;;
    (recent) print -r -- "MAX(ts)" ;;
    (seg)
      # Rules "max_age:weight", checked in order; a bare weight is the fallback.
      local r sql="CASE" last="0.25"
      for r in "${SHHIST_SUGGEST_SEGS[@]}"; do
        if [[ "$r" == *:* ]]; then
          sql+=" WHEN MIN($age) < $(_shhist_pos_int "${r%%:*}" 3600) THEN $(_shhist_num "${r#*:}" 1)"
        else
          last="$(_shhist_num "$r" 0.25)"
        fi
      done
      print -r -- "(COUNT(*) * $sql ELSE $last END)" ;;
    (*)      print -r -- "($w * $ss + log2(1 + $sl))" ;;
  esac
}

# Full ranking query for prefix candidates. Ties go to the newest run.
_shhist_suggest_sql() {  # $1 = prefix (raw), $2 = limit, $3 = algorithm, $4 = 1 to include score
  local q="$(_shhist_q "$1")" score="$(_shhist_cmd_score_sql "$3")" cols="cmd"
  (( ${4:-0} )) && cols="printf('%10.3f', $score) AS score, COUNT(*) AS runs, datetime(MAX(ts), 'unixepoch', 'localtime') AS last, cmd"
  print -r -- "
    SELECT $cols FROM commands
    WHERE cmd > '$q' AND cmd < '$q' || char(1114111)
      AND instr(cmd, char(10)) = 0
    GROUP BY cmd
    ORDER BY $score DESC, MAX(ts) DESC
    LIMIT $2;"
}

# Inspect ranking on real data, e.g. to compare algorithms before switching.
#   shhist-rank [-a duallog|dual|single|seg|recent] [-n N] PREFIX
shhist-rank() {
  emulate -L zsh
  local algo="" n=10 opt OPTARG OPTIND
  while getopts 'a:n:' opt; do
    case "$opt" in
      (a) algo="$OPTARG" ;;
      (n) n="$(_shhist_pos_int "$OPTARG" 10)" ;;
      (*) print -u2 "usage: shhist-rank [-a algo] [-n N] PREFIX"; return 2 ;;
    esac
  done
  shift $(( OPTIND - 1 ))
  if [[ -z "$1" ]]; then
    print -u2 "usage: shhist-rank [-a duallog|dual|single|seg|recent] [-n N] PREFIX"
    return 2
  fi
  print -r -- "algorithm: ${algo:-${SHHIST_SUGGEST_RANK:-duallog}}"
  "$SHHIST_SQLITE" -batch -header -column -cmd '.timeout 300' "$SHHIST_DB" \
    "$(_shhist_suggest_sql "$*" "$n" "$algo" 1)"
}

# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------
# Best command starting with $1, ranked by _shhist_cmd_score_sql. The top
# $SHHIST_SUGGEST_CANDIDATES rows go through the strict scan, so a command
# whose program or file operands are gone right now is skipped -- not
# deleted: it may work again later (venv activated, disk mounted, ...).
# The range test `cmd > p AND cmd < p || U+10FFFF` is a prefix match that
# can use idx_commands_cmd and needs no LIKE escaping.
# REPLY = suggestion, '' if none.
_shhist_suggest_query() {  # $1 = prefix
  emulate -L zsh
  local prefix="$1" cand
  REPLY=""
  [[ -n "$prefix" ]] || return 1
  local -a cands
  cands=("${(@f)$(_shhist_sql "$(_shhist_suggest_sql "$prefix" \
    "$(_shhist_pos_int "$SHHIST_SUGGEST_CANDIDATES" 20)")")}")
  for cand in "${cands[@]}"; do
    [[ -n "$cand" && "$cand" == "$prefix"?* ]] || continue
    _shhist_cmd_scan strict "$cand" "$PWD"
    if [[ -z "$REPLY" ]]; then
      REPLY="$cand"
      return 0
    fi
  done
  REPLY=""
  return 1
}

# ---------------------------------------------------------------------------
# Legacy mode: zsh-autosuggestions still loaded -> act as its strategy
# ---------------------------------------------------------------------------
if (( $+functions[_zsh_autosuggest_start] )); then
  _zsh_autosuggest_strategy_shhist() {
    typeset -g suggestion
    _shhist_suggest_query "$1"
    suggestion="$REPLY"
  }
  case "${SHHIST_SUGGEST_MODE:u}" in
    A)  ZSH_AUTOSUGGEST_STRATEGY=(shhist) ;;
    AB) ZSH_AUTOSUGGEST_STRATEGY=(shhist history) ;;
    *)  ZSH_AUTOSUGGEST_STRATEGY=(history) ;;
  esac
  if (( ${SHHIST_SUGGEST:-1} )); then
    print -u2 "shhist: zsh-autosuggestions is loaded -- remove it from plugins=(...) to use shhist's own suggestions (SHHIST_SUGGEST=0 silences this)"
  fi
  return 0
fi
(( ${SHHIST_SUGGEST:-1} )) || return 0

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
typeset -g  _SHHIST_SUG_BUF=""    # BUFFER the cache was last computed for
typeset -g  _SHHIST_SUG_FULL=""   # full suggested line, '' = none
typeset -gi _SHHIST_SUG_OFF=0     # 1 between line-finish and next line-init

# Widgets after which no suggestion is shown until the user types again
# (history navigation already put a whole command in the buffer).
typeset -g _SHHIST_SUG_QUIET_PAT='(*history*|*beginning-search*|*-search-*|copy-earlier-word)'

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------
_shhist_sug_refresh() {
  local buf="$BUFFER"
  if [[ "$LASTWIDGET" == ${~_SHHIST_SUG_QUIET_PAT} ]]; then
    _SHHIST_SUG_FULL="" _SHHIST_SUG_BUF="$buf"
    return
  fi
  # Input still queued (paste, fast typing): wait, refresh on a later redraw.
  if (( PENDING || KEYS_QUEUED_COUNT )); then
    _SHHIST_SUG_FULL=""
    return
  fi
  _SHHIST_SUG_BUF="$buf"
  if [[ -z "$buf" || "$buf" == *$'\n'* ]] || (( CURSOR != $#buf )); then
    _SHHIST_SUG_FULL=""
    return
  fi
  # Typing along the current suggestion: keep it, no query needed.
  [[ -n "$_SHHIST_SUG_FULL" && "$_SHHIST_SUG_FULL" == "$buf"?* ]] && return
  _shhist_suggest_query "$buf"
  _SHHIST_SUG_FULL="$REPLY"
}

# line-pre-redraw hook: runs before every redraw, so the ghost text follows
# any edit without wrapping the editing widgets themselves.
_shhist_sug_redraw() {
  emulate -L zsh
  region_highlight=("${(@)region_highlight:#*memo=shhist}")
  if (( _SHHIST_SUG_OFF )); then
    POSTDISPLAY=""
    return
  fi
  [[ "$BUFFER" != "$_SHHIST_SUG_BUF" ]] && _shhist_sug_refresh
  if (( CURSOR == $#BUFFER )) && [[ -n "$_SHHIST_SUG_FULL" && "$_SHHIST_SUG_FULL" == "$BUFFER"?* ]]; then
    POSTDISPLAY="${_SHHIST_SUG_FULL:$#BUFFER}"
    region_highlight+=("$#BUFFER $(( $#BUFFER + $#POSTDISPLAY )) ${SHHIST_SUGGEST_STYLE:-fg=8} memo=shhist")
  else
    POSTDISPLAY=""
  fi
}

_shhist_sug_line_init() {
  _SHHIST_SUG_BUF="" _SHHIST_SUG_FULL="" _SHHIST_SUG_OFF=0
}

# Clear the ghost text so it doesn't stay on the executed line.
_shhist_sug_line_finish() {
  _SHHIST_SUG_OFF=1
  POSTDISPLAY=""
  region_highlight=("${(@)region_highlight:#*memo=shhist}")
  zle -R
}

# ---------------------------------------------------------------------------
# Accepting
# ---------------------------------------------------------------------------
# Whole suggestion (Right arrow, End, ...). Elsewhere on the line the key
# keeps its normal meaning.
_shhist_sug_accept() {  # $1 = original widget, rest = its args
  local orig="$1"; shift
  if [[ -n "$POSTDISPLAY" ]] && (( CURSOR == $#BUFFER )); then
    BUFFER+="$POSTDISPLAY"
    POSTDISPLAY=""
    CURSOR=$#BUFFER
  else
    zle "$orig" -- "$@"
  fi
}

# Up to the next word: run the motion over buffer + suggestion, then split
# at wherever the cursor landed.
_shhist_sug_partial() {  # $1 = original widget, rest = its args
  local orig="$1"; shift
  if [[ -z "$POSTDISPLAY" ]] || (( CURSOR != $#BUFFER )); then
    zle "$orig" -- "$@"
    return
  fi
  local full="$BUFFER$POSTDISPLAY"
  local -i at=$CURSOR
  POSTDISPLAY=""
  BUFFER="$full"
  CURSOR=$at
  zle "$orig" -- "$@"
  if (( CURSOR <= at )); then
    BUFFER="${full[1,at]}"
    CURSOR=$at
  elif (( CURSOR < $#full )); then
    BUFFER="${full[1,CURSOR]}"
  fi
}

# Dedicated key (SHHIST_BIND_ACCEPT_WORD): next word of the suggestion if
# one is showing, otherwise a normal forward-char.
_shhist_sug_accept_word() {
  if [[ -n "$POSTDISPLAY" ]] && (( CURSOR == $#BUFFER )); then
    _shhist_sug_partial .forward-word "$@"
  else
    zle forward-char -- "$@"
  fi
}

# Replace widget $1 by a wrapper that calls handler $2 with the previous
# implementation: another plugin's user widget if there was one, else the
# builtin (.name). Re-sourcing never wraps our own wrapper.
_shhist_sug_wrap() {  # $1 = widget, $2 = accept | partial
  local w="$1" handler="$2" cur="${widgets[$1]:-}" fn="_shhist_sug_w_${1//-/_}"
  [[ "$cur" == "user:$fn" ]] && return 0
  local orig=".$w"
  if [[ "$cur" == user:* ]]; then
    orig="_shhist_sug_orig_${w//-/_}"
    zle -N "$orig" "${cur#user:}"
  elif [[ "$cur" != builtin ]]; then
    return 0                       # completion widget etc.: leave alone
  fi
  functions[$fn]="_shhist_sug_$handler ${(q)orig} \"\$@\""
  zle -N "$w" "$fn"
}

# ---------------------------------------------------------------------------
# Wiring
# ---------------------------------------------------------------------------
() {
  local w
  for w in "${SHHIST_SUGGEST_ACCEPT_WIDGETS[@]}"; do _shhist_sug_wrap "$w" accept; done
  for w in "${SHHIST_SUGGEST_PARTIAL_WIDGETS[@]}"; do _shhist_sug_wrap "$w" partial; done
}

zle -N _shhist_sug_accept_word
if [[ -n "$SHHIST_BIND_ACCEPT_WORD" ]]; then
  bindkey -M emacs "$SHHIST_BIND_ACCEPT_WORD" _shhist_sug_accept_word
  bindkey -M viins "$SHHIST_BIND_ACCEPT_WORD" _shhist_sug_accept_word
fi

autoload -Uz add-zle-hook-widget
zle -N _shhist_sug_redraw
zle -N _shhist_sug_line_init
zle -N _shhist_sug_line_finish
add-zle-hook-widget line-pre-redraw _shhist_sug_redraw
add-zle-hook-widget line-init       _shhist_sug_line_init
add-zle-hook-widget line-finish     _shhist_sug_line_finish
