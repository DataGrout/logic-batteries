#!/usr/bin/env bash
# Runs each smoke spec in test/scryer/*.smoke on scryer-prolog.
#
# A spec is a plain text file: battery rule-file paths (relative to the repo
# root) one per line, then a line '---', then Prolog facts and a smoke/0 goal
# that writes 'smoke_ok' as its last line on success and halts. The script
# concatenates the batteries and the facts into one file — the same shape a
# cell install produces — stripping the batteries' directives (module headers,
# use_module, dynamic) the way an install does; the common dynamics are
# declared once in the header so later clause blocks are not redefinitions.
#
# Usage: ./scripts/scryer_smoke.sh [spec ...]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRYER="${SCRYER:-$(command -v scryer-prolog || echo "$HOME/.cargo/bin/scryer-prolog")}"
if [[ ! -x "$SCRYER" ]]; then
  echo "scryer-prolog not found (set SCRYER=/path/to/scryer-prolog)"; exit 2
fi

# Drop every directive from a battery file — one-liners and the multi-line
# `:- module(name, [ ... ]).` header alike — which is what a cell install does.
strip_directives() {
  awk '
    skip { if ($0 ~ /\.[ \t]*$/) skip = 0; next }
    /^:-/ { if ($0 !~ /\.[ \t]*$/) skip = 1; next }
    { print }
  ' "$1"
}

specs=("$@")
if (( ${#specs[@]} == 0 )); then
  specs=("$ROOT"/test/scryer/*.smoke)
fi

FAIL=0
for spec in "${specs[@]}"; do
  name="$(basename "$spec" .smoke)"
  tmp="$(mktemp -t scryer_smoke_XXXXXX).pl"
  {
    printf ':- use_module(library(lists)).\n'
    printf ':- dynamic(relation/3).\n:- dynamic(attribute/3).\n:- dynamic(metric/3).\n:- dynamic(entity/1).\n'
    printf ':- dynamic(assign_reject/2).\n:- dynamic(assign_reject_pair/4).\n:- dynamic(assign_cost/3).\n'
    in_facts=false
    while IFS= read -r line || [[ -n "$line" ]]; do
      if $in_facts; then
        printf '%s\n' "$line"
      elif [[ "$line" == "---" ]]; then
        in_facts=true
      elif [[ -n "$line" && ! "$line" =~ ^# ]]; then
        strip_directives "$ROOT/$line"
      fi
    done < "$spec"
  } > "$tmp"

  out="$("$SCRYER" -g smoke "$tmp" 2>&1 < /dev/null | grep -v '^% Warning' || true)"
  if [[ "$(printf '%s\n' "$out" | tail -n 1)" == "smoke_ok" ]]; then
    echo "PASS    $name"
  else
    echo "FAIL    $name"
    printf '%s\n' "$out" | sed 's/^/        /'
    ((FAIL++)) || true
  fi
  rm -f "$tmp"
done

echo ""
if (( FAIL == 0 )); then echo "Scryer smoke passed."; else echo "Scryer smoke failed — $FAIL spec(s)."; exit 1; fi
