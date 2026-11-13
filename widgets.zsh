# shhist - entry point. Add to ~/.zshrc AFTER fzf keybindings and other
# plugins (oh-my-zsh), so its widgets wrap theirs:
#
#   source ~/.config/shhist/widgets.zsh
#
# shhist brings its own inline suggestions; drop zsh-autosuggestions from
# plugins=(...) (see SHHIST_SUGGEST in config.zsh).

[[ -o interactive ]] || return 0

# Directory this file lives in.
typeset -g SHHIST_HOME="${${(%):-%N}:A:h}"

source "$SHHIST_HOME/config.zsh"
# Untracked local overrides (gitignored): re-export any setting here so
# `git pull` never conflicts with your customizations.
[[ -f "$SHHIST_HOME/config.local.zsh" ]] && source "$SHHIST_HOME/config.local.zsh"
source "$SHHIST_HOME/core.zsh"

_shhist_resolve_sqlite || return 1
_shhist_init_db

autoload -Uz add-zsh-hook
add-zsh-hook preexec _shhist_preexec
add-zsh-hook precmd  _shhist_precmd
add-zsh-hook chpwd   _shhist_chpwd

# ---------------------------------------------------------------------------
# Quick pick: Opt+1..9,0 -> 1st..10th row
# ---------------------------------------------------------------------------
# Fills $reply with fzf --bind args. A plain pos(N)+accept would clamp to
# the last row when fewer than N rows exist, so the bind is guarded by
# $FZF_MATCH_COUNT and does nothing in that case.
_shhist_quick_binds() {
  reply=()
  (( ${SHHIST_QUICK_PICK:-1} )) || return 0
  local -a mac=('¡' '™' '£' '¢' '∞' '§' '¶' '•' 'ª' 'º')
  local i cmd
  for i in {1..10}; do
    cmd="[ \"\${FZF_MATCH_COUNT:-0}\" -ge $i ] && echo \"pos($i)+accept\""
    reply+=("--bind=alt-$(( i % 10 )):transform:$cmd")
    (( ${SHHIST_QUICK_PICK_MAC:-1} )) && reply+=("--bind=${mac[i]}:transform:$cmd")
  done
}

# 1 when rows carry visible Opt+N labels (label.zsh).
_shhist_labels_on() { (( ${SHHIST_QUICK_PICK:-1} && ${SHHIST_QUICK_LABEL:-1} )) }

# Width fzf will give the list (FZF_COLUMNS only exists once fzf runs).
_shhist_list_cols() {
  REPLY=$COLUMNS
  [[ "$SHHIST_FZF_OPTS" == *--border* ]] && (( REPLY -= 4 ))
  return 0
}

# Header hint for the quick-pick keys; empty when labels already show them.
_shhist_quick_hint() {
  if (( ${SHHIST_QUICK_PICK:-1} )) && ! _shhist_labels_on; then
    REPLY=" | opt+1~0: pick 1~10"
  else
    REPLY=""
  fi
}

