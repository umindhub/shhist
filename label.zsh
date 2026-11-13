#!/usr/bin/env zsh
# shhist - add right-aligned Opt+1..0 labels to the first 10 rows.
# stdin : rows. History rows are "key<SEP>display"; with SHHIST_LABEL_PATHS=1
#         rows are bare paths and every row is emitted as "path<SEP>display".
# env   : SHHIST_SEP (field separator), FZF_COLUMNS / SHHIST_COLS (width)
emulate -L zsh
# Display widths below need a UTF-8 locale (rows hold CJK text and "…").
[[ "${LC_ALL:-${LC_CTYPE:-$LANG}}" == *(utf|UTF)-8* ]] || export LC_ALL=en_US.UTF-8
local sep="${SHHIST_SEP:-$'\x1f'}"
local -a labels=('⌥1' '⌥2' '⌥3' '⌥4' '⌥5' '⌥6' '⌥7' '⌥8' '⌥9' '⌥0')
# FZF_COLUMNS is the list width; minus pointer gutter (2), scrollbar (1) and
# one spare column.
local w=$(( ${FZF_COLUMNS:-${SHHIST_COLS:-80}} - 4 ))
local line key text lab pad
local -i n=0 lw=2 room
while (( n < 10 )) && IFS= read -r line; do
  (( n++ ))
  if [[ -n "${SHHIST_LABEL_PATHS:-}" ]]; then
    key="$line" text="$line"
  else
    key="${line%%$sep*}" text="${line#*$sep}"
  fi
  lab="${labels[n]}"
  room=$(( w - lw - 2 ))          # keep at least 2 spaces before the label
  if (( ${(m)#text} > room )); then
    while (( ${(m)#text} > room - 1 )); do text="${text[1,-2]}"; done
    text+='…'
  fi
  pad=$(( w - ${(m)#text} - lw ))
  print -r -- "${key}${sep}${text}${(l:$pad:: :)}${lab}"
done
# Remaining rows carry no label.
if [[ -n "${SHHIST_LABEL_PATHS:-}" ]]; then
  awk -v s="$sep" '{ print $0 s $0 }'
else
  cat
fi
