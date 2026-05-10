#!/usr/bin/env bash
# Scans battery modules for predicates that are unsafe outside the LC runtime.
# Batteries must stay within the LC predicate whitelist so they are safe to load
# in any environment — not just the managed runtime.
#
# Usage: ./scripts/check_safety.sh [--verbose]

set -euo pipefail

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

MODULES_DIR="$(cd "$(dirname "$0")/.." && pwd)/modules"
VIOLATIONS=0

# Predicates that are never permitted in battery rule bodies.
# These can cause side effects (I/O, process execution, global mutation,
# networking, or runtime modification) outside of a sandboxed environment.
DANGEROUS_PATTERNS=(
  "shell("
  "process_create("
  "process_wait("
  "process_kill("
  "nb_setval("
  "nb_getval("
  "b_setval("
  "b_getval("
  "thread_create("
  "thread_signal("
  "tcp_socket("
  "tcp_connect("
  "udp_socket("
  "open("
  "close("
  "read_term("
  "write_term("
  "assertz("
  "asserta("
  "assert("
  "retract("
  "retractall("
  "abolish("
  "load_files("
)

# Lines that are acceptable despite matching a pattern above.
# - ':- use_module(' is a compile-time directive, not a runtime call
ALLOWED_PATTERN="^[[:space:]]*:-[[:space:]]*use_module("

while IFS= read -r -d '' file; do
  rel="${file#$MODULES_DIR/}"
  line_num=0

  while IFS= read -r line; do
    ((line_num++)) || true

    # Skip comments
    [[ "$line" =~ ^[[:space:]]*% ]] && continue

    # Strip inline comments
    code="${line%%\%*}"

    # Skip allowed directives
    [[ "$code" =~ $ALLOWED_PATTERN ]] && continue

    for pattern in "${DANGEROUS_PATTERNS[@]}"; do
      if [[ "$code" == *"$pattern"* ]]; then
        echo "UNSAFE  modules/$rel:$line_num — '$pattern' is not permitted in battery rules"
        ((VIOLATIONS++)) || true
        break
      fi
    done

    $VERBOSE && echo "OK      modules/$rel:$line_num" || true

  done < "$file"

done < <(find "$MODULES_DIR" -name "*.pl" -print0)

echo ""
if [[ $VIOLATIONS -eq 0 ]]; then
  echo "Safety check passed — all batteries clean."
  exit 0
else
  echo "Safety check failed — $VIOLATIONS violation(s) found."
  echo "Batteries must only use predicates available in the LC runtime."
  exit 1
fi