# ---------------------------------------------------------------------------
# Shared fzf-over-frecency picker (used by jump/edit/shf/Tab)
# ---------------------------------------------------------------------------
# Runs fzf over all frecent paths of a given kind. $SHHIST_DELETE_KEY
# deletes the highlighted row WITHOUT closing fzf: it writes the selected
# path to a private temp file (so an arbitrary path -- quotes and all --
# never has to be spliced into a SQL string) and deletes by matching that
# file's content via sqlite's readfile(), then reload() re-runs the same
# query in place. fzf's process (and terminal geometry) never restarts,
# so the list no longer visibly jumps by a line the way closing and
# relaunching fzf did. Prints the chosen path on Enter, or nothing if
# aborted. Requires an fzf new enough to support nested parens in
# --bind action arguments, and an sqlite3 CLI with readfile() (standard
# in stock builds).
# fzf runner for the frecency path lists. $1=kind $2=prompt $3=query
# $4=header $5..=extra fzf args. Prints fzf's output (selected path, with an
# --expect key line first when given); nothing if aborted.
# Labels on : fzf only draws (--disabled); rows.sh filters (fzf --filter, same
#   fuzzy scheme) and labels, so Opt+N always matches the row shown. Rows are
#   "path<SEP>display"; the path is field 1 and is all we ever print/delete.
# Labels off: plain fzf filtering, rows are bare paths.
_shhist_fzf_paths() {
  local kind="$1" prompt="$2" query="$3" header="$4"
  shift 4
  local list_sql tmp out hint cols sep=$'\x1f'
  local -a qb
  _shhist_list_cols; cols="$REPLY"
  _shhist_quick_binds; qb=("${reply[@]}")
  _shhist_quick_hint; hint="$REPLY"
  (( ${SHHIST_PRUNE_ON_PICK:-1} )) && shhist-prune -q "$kind"
  list_sql="$(_shhist_frecent_sql "$kind" '')"
  tmp="$(mktemp "${TMPDIR:-/tmp}/shhist_del.XXXXXX")"

  local del_write reload_cmd
  local -a mode
  if _shhist_labels_on; then
    del_write="printf '%s' {} | cut -d \"\$SHHIST_SEP\" -f1 | tr -d '\\n' > \"\$SHHIST_DEL_FILE\""
    reload_cmd="sh \"\$SHHIST_ROWS\" \"\$FZF_QUERY\""
    mode=(--disabled --delimiter="$sep" --with-nth=2.. \
          --bind='change:reload:sh "$SHHIST_ROWS" {q}')
  else
    del_write="printf '%s' {} > \"\$SHHIST_DEL_FILE\""
    reload_cmd="\"\$SHHIST_SQLITE\" -batch -noheader \"\$SHHIST_DB\" \"\$SHHIST_LIST_SQL\""
    mode=(--scheme=path --no-sort)
  fi

  out="$(
    export SHHIST_LIST_SQL="$list_sql" SHHIST_DEL_FILE="$tmp" SHHIST_KIND="$kind" \
           SHHIST_SEP="$sep" SHHIST_ROWS="$SHHIST_HOME/rows.sh" \
           SHHIST_LABEL="$SHHIST_HOME/label.zsh" SHHIST_COLS="$cols"
    if _shhist_labels_on; then
      sh "$SHHIST_ROWS" "$query"
    else
      "$SHHIST_SQLITE" -batch -noheader "$SHHIST_DB" "$list_sql"
    fi \
      | fzf ${=SHHIST_FZF_OPTS} "${mode[@]}" "$@" "${qb[@]}" \
          --prompt="$prompt" --query="$query" \
          --header="${header}${hint}" \
          --bind="${SHHIST_DELETE_KEY}:execute-silent(${del_write}; \"\$SHHIST_SQLITE\" -batch -noheader \"\$SHHIST_DB\" \"DELETE FROM frecency WHERE kind='\$SHHIST_KIND' AND path = CAST(readfile('\$SHHIST_DEL_FILE') AS TEXT);\")+reload(${reload_cmd})"
  )"
  rm -f "$tmp"

  [[ -z "$out" ]] && return 0
  # Keep only field 1 of every line (drops the display column).
  local -a lines
  lines=("${(@f)out}")
  print -rl -- "${(@)lines%%$sep*}"
}

_shhist_fzf_pick_path() {  # $1=kind $2=prompt $3=initial query (opt) $4=1 for --select-1 (opt)
  local kind="$1" prompt="$2" query="${3:-}"
  local -a extra=()
  (( ${4:-0} )) && extra+=(--select-1)

  local sel
  sel="$(_shhist_fzf_paths "$kind" "$prompt" "$query" \
    "enter: select | ${SHHIST_DELETE_KEY}: delete entry" "${extra[@]}")"
  [[ -n "$sel" ]] && print -r -- "$sel"
}

