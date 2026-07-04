# shhist - entry point. Add to ~/.zshrc AFTER fzf keybindings and
# zsh-autosuggestions:
#
#   source ~/.config/shhist/widgets.zsh

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
_shhist_fzf_pick_path() {  # $1=kind $2=half-life $3=prompt $4=initial query (opt) $5=1 for --select-1 (opt)
  local kind="$1" halflife="$2" prompt="$3" query="${4:-}"
  local -a extra=()
  (( ${5:-0} )) && extra+=(--select-1)

  local list_sql tmp sel
  list_sql="$(_shhist_frecent_sql "$kind" "$halflife" '')"
  tmp="$(mktemp "${TMPDIR:-/tmp}/shhist_del.XXXXXX")"

  sel="$(
    "$SHHIST_SQLITE" -batch -noheader "$SHHIST_DB" "$list_sql" \
      | SHHIST_LIST_SQL="$list_sql" SHHIST_DEL_FILE="$tmp" SHHIST_KIND="$kind" \
        fzf ${=SHHIST_FZF_OPTS} --scheme=path --no-sort "${extra[@]}" \
          --prompt="$prompt" --query="$query" \
          --header="enter: select | ${SHHIST_DELETE_KEY}: delete entry" \
          --bind="${SHHIST_DELETE_KEY}:execute-silent(printf '%s' {} > \"\$SHHIST_DEL_FILE\"; \"\$SHHIST_SQLITE\" -batch -noheader \"\$SHHIST_DB\" \"DELETE FROM frecency WHERE kind='\$SHHIST_KIND' AND path = CAST(readfile('\$SHHIST_DEL_FILE') AS TEXT);\")+reload(\"\$SHHIST_SQLITE\" -batch -noheader \"\$SHHIST_DB\" \"\$SHHIST_LIST_SQL\")"
  )"
  rm -f "$tmp"

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
    target="$(_shhist_fzf_pick_path dir "$SHHIST_HALFLIFE_DIR" 'jump> ')"
  else
    local pat="%${(j:%:)@}%"
    while IFS= read -r line; do
      if [[ -d "$line" ]]; then
        target="$line"
        break
      else
        _shhist_sql "DELETE FROM frecency WHERE kind='dir' AND path='$(_shhist_q "$line")';"
      fi
    done < <(_shhist_frecent dir "$SHHIST_HALFLIFE_DIR" "$pat")
    if [[ -z "$target" ]]; then
      target="$(_shhist_fzf_pick_path dir "$SHHIST_HALFLIFE_DIR" 'jump> ' "$*")"
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
    target="$(_shhist_fzf_pick_path file "$SHHIST_HALFLIFE_FILE" 'file> ')"
  else
    local pat="%${(j:%:)@}%"
    while IFS= read -r line; do
      if [[ -f "$line" ]]; then
        target="$line"
        break
      else
        _shhist_sql "DELETE FROM frecency WHERE kind='file' AND path='$(_shhist_q "$line")';"
      fi
    done < <(_shhist_frecent file "$SHHIST_HALFLIFE_FILE" "$pat")
    if [[ -z "$target" ]]; then
      target="$(_shhist_fzf_pick_path file "$SHHIST_HALFLIFE_FILE" 'file> ' "$*")"
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
# commands round-trip intact. Matching runs on the displayed text only
# (never pass --nth here: with --with-nth active, fzf matches against the
# TRANSFORMED line, which has a single field -- --nth=2.. would match
# nothing at all). ctrl-t toggles between all dirs and commands run in
# $PWD; the toggle inspects $FZF_PROMPT (requires fzf >= 0.45).
_shhist_history_widget() {
  local sep=$'\x1f'
  local q_global="
    SELECT MAX(id), replace(cmd, char(10), ' ⏎ ')
    FROM commands GROUP BY cmd
    ORDER BY MAX(ts) DESC LIMIT $SHHIST_FZF_LIMIT;"
  local q_local="
    SELECT MAX(id), replace(cmd, char(10), ' ⏎ ')
    FROM commands WHERE dir = '$(_shhist_q "$PWD")' GROUP BY cmd
    ORDER BY MAX(ts) DESC LIMIT $SHHIST_FZF_LIMIT;"

  # --expect reports which key closed fzf as the FIRST output line, so we
  # can tell a plain Enter (insert only) apart from the run-key (insert +
  # execute). The delete-key is no longer in --expect: deleting is bound
  # via `transform`, same trick as ctrl-t's toggle below, so it deletes
  # AND reloads the currently-active scope (all/cwd) WITHOUT closing
  # fzf -- that's what used to make the list visibly jump by one line.
  # The row's own id is a plain integer straight out of our own SQL, so
  # it's safe to splice into the DELETE statement without escaping.
  local out key selected id cmd
  out="$(
    "$SHHIST_SQLITE" -batch -noheader -cmd '.timeout 300' -separator "$sep" \
        "$SHHIST_DB" "$q_global" \
    | SHHIST_SEP="$sep" SHHIST_Q_GLOBAL="$q_global" SHHIST_Q_LOCAL="$q_local" \
      fzf ${=SHHIST_FZF_OPTS} \
        --scheme=history --no-sort \
        --delimiter="$sep" --with-nth=2.. \
        --query="$LBUFFER" \
        --prompt='hist:all> ' \
        --expect="$SHHIST_FILE_RUN_KEY" \
        --header="enter: insert | ${SHHIST_FILE_RUN_KEY}: insert + run | ${SHHIST_DELETE_KEY}: delete | ctrl-t: toggle all dirs / current dir" \
        --bind='ctrl-t:transform:if [ "$FZF_PROMPT" = "hist:all> " ]; then
            echo "change-prompt(hist:cwd> )+reload(\"$SHHIST_SQLITE\" -batch -noheader -separator \"$SHHIST_SEP\" \"$SHHIST_DB\" \"$SHHIST_Q_LOCAL\")"
          else
            echo "change-prompt(hist:all> )+reload(\"$SHHIST_SQLITE\" -batch -noheader -separator \"$SHHIST_SEP\" \"$SHHIST_DB\" \"$SHHIST_Q_GLOBAL\")"
          fi' \
        --bind="$SHHIST_DELETE_KEY"':transform:id=$(printf "%s" {} | cut -d "$SHHIST_SEP" -f1)
            "$SHHIST_SQLITE" -batch -noheader "$SHHIST_DB" "DELETE FROM commands WHERE cmd = (SELECT cmd FROM commands WHERE id = $id);"
            if [ "$FZF_PROMPT" = "hist:all> " ]; then
              echo "reload(\"$SHHIST_SQLITE\" -batch -noheader -separator \"$SHHIST_SEP\" \"$SHHIST_DB\" \"$SHHIST_Q_GLOBAL\")"
            else
              echo "reload(\"$SHHIST_SQLITE\" -batch -noheader -separator \"$SHHIST_SEP\" \"$SHHIST_DB\" \"$SHHIST_Q_LOCAL\")"
            fi'
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
zle -N _shhist_history_widget
bindkey "$SHHIST_BIND_HISTORY" _shhist_history_widget

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
  local list_sql tmp out key sel
  list_sql="$(_shhist_frecent_sql file "$SHHIST_HALFLIFE_FILE" '')"
  tmp="$(mktemp "${TMPDIR:-/tmp}/shhist_del.XXXXXX")"

  out="$(
    "$SHHIST_SQLITE" -batch -noheader "$SHHIST_DB" "$list_sql" \
      | SHHIST_LIST_SQL="$list_sql" SHHIST_DEL_FILE="$tmp" \
        fzf ${=SHHIST_FZF_OPTS} --scheme=path --no-sort --prompt='file> ' \
          --expect="$SHHIST_FILE_RUN_KEY" \
          --header="enter: insert | ${SHHIST_FILE_RUN_KEY}: insert + run | ${SHHIST_DELETE_KEY}: delete entry" \
          --bind="${SHHIST_DELETE_KEY}:execute-silent(printf '%s' {} > \"\$SHHIST_DEL_FILE\"; \"\$SHHIST_SQLITE\" -batch -noheader \"\$SHHIST_DB\" \"DELETE FROM frecency WHERE kind='file' AND path = CAST(readfile('\$SHHIST_DEL_FILE') AS TEXT);\")+reload(\"\$SHHIST_SQLITE\" -batch -noheader \"\$SHHIST_DB\" \"\$SHHIST_LIST_SQL\")"
  )"
  rm -f "$tmp"

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
    local kind halflife
    if [[ "${words[1]:-}" == "$SHHIST_JUMP_CMD" ]]; then
      kind=dir; halflife=$SHHIST_HALFLIFE_DIR
    elif [[ "${words[1]:-}" == "$SHHIST_EDIT_CMD" || "${words[1]:-}" == "$SHHIST_SH_CMD" ]]; then
      kind=file; halflife=$SHHIST_HALFLIFE_FILE
    else
      zle "${_SHHIST_ORIG_TAB:-expand-or-complete}"
      return
    fi

    local query="${(j: :)words[2,-1]}"
    local target
    target="$(_shhist_fzf_pick_path "$kind" "$halflife" "${words[1]}> " "$query" 1)"
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
# zsh-autosuggestions strategy backed by sqlite
# ---------------------------------------------------------------------------
# Candidates are ranked by decayed occurrence count: every past run of a
# command contributes 0.5 ^ (age / SHHIST_HALFLIFE_CMD). Multi-line
# commands are excluded (they render badly as inline suggestions).
_zsh_autosuggest_strategy_shhist() {
  emulate -L zsh
  local prefix="$1"
  [[ -n "$prefix" ]] || return
  # Escape LIKE wildcards, then let _shhist_q handle SQL quoting.
  local like="${prefix//\\/\\\\}"
  like="${like//\%/\\%}"
  like="${like//_/\\_}"
  typeset -g suggestion
  suggestion="$(_shhist_sql "
    PRAGMA case_sensitive_like = ON;
    SELECT cmd FROM commands
    WHERE cmd LIKE '$(_shhist_q "$like")%' ESCAPE '\'
      AND instr(cmd, char(10)) = 0
    GROUP BY cmd
    ORDER BY SUM(pow(0.5, (strftime('%s','now') - ts) / CAST($SHHIST_HALFLIFE_CMD AS REAL))) DESC
    LIMIT 1;")"
}

case "${SHHIST_SUGGEST_MODE:u}" in
  A)  ZSH_AUTOSUGGEST_STRATEGY=(shhist) ;;
  AB) ZSH_AUTOSUGGEST_STRATEGY=(shhist history) ;;
  *)  ZSH_AUTOSUGGEST_STRATEGY=(history) ;;
esac
