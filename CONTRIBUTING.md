# Contributing Batteries

## Authoring a battery

A battery is a directory under `modules/<category>/<id>/` containing:

1. **Rule file(s)** (`<id>.pl`) opening with the manifest header and clauses:

   ```prolog
   %% Battery: my-battery v1.0.0
   %% Requires: (nothing)          % or a comma-separated list of battery ids
   %% Exports: my_pred/2, other_pred/3

   :- dynamic(my_input_fact/2).   % declare every INPUT predicate dynamic

   battery_module('my-battery', '1.0.0', auto).
   battery_export('my-battery', 'my_pred/2',
       'my_pred(X, Y) — one-line doc shown by batteries.describe and the CLI').
   ```

   - `battery_module/3` and `battery_export/3` are the manifest ABI —
     `batteries.describe` reads the export doc strings as authoritative
     documentation, so write them for the person (or agent) who will call
     your predicates.
   - Declare your battery's **input predicates** `:- dynamic(...)` so
     standalone (consult) users can `assertz` their facts after loading.
     DataGrout strips directives at install time, so cells are unaffected.
   - Prefer pure ISO Prolog. Batteries that avoid SWI-only constructs run on
     both engines, including ISO-pinned cells.
   - **Never rely on directives for cell behavior** — the installer strips
     ALL `:- ...` directives at cell install, by design (directives are
     arbitrary goal execution at load time; stripping them is a security
     boundary). In particular, do not rely on `:- table` for termination:
     both engines support tabling (SWI natively, Scryer via
     `library(tabling)`), but the directive is stripped so it never reaches
     cells — write visited-set walks for paths and BFS fixpoints for
     closures instead.
     `make lint` rejects `table`, `initialization`, and `set_prolog_flag`
     directives outright.

2. **A README** with an install snippet, an exported-predicates table, a
   worked example, and honest notes on semantics and scope.

3. **Tests** in `test/<category>/<id>_test.pl` (plunit), wired into
   `test/run_all.pl`. Assert via file-level setup predicates, never inside
   test bodies (plunit compiles bodies into a per-unit module).

4. **A registry entry** in `modules/<category>/registry.json` — id, version,
   title, description, tags, predicates, `rules_url`, `readme_url`. Add a
   `license` field only if your battery's license differs from the repository
   default.

## Portability: two engines

Batteries run on SWI-Prolog and on Scryer. Directives do not survive
installation, so a battery may only call what is available without a
`use_module` line of its own. Write to that intersection:

| Portable | Absent from Scryer | On Scryer only via a library |
|---|---|---|
| `sort/2`, `keysort/2`, `sum_list/2`, `nth0/3`, `nth1/3`, `maplist/2..5`, `reverse/2`, `length/2`, `member/2`, `memberchk/2`, `append/3`, `select/3`, `permutation/2`, `list_to_set/2`, `foldl/4`, `findall/3`, `\+`, if-then-else, arithmetic (`max`, `min`, `abs`, `//`, `mod`, `sqrt`, `**`) | `msort/2`, `sort/4`, `max_list/2`, `min_list/2`, `max_member/2`, `min_member/2`, `last/2`, `include/3`, `exclude/3`, `partition/4`, `forall/2`, `aggregate_all/3`, `subtract/3`, `flatten/2`, `sumlist/2`, `predsort/3` | `between/3`, `numlist/3`, `pairs_keys/2`, `pairs_values/2`, `pairs_keys_values/3`, `group_pairs_by_key/2` — all in `library(between)` or `library(pairs)` |

The two right-hand columns are different problems. The middle column needs a
shim because Scryer has no equivalent at all. The right column exists on both
engines, but sits in a library a battery cannot import for itself. Either way,
use the `core` battery's `core_*` equivalent
(`modules/core/core/README.md`) rather than redefining it under your own prefix.

Measured by calling each predicate with valid arguments and watching for
`existence_error`. `current_predicate/1` is false for builtins, so it cannot
answer this question — `keysort/2`, for one, is a Scryer builtin that
`current_predicate/1` reports as absent.