# ---------------------------------------------------------------------------
# Directory jump (fasd/z style)
# ---------------------------------------------------------------------------
#   j            -> fzf over all known dirs, frecency-ordered
#   j foo bar    -> cd to best dir matching *foo*bar* ; if nothing matches,
#                   fall into fzf pre-filtered with the query
# Stale (deleted) directories are pruned from the db on sight; inside fzf,
# $SHHIST_DELETE_KEY removes a directory on demand.
_shhist_jump() {
  local target="" line
  if (( $# == 0 )); then
    target="$(_shhist_fzf_pick_path dir 'jump> ')"
  else
    local pat="%${(j:%:)@}%"
    while IFS= read -r line; do
      if [[ -d "$line" ]]; then
        target="$line"
        break
      else
        _shhist_sql "DELETE FROM frecency WHERE kind='dir' AND path='$(_shhist_q "$line")';"
      fi
    done < <(_shhist_frecent dir "$pat")
    if [[ -z "$target" ]]; then
      target="$(_shhist_fzf_pick_path dir 'jump> ' "$*")"
    fi
  fi
  [[ -n "$target" && -d "$target" ]] && cd -- "$target"
}

# ---------------------------------------------------------------------------
# Frecent file commands (fasd style): v = edit, shf = run with sh
# ---------------------------------------------------------------------------
# Shared picker:
#   no args -> fzf over all known files, frecency-ordered
#   args    -> best file matching *foo*bar*; if nothing matches, fall into
#              fzf pre-filtered with the query
# Stale (deleted) files are pruned from the db on sight; inside fzf,
# $SHHIST_DELETE_KEY removes a file on demand. Prints the chosen path, or
# nothing if aborted.
_shhist_pick_file() {
  local target="" line
  if (( $# == 0 )); then
    target="$(_shhist_fzf_pick_path file 'file> ')"
  else
    local pat="%${(j:%:)@}%"
    while IFS= read -r line; do
      if [[ -f "$line" ]]; then
        target="$line"
        break
      else
        _shhist_sql "DELETE FROM frecency WHERE kind='file' AND path='$(_shhist_q "$line")';"
      fi
    done < <(_shhist_frecent file "$pat")
    if [[ -z "$target" ]]; then
      target="$(_shhist_fzf_pick_path file 'file> ' "$*")"
    fi
  fi
  [[ -n "$target" && -f "$target" ]] && print -r -- "$target"
}

_shhist_edit() {
  local target
  target="$(_shhist_pick_file "$@")"
  [[ -n "$target" ]] && "${EDITOR:-vim}" -- "$target"
}

_shhist_sh() {
  local target
  target="$(_shhist_pick_file "$@")"
  [[ -n "$target" ]] && sh -- "$target"
}

alias -- "${SHHIST_JUMP_CMD}=_shhist_jump"
alias -- "${SHHIST_EDIT_CMD}=_shhist_edit"
alias -- "${SHHIST_SH_CMD}=_shhist_sh"

# ---------------------------------------------------------------------------
# Ctrl+R: fzf over the sqlite command history
# ---------------------------------------------------------------------------
# Rows are "id<US>display" where display has newlines flattened to ' ⏎ '
# for fzf; on accept we fetch the ORIGINAL command by id, so multi-line
# commands round-trip intact. fzf runs with --disabled: it only draws the
# list and never filters or sorts it. Every keystroke (change event)
# re-runs match.sh, which filters and orders in SQL (see its header):
# phrase matches first, then frecency (SHHIST_HISTORY_RANK) inside each
# match tier. fzf's own fuzzy ranking cannot put `sh create_x.sh` above
# `gd create_x.sh` (".sh" fuzzy-matches "sh"), hence the custom matcher.
# ctrl-t toggles between all dirs and commands run in $PWD; the toggle
# inspects $FZF_PROMPT (requires fzf >= 0.45). Actions only reference
# environment variables ($SHHIST_MATCH, $FZF_QUERY, ...) and never embed
# SQL or user text, so fzf's action parser (parens, quotes) never sees it.
# Matching is plain text: fzf's extended syntax (^ $ ' !) is not applied.
_shhist_history_pick() {  # $1 = start scope: all | cwd
  local sep=$'\x1f'
  local start_prompt='hist:all> ' scope=all score_sql
  if [[ "${1:-all}" == cwd ]]; then
    start_prompt='hist:cwd> '
    scope=cwd
  fi
  _shhist_algo HISTORY
  _shhist_cmd_score_sql "$REPLY"
  score_sql="$REPLY"

  # --expect reports which key closed fzf as the FIRST output line, so we
  # can tell a plain Enter (insert only) apart from the run-key (insert +
  # execute). The delete-key is bound via `transform`: it deletes AND
  # reloads the list for the current query/scope WITHOUT closing fzf.
  # The row's own id is a plain integer straight out of our own SQL, so
  # it's safe to splice into the DELETE statement without escaping.
  local out key selected id cmd hint cols
  local -a qb
  _shhist_quick_binds; qb=("${reply[@]}")
  _shhist_quick_hint; hint="$REPLY"
  _shhist_list_cols; cols="$REPLY"
  out="$(
    export SHHIST_SEP="$sep" SHHIST_MATCH="$SHHIST_HOME/match.sh" \
           SHHIST_SCORE_SQL="$score_sql" SHHIST_CWD="$PWD" \
           SHHIST_COLS="$cols"
    # Opt+N labels on the first 10 rows (see label.zsh); unset = none.
    if _shhist_labels_on; then
      export SHHIST_LABEL="$SHHIST_HOME/label.zsh"
    else
      unset SHHIST_LABEL
    fi
    sh "$SHHIST_MATCH" "$LBUFFER" "$scope" \
    | fzf ${=SHHIST_FZF_OPTS} "${qb[@]}" \
        --disabled \
        --delimiter="$sep" --with-nth=2.. \
        --query="$LBUFFER" \
        --prompt="$start_prompt" \
        --expect="$SHHIST_FILE_RUN_KEY" \
        --header="enter: insert | ${SHHIST_FILE_RUN_KEY}: insert + run | ${SHHIST_DELETE_KEY}: delete | ctrl-t: toggle all dirs / current dir${hint}" \
        --bind='change:reload:sh "$SHHIST_MATCH" {q} "$FZF_PROMPT"' \
        --bind='ctrl-t:transform:if [ "$FZF_PROMPT" = "hist:all> " ]; then
            echo "change-prompt(hist:cwd> )+reload(sh \"\$SHHIST_MATCH\" \"\$FZF_QUERY\" cwd)"
          else
            echo "change-prompt(hist:all> )+reload(sh \"\$SHHIST_MATCH\" \"\$FZF_QUERY\" all)"
          fi' \
        --bind="$SHHIST_DELETE_KEY"':transform:id=$(printf "%s" {} | cut -d "$SHHIST_SEP" -f1)
            "$SHHIST_SQLITE" -batch -noheader "$SHHIST_DB" "DELETE FROM commands WHERE cmd = (SELECT cmd FROM commands WHERE id = $id);"
            echo "reload(sh \"\$SHHIST_MATCH\" \"\$FZF_QUERY\" \"\$FZF_PROMPT\")"'
  )"

  if [[ -z "$out" ]]; then
    zle redisplay
    return
  fi
  # Line 1 = the --expect key (empty string if Enter was pressed),
  # line 2 = the selected "id<sep>display" row.
  local -a lines
  lines=("${(@f)out}")
  key="${lines[1]}" selected="${lines[2]:-}"
  if [[ -z "$selected" ]]; then
    zle redisplay
    return
  fi
  id="${selected%%$'\x1f'*}"
  if [[ "$id" != <-> ]]; then
    zle redisplay
    return
  fi

  cmd="$(_shhist_sql "SELECT cmd FROM commands WHERE id = $id;")"
  if [[ -n "$cmd" ]]; then
    BUFFER="$cmd"
    CURSOR=$#BUFFER
    if [[ "$key" == "$SHHIST_FILE_RUN_KEY" ]]; then
      zle accept-line
      return
    fi
  fi
  zle redisplay
}

# Ctrl+R: start in all-dirs scope.
_shhist_history_widget() { _shhist_history_pick all }
zle -N _shhist_history_widget
bindkey "$SHHIST_BIND_HISTORY" _shhist_history_widget

# Ctrl+T: start directly in current-dir scope (ctrl-t inside toggles to all).
_shhist_history_cwd_widget() { _shhist_history_pick cwd }
zle -N _shhist_history_cwd_widget
[[ -n "$SHHIST_BIND_HISTORY_CWD" ]] && bindkey "$SHHIST_BIND_HISTORY_CWD" _shhist_history_cwd_widget

# ---------------------------------------------------------------------------
# File picker widget: insert a frecent file path at the cursor
# ---------------------------------------------------------------------------
# Works with ANY half-typed command: type `vim `, hit the key, pick a file.
# Enter inserts the path; $SHHIST_FILE_RUN_KEY inserts AND executes the
# line in one stroke. $SHHIST_DELETE_KEY deletes the highlighted file's
# frecency entry in place via fzf's execute-silent+reload (see
# _shhist_fzf_pick_path above for why: readfile() avoids splicing an
# arbitrary path into a SQL string), so fzf never closes/relaunches and
# the list doesn't jump. --expect is only needed now to tell "insert" and
# "insert + run" apart.
_shhist_file_widget() {
  local out key sel
  out="$(_shhist_fzf_paths file 'file> ' '' \
    "enter: insert | ${SHHIST_FILE_RUN_KEY}: insert + run | ${SHHIST_DELETE_KEY}: delete entry" \
    --expect="$SHHIST_FILE_RUN_KEY")"

  if [[ -z "$out" ]]; then
    zle redisplay
    return
  fi
  local -a lines
  lines=("${(@f)out}")
  key="${lines[1]}" sel="${lines[2]:-}"
  if [[ -z "$sel" ]]; then
    zle redisplay
    return
  fi
  LBUFFER+="${(q)sel}"
  if [[ "$key" == "$SHHIST_FILE_RUN_KEY" ]]; then
    zle accept-line
    return
  fi
  zle redisplay
}
zle -N _shhist_file_widget
bindkey "$SHHIST_BIND_FILE" _shhist_file_widget

# ---------------------------------------------------------------------------
# Tab on a jump/edit line: fzf-pick, Enter jumps/opens immediately
# ---------------------------------------------------------------------------
# `j youmindhub<Tab>` opens fzf over frecency-ordered dirs with the typed
# words as the initial query; Enter executes the jump right away. If the
# query narrows to a single candidate, it jumps without showing the list
# (--select-1). Same for the edit/sh commands with files. $SHHIST_DELETE_KEY
# removes the highlighted entry instead of jumping/opening. Any other
# command line falls through to whatever Tab was bound to before.
if [[ -n "$SHHIST_BIND_TAB" ]]; then
  # Capture the original Tab widget once; guard against re-sourcing
  # capturing our own widget and looping forever.
  if [[ "${${(z)$(bindkey "$SHHIST_BIND_TAB")}[2]}" != _shhist_tab_widget ]]; then
    typeset -g _SHHIST_ORIG_TAB="${${(z)$(bindkey "$SHHIST_BIND_TAB")}[2]}"
  fi

  _shhist_tab_widget() {
    local -a words
    words=(${(z)LBUFFER})
    local kind
    if [[ "${words[1]:-}" == "$SHHIST_JUMP_CMD" ]]; then
      kind=dir
    elif [[ "${words[1]:-}" == "$SHHIST_EDIT_CMD" || "${words[1]:-}" == "$SHHIST_SH_CMD" ]]; then
      kind=file
    else
      zle "${_SHHIST_ORIG_TAB:-expand-or-complete}"
      return
    fi

    local query="${(j: :)words[2,-1]}"
    local target
    target="$(_shhist_fzf_pick_path "$kind" "${words[1]}> " "$query" 1)"
    if [[ -n "$target" ]]; then
      BUFFER="${words[1]} ${(q)target}"
      zle accept-line
    else
      zle redisplay
    fi
  }
  zle -N _shhist_tab_widget
  bindkey "$SHHIST_BIND_TAB" _shhist_tab_widget
fi

# ---------------------------------------------------------------------------
# Lone ESC fix
# ---------------------------------------------------------------------------
# In the emacs keymap a bare ESC is only a Meta prefix, so zle waits
# indefinitely and the NEXT keypress gets consumed as an Alt-combo
# (reproducible in plain zsh: ESC, then 'echo hi' runs 'cho hi').
# Binding ESC itself to a no-op makes zle wait just $KEYTIMEOUT before
# dispatching it; escape sequences from the terminal (arrows, Alt keys)
# arrive within milliseconds and still match their longer bindings.
# Only applied when ESC is currently unbound -- never in vi mode.
if (( ${SHHIST_ESC_FIX:-1} )); then
  if [[ "${${(z)$(bindkey '\e')}[2]}" == undefined-key ]]; then
    _shhist_noop() { }
    zle -N _shhist_noop
    bindkey '\e' _shhist_noop
    # KEYTIMEOUT is in centiseconds (units of 10ms).
    if [[ -n "${SHHIST_ESC_TIMEOUT_MS:-}" ]]; then
      KEYTIMEOUT=$(( SHHIST_ESC_TIMEOUT_MS / 10 ))
      (( KEYTIMEOUT < 1 )) && KEYTIMEOUT=1
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Inline suggestions
# ---------------------------------------------------------------------------
# Loaded last: it wraps forward-char / forward-word & co, and must see any
# other plugin's versions of them to chain to.
source "$SHHIST_HOME/suggest.zsh"
