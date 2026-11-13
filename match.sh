#!/bin/sh
# shhist - history matcher for Ctrl+R / Ctrl+T. Prints "id<SEP>display" rows,
# best first. fzf only draws the list; every keystroke re-runs this script.
#
# usage: match.sh QUERY SCOPE
#   SCOPE: all | cwd | an fzf prompt (anything containing "cwd" = current dir)
# env:   SHHIST_SQLITE SHHIST_DB SHHIST_SEP SHHIST_SCORE_SQL SHHIST_CWD
#        SHHIST_FZF_LIMIT SHHIST_LABEL (optional, label.zsh path)
#
# Words are separated by spaces, case-insensitive. A command must contain
# every word (each as a substring, or, as a last resort, as a fuzzy
# subsequence). Order: match tier first, frecency score inside a tier.
#   0  command starts with the whole query ("sh create" -> "sh create_x.sh")
#   1  command contains the whole query as one phrase
#   2  all words appear, in the typed order
#   3  all words appear, in any order
#   4  every word matches fuzzily (characters in order, gaps allowed)

q="$1"

# Build one SQL fragment. $1 = where | tier.
frag() {
  Q="$q" MODE="$1" LC_ALL=C awk -v qt="'" -v bs='\\' '
    function sq(s) { gsub(qt, qt qt, s); return s }
    # Escape LIKE wildcards (ESCAPE char is a backslash).
    function le(s,   i, c, o) {
      o = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == bs || c == "%" || c == "_") o = o bs
        o = o c
      }
      return o
    }
    # Fuzzy pattern: s -> %s%h%. Words with non-ASCII bytes stay substrings.
    function fuzzy(s,   i, o, ascii) {
      ascii = 1
      for (i = 1; i <= length(s); i++)
        if (!(substr(s, i, 1) in ord)) ascii = 0
      if (!ascii) return "%" le(s) "%"
      o = "%"
      for (i = 1; i <= length(s); i++) o = o le(substr(s, i, 1)) "%"
      return o
    }
    function like(pat) { return "cmd LIKE " qt sq(pat) qt " ESCAPE " qt bs qt }
    function has(s)    { return "instr(lower(cmd), " qt sq(s) qt ")" }
    BEGIN {
      for (i = 1; i <= 127; i++) ord[sprintf("%c", i)] = i
      mode = ENVIRON["MODE"]
      q = tolower(ENVIRON["Q"])
      gsub(/[ \t\r\n]+/, " ", q); sub(/^ /, "", q); sub(/ $/, "", q)
      if (q == "") { print (mode == "where" ? "1" : "0.0"); exit }
      n = split(q, w, " ")

      if (mode == "where") {
        out = ""
        for (i = 1; i <= n; i++) out = out (i > 1 ? " AND " : "") like(fuzzy(w[i]))
        print out
        exit
      }

      t = "CASE WHEN " has(q) " = 1 THEN 0 WHEN " has(q) " > 0 THEN 1"
      if (n > 1) {
        inorder = "%"; all = ""
        for (i = 1; i <= n; i++) {
          inorder = inorder le(w[i]) "%"
          all = all (i > 1 ? " AND " : "") has(w[i]) " > 0"
        }
        t = t " WHEN " like(inorder) " THEN 2 WHEN " all " THEN 3"
      }
      print t " ELSE 4 END"
    }'
}

where="$(frag where)"
tier="$(frag tier)"

scope="1"
case "${2:-all}" in
  *cwd*) scope="dir = '$(printf '%s' "$SHHIST_CWD" | sed "s/'/''/g")'" ;;
esac

sql="
  SELECT MAX(id), replace(cmd, char(10), ' ⏎ ')
  FROM commands
  WHERE $scope AND $where
  GROUP BY cmd
  ORDER BY $tier, ${SHHIST_SCORE_SQL:-MAX(ts)} DESC, MAX(ts) DESC
  LIMIT ${SHHIST_FZF_LIMIT:-20000};"

run() {
  "$SHHIST_SQLITE" -batch -noheader -cmd '.timeout 300' \
    -separator "$SHHIST_SEP" "$SHHIST_DB" "$sql"
}

# Optional Opt+1..0 labels on the first 10 rows (see label.zsh).
if [ -n "$SHHIST_LABEL" ]; then
  run | zsh -f "$SHHIST_LABEL"
else
  run
fi
