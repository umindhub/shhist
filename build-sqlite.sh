#!/usr/bin/env bash
# build-sqlite.sh -- build SQLite from the official amalgamation and install it.
#
# shhist needs a sqlite3 with math functions (pow, log2): SQLite >= 3.35 built
# with SQLITE_ENABLE_MATH_FUNCTIONS. Prebuilt binaries from sqlite.org need a
# newer glibc than old distros (e.g. CentOS 8) have, so build from source here.
#
# Usage:  ./build-sqlite.sh [-y]
#   -y                assume "yes" at the confirmation prompt
# Env overrides:
#   PREFIX=/usr/local install prefix (binary goes to $PREFIX/bin)
#   SQLITE_URL=...    custom download URL (e.g. a mirror)
#   FORCE=1           rebuild even if a working sqlite3 is already installed

set -euo pipefail

SQLITE_VERSION_NUM="3540100"   # 3.54.1
SQLITE_YEAR="2026"             # sqlite.org puts each release under its year
SQLITE_VERSION_STR="3.54.1"
MIN_VERSION_NUM=3035000        # 3.35.0, first release with math functions
PREFIX="${PREFIX:-/usr/local}"
SQLITE_URL="${SQLITE_URL:-https://sqlite.org/${SQLITE_YEAR}/sqlite-amalgamation-${SQLITE_VERSION_NUM}.zip}"
ASSUME_YES=0
[[ "${1:-}" == "-y" ]] && ASSUME_YES=1

info() { printf '\033[32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31mx\033[0m %s\n' "$*" >&2; exit 1; }

# "3.26.0" -> 3026000 (major*1e6 + minor*1e3 + patch) for numeric comparison.
ver_to_num() {
  local IFS=.
  local -a p=($1)
  echo $(( ${p[0]:-0} * 1000000 + ${p[1]:-0} * 1000 + ${p[2]:-0} ))
}

# Run a command as root; fall back to sudo when not root.
run_priv() {
  if [[ $EUID -eq 0 ]]; then "$@"
  elif command -v sudo >/dev/null 2>&1; then sudo "$@"
  else die "need root privileges for: $* (run as root or install sudo)"
  fi
}

# --- 1. Inspect the current sqlite3 ----------------------------------------
existing="$(command -v sqlite3 2>/dev/null || true)"
cur_ver=""
if [[ -n "$existing" ]]; then
  # A binary that cannot run (e.g. glibc mismatch) yields an empty version.
  cur_ver="$("$existing" --version 2>/dev/null | awk '{print $1}' || true)"

  if [[ -z "$cur_ver" ]]; then
    warn "found $existing but it cannot run (broken binary?)"
  else
    info "found sqlite3 $cur_ver at $existing"
    # Version >= 3.35 is necessary but not sufficient: the build must also
    # enable math functions, so test pow() directly.
    if (( $(ver_to_num "$cur_ver") >= MIN_VERSION_NUM )) \
       && "$existing" :memory: 'SELECT pow(2,10), log2(8);' >/dev/null 2>&1 \
       && [[ "${FORCE:-0}" != "1" ]]; then
      info "already has math functions -- nothing to do (FORCE=1 to rebuild)"
      exit 0
    fi
    warn "sqlite3 $cur_ver is too old or lacks math functions (pow/log2)"
  fi

  # --- 2. Confirm before replacing ------------------------------------------
  target="$PREFIX/bin/sqlite3"
  echo
  echo "About to build and install SQLite $SQLITE_VERSION_STR to $target."
  if [[ "$existing" == "$target" ]]; then
    echo "The current $existing will be REMOVED and replaced."
  else
    echo "The current $existing is left untouched (e.g. package-managed);"
    echo "the new binary comes first in PATH and shadows it."
  fi
  if (( ASSUME_YES == 0 )); then
    { : < /dev/tty; } 2>/dev/null || die "no terminal for confirmation; re-run with -y"
    read -r -p "Continue? [y/N] " ans < /dev/tty
    [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]] || die "aborted by user"
  fi
else
  info "sqlite3 not installed -- starting install"
fi

# --- 3. Check build dependencies -------------------------------------------
command -v gcc   >/dev/null 2>&1 || die "gcc not found -- install it (dnf install -y gcc)"
command -v unzip >/dev/null 2>&1 || die "unzip not found -- install it (dnf install -y unzip)"
if   command -v curl >/dev/null 2>&1; then dl() { curl -fL --retry 3 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then dl() { wget -O "$2" "$1"; }
else die "neither curl nor wget found"
fi

# --- 4. Download, build, self-test -----------------------------------------
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT   # always clean up the build directory

info "downloading $SQLITE_URL"
dl "$SQLITE_URL" "$work/sqlite.zip" || die "download failed (set SQLITE_URL to use a mirror)"
unzip -q -o "$work/sqlite.zip" -d "$work"
src="$(dirname "$(find "$work" -name sqlite3.c | head -n1)")"
[[ -f "$src/shell.c" && -f "$src/sqlite3.c" ]] || die "sqlite3.c / shell.c not found in the archive"

info "compiling (this takes about a minute)"
gcc -O2 -DSQLITE_ENABLE_MATH_FUNCTIONS -DSQLITE_THREADSAFE=1 \
    "$src/shell.c" "$src/sqlite3.c" -o "$work/sqlite3" -lpthread -ldl -lm

# Verify the fresh binary before it replaces anything.
out="$("$work/sqlite3" -batch -noheader :memory: 'SELECT pow(2,10), log2(8);')" \
  || die "self-test failed: built binary cannot run"
[[ "$out" == "1024.0|3.0" ]] || die "self-test failed: unexpected output '$out'"
info "self-test passed ($("$work/sqlite3" --version | awk '{print $1}'))"

# --- 5. Install -------------------------------------------------------------
run_priv mkdir -p "$PREFIX/bin"
# Remove first so a running/old binary is never overwritten in place.
[[ -e "$PREFIX/bin/sqlite3" ]] && run_priv rm -f "$PREFIX/bin/sqlite3"
run_priv install -m 755 "$work/sqlite3" "$PREFIX/bin/sqlite3"

hash -r 2>/dev/null || true
info "installed: $PREFIX/bin/sqlite3"
echo "Run 'hash -r' in your current shell, then check: sqlite3 --version; which -a sqlite3"
