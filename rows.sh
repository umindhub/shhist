#!/bin/sh
# shhist - rows for the path pickers (j / v / shf / Tab / Ctrl+G).
# usage: rows.sh QUERY
# env:   SHHIST_SQLITE SHHIST_DB SHHIST_LIST_SQL SHHIST_LABEL SHHIST_SEP
#
# Lists the frecency paths, filters them with fzf's own fuzzy matcher (same
# scheme as before) and labels the first 10 survivors, so the labels always
# match what the picker shows. Output rows: "path<SEP>display".
list() { "$SHHIST_SQLITE" -batch -noheader "$SHHIST_DB" "$SHHIST_LIST_SQL"; }

if [ -n "$1" ]; then
  list | fzf --filter="$1" --scheme=path --no-sort
else
  list
fi | SHHIST_LABEL_PATHS=1 zsh -f "$SHHIST_LABEL"