`core_include/3`, `core_exclude/3`, `core_foldl/4` and `core_forall/2`
meta-call their goal argument. A host that vets goals before running them may
decline a higher-order call it cannot inspect, so prefer a first-order
formulation in a battery meant to run anywhere. `make lint` runs
`scripts/check_portability.sh` and fails on new files that reach outside the
subset; `scripts/portability_baseline.txt` records the files that predate the
rule and only ever shrinks.

One Scryer behaviour that IS a bug (0.10.0): a numeric literal on the left of
`is/2` inside a clause body miscompiles, so `even(X) :- 0 is X mod 2.` succeeds
for `X = 3` while the same goal fails at the top level. Write `X mod 2 =:= 0`,
or bind a variable first. The portability check flags the literal form.

Two Scryer habits that look like bugs but are not: clauses of one predicate
must be contiguous within a file or the later block silently replaces the
earlier one, so keep fact blocks grouped when you build a flat test file; and
an existence error under `-g goal` drops Scryer into its toplevel, which looks
like a hang. `make scryer-smoke` runs the flat-file smoke specs in
`test/scryer/`; add one for any battery whose behaviour depends on engine
details.

Run `make lint` and the full test suite before opening a PR. Batteries must
stay within the predicate whitelist provided by the LC runtime — no process
execution, file I/O, networking, global mutable state, or runtime fact
modification. This keeps batteries safe to load in any environment.

## Why batteries aren't module libraries

A fair question from anyone fluent in Prolog's module systems: why do
batteries ship as flat clause files with `battery_module`/`battery_export`
manifest facts and predicate-name prefixes, instead of `:- module(...)`
libraries with proper export lists?

Because the primary deployment target can't use modules — the flat form is a
design decision, not an oversight:

1. **Cells install by assertion into a shared namespace.** A logic cell
   receives a battery clause by clause (`assertz`), not by consulting a
   file, and every directive is stripped at install. A `:- module` header
   wouldn't survive the pipeline.
2. **Composition through shared facts is the point.** Batteries reason over
   facts the user asserts into the same namespace, and over each other's
   predicates (`prob-loot` over `loot-tables`, `prob-decide` over
   `prob-core-iso`). Module encapsulation would break exactly this — a
   module-scoped predicate can't see user facts without meta-qualification
   on every call.
3. **Modules are the least portable part of Prolog.** The ISO module
   standard (13211-2) was never adopted — engines use Quintus-descended or
   homegrown module systems instead, and SWI's and Scryer's differ in real
   ways. Plain ISO clauses with prefix-based namespacing mean the same
   thing on every engine.
4. **Manifests as facts are queryable.** `battery_export/3` doc strings are
   read by unification (`batteries.describe`, the CLI) — Prolog-native
   introspection rather than a parallel metadata format.

The cost is honest: standalone (consult) users get a battery's internal
helpers in their namespace too, not just its public predicates. The
`<battery>_`-prefix convention keeps that tolerable. If you're writing a
library for standalone use only, a real module is the better tool — batteries
are written for the cell substrate first, with bare consult as the secondary
path.

## Licensing of contributions

This repository uses tiered licensing (see [README → License](./README.md#license)).
So the project can keep that structure coherent — and adjust it in the
future — contributions are accepted under the following terms:

1. **Developer Certificate of Origin.** Every commit must be signed off
   (`git commit -s`), certifying the [DCO](https://developercertificate.org/):
   you wrote the contribution or otherwise have the right to submit it.

2. **Contribution license grant.** By submitting a contribution, you license
   it to the project under the **Apache License 2.0**, and you grant the
   maintainer (DataGrout AI) a perpetual, worldwide, irrevocable right to
   distribute your contribution under the repository's license(s) — currently
   Elastic License 2.0 for content batteries, Apache-2.0 for designated core
   modules, and MIT for the CLI — **including under future license changes**
   to the repository or the module your contribution lands in.

In plain terms: you keep your copyright, your contribution is permissively
licensed *inbound*, and the project retains the freedom to manage *outbound*
licensing coherently — including relicensing decisions like the ones that
produced the current tiers.

If you are contributing on behalf of an employer, ensure you have the
authority to agree to these terms.
