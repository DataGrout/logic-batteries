#!/usr/bin/env bash
# Flags battery rule files that call predicates unavailable in one of the four
# places a battery has to run: SWI-Prolog standalone, Scryer standalone, and a
# a restricted host on either engine.
#
# Two causes, reported by name because the fixes differ:
#
#   swi-only       Scryer has no equivalent, so a shim is the only option.
#   needs-library  Scryer has it, but in a library a battery cannot import for
#                  itself (library(between), library(pairs)). A battery may only
#                  call what is available without a use_module line of its own.
#
# Either way the battery-side answer is the core battery's core_* equivalent:
# one spelling that works on both engines.
#
# Measured against SWI-Prolog 9.2 and Scryer 0.10.0, September 2026, by calling
# each predicate with valid arguments and watching for existence_error —
# current_predicate/1 is false for builtins and cannot answer this question.
#
# The check is a ratchet: files listed in scripts/portability_baseline.txt are
# known offenders from before the rule existed. They are reported as LEGACY and
# do not fail the check; new files, and any file removed from the baseline, do.
#
# Usage: ./scripts/check_portability.sh [--verbose]

set -euo pipefail

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULES_DIR="$ROOT/modules"
BASELINE="$ROOT/scripts/portability_baseline.txt"

# name|cause|replacement
NON_PORTABLE=(
  "msort|swi-only|core_msort/2"
  "max_list|swi-only|core_max_list/2"
  "min_list|swi-only|core_min_list/2"
  "max_member|swi-only|core_argmax/2 over Key-Value pairs"
  "min_member|swi-only|core_argmin/2 over Key-Value pairs"
  "last|swi-only|core_last/2"
  "include|swi-only|core_include/3"
  "exclude|swi-only|core_exclude/3"
  "partition|swi-only|core_include/3 plus core_exclude/3"
  "forall|swi-only|core_forall/2"
  "aggregate_all|swi-only|findall/3 plus length/2 or core_max_list/2"
  "subtract|swi-only|core_subtract/3"
  "flatten|swi-only|core_flatten/2"
  "sumlist|swi-only|sum_list/2"
  "atom_string|swi-only|atom_codes/2"
  "string_concat|swi-only|atom_concat/3"
  "string_to_atom|swi-only|atom_codes/2"
  "split_string|swi-only|atom_codes/2 and a hand-written splitter"
  "transpose_pairs|swi-only|core_zip/3 over swapped pairs"
  "predsort|swi-only|core_msort/2 over Key-Value pairs"
  "group_pairs_by_key|needs-library|core_group_pairs/2"
  "between|needs-library|core_between/3"
  "numlist|needs-library|core_numlist/3"
  "pairs_keys|needs-library|core_keys/2"
  "pairs_values|needs-library|core_values/2"
  "pairs_keys_values|needs-library|core_zip/3"
  "nb_setval|no-global-state|pass state as an argument"
  "nb_getval|no-global-state|pass state as an argument"
  "succ_or_zero|swi-only|arithmetic"
)

describe_cause() {
  case "$1" in
    swi-only)       echo "absent from Scryer" ;;
    needs-library)  echo "on Scryer only via a library a battery cannot import" ;;
    no-global-state) echo "global mutable state is not permitted in batteries" ;;
    *)              echo "$1" ;;
  esac
}

VIOLATIONS=0
LEGACY=0

report() {  # level file line message
  echo "$1  $2:$3 — $4"
}

while IFS= read -r -d '' file; do
  rel="${file#$ROOT/}"
  # The core battery is where the shims live; it is allowed to name them.
  [[ "$rel" == modules/core/* ]] && continue

  in_baseline=false
  if [[ -f "$BASELINE" ]] && grep -qxF "$rel" "$BASELINE"; then in_baseline=true; fi
  level="UNSAFE"; $in_baseline && level="LEGACY"

  file_hits=0
  line_num=0
  while IFS= read -r line; do
    ((line_num++)) || true
    [[ "$line" =~ ^[[:space:]]*% ]] && continue
    code="${line%%\%*}"

    # A numeric literal on the LEFT of is/2 inside a clause body miscompiles on
    # Scryer 0.10 (`0 is X mod 2` succeeds for X = 3) when the goal is the first
    # in the body. Top-level queries are unaffected, which is why it hides.
    if [[ "$code" =~ (^|[^A-Za-z0-9_.])-?[0-9]+(\.[0-9]+)?[[:space:]]+is[[:space:]] ]]; then
      report "$level" "$rel" "$line_num" "numeric literal on the left of is/2 miscompiles on Scryer 0.10; write Expr =:= N"
      ((file_hits++)) || true
    fi

    # sort/4 (sort(Key, Order, List, Sorted)) is SWI-only.
    if [[ "$code" =~ (^|[^A-Za-z0-9_])sort\([0-9] ]]; then
      report "$level" "$rel" "$line_num" "sort/4 is absent from Scryer; use core_keysort/2 or core_msort/2 over Key-Value pairs"
      ((file_hits++)) || true
    fi

    for entry in "${NON_PORTABLE[@]}"; do
      name="${entry%%|*}"; rest="${entry#*|}"
      cause="${rest%%|*}"; fix="${rest#*|}"
      # A call: the bare name followed by '(' and not preceded by an identifier
      # character, so my_last( and core_include( do not match.
      if [[ "$code" =~ (^|[^A-Za-z0-9_])${name}\( ]]; then
        report "$level" "$rel" "$line_num" "'$name(' is $(describe_cause "$cause"); use $fix"
        ((file_hits++)) || true
      fi
    done
  done < "$file"

  if (( file_hits > 0 )); then
    if $in_baseline; then ((LEGACY++)) || true; else ((VIOLATIONS++)) || true; fi
  elif $in_baseline; then
    echo "STALE   $rel is in the baseline but is clean — remove it from scripts/portability_baseline.txt"
    ((VIOLATIONS++)) || true
  fi
  $VERBOSE && echo "OK      $rel" || true
done < <(find "$MODULES_DIR" -name "*.pl" -print0 | sort -z)

echo ""
if (( VIOLATIONS == 0 )); then
  echo "Portability check passed — $LEGACY legacy file(s) still on the baseline."
  exit 0
else
  echo "Portability check failed — $VIOLATIONS file(s) outside the baseline use unavailable predicates."
  echo "Use the core battery's core_* helpers or the portable base (see modules/core/core/README.md)."
  exit 1
fi
