# Changelog

## 2026-09-10

### Registry

`make registry` now normalises the category `registry.json` files as well as
merging them. `installs` is gone — it was a static `0` on every entry that
nothing incremented, and it rendered as "0 installs" everywhere. `tests_file`
is filled from `test/<category>/<id>_test.pl` so a reader can see which
batteries are tested (all 46 are). A category's `updated_at` is bumped when its
module list changes; `business` had said 2026-05-11 through the addition of
`duty` and `rostering`. `make check-registry` fails on any stale file and lists
the batteries with no `license` (44 of 46 at the time of writing) rather than
guessing one for them.

### Modules

Writing each README's facts table against the source turned up places where a
battery did not do what its documentation said. Each is a patch release.

**ai-director** v1.0.1 — `spawn_zone` is enforced; the clause that read it succeeded whether or not the zone matched.

**progression** v1.0.1 — unlocks accept `requires_level` / `requires_class` alongside `unlock_at_level` / `unlock_requires_class`. The README had always used the former; the code read only the latter. The `prestige` entity is excluded from the alias so it is not enumerated as an unlock.

**faction** v1.0.1 — negative standings mirror the positive thresholds: at or below `unfriendly_threshold` is `unfriendly`, at or below `hostile_threshold` is `hostile`. Scores between the two negative thresholds had matched neither rule and fallen through to `neutral`; small negative scores are now `neutral` rather than `unfriendly`.

**prob-loot** v1.0.2 — `drop_occurs` weights are 0.70 / 0.30 / 0.10 / 0.03 / 0.01, the same scale as `loot-tables` and `drop_probability`. They were 0.90 / 0.65 / 0.35 / 0.10 / 0.15, which ranked legendary above epic.

**permissions** v1.0.1 and **taxonomy** v1.0.1 — `role_grants`, `isa`, `inherits_property` and `depth_in_hierarchy` walk with a visited set; a cycle in `inherits_from` or `is_a` terminates instead of looping.

**loot-tables** v1.0.1 — `eligible_loot/3` takes a player context, so `player_level_gte` and `player_has` conditions can hold. Through `eligible_loot/2`, whose context is `world`, they never could.

**dungeon** v1.0.1 — `dungeon_path` returns maximal walks rather than every prefix (the first answer was `[From]`). `room_cleared/3` and `dungeon_complete` read the per-dungeon key `<player>_<dungeon>` the source comments had promised; the fixed `_dungeon` suffix and `cleared_room` still count as per-player shapes.

**puzzle-fsm** v1.0.1 — a puzzle with a `player` attribute reads that player's `has_item` for item gates, so `inventory` composes without mirroring items onto the puzzle. The unused `requires_state` check was removed.

**risk-assessment** v1.0.1 — the declared dependency on `combat` was removed; nothing called it. Gains a test file.

**prob-detection** v1.0.1 — `detection_probability` starts from the same tier weights as the annotated `detected/2` clauses, disguise included, instead of `perception / 10 × 1.3`. `environmental_detection_factor` no longer uses a yall lambda.

**economy** v1.0.1 — a `<material>_qty` attribute on the player is read as quantity held, ahead of counting duplicate `has_material` facts.

### Documentation

Every battery README now carries a `## Facts this battery reads` section — attributes and relations it looks up, what they sit on, their values, what they mean — directly under the exported predicates. The 22 READMEs written as Tether/Lua callbacks show setup as plain facts and querying as bare goals, with one short Tether block each.

### Tooling

- `make check-readme` (`scripts/check_readme_vocab.py --check`) fails when a name a battery's clauses read is missing from its README's facts section; `--draft <id>` prints a starting table. Part of `make check`; CONTRIBUTING asks for the table.

## 2026-09-06

### Modules

**core** v1.0.0 (new category `core`) — the one copy of the list and aggregate helpers batteries kept redefining under their own prefixes. Pure ISO, every predicate prefixed `core_` so nothing shadows an engine library: `core_max_list/2`, `core_min_list/2`, `core_argmax/2`, `core_argmin/2`, `core_mean/2`, `core_median/2`, `core_clamp/4`, `core_last/2`, `core_take/3`, `core_drop/3`, stable duplicate-keeping `core_msort/2` and `core_keysort/2`, `core_group_pairs/2`, `core_unique/2`, `core_between/3`, `core_numlist/3`, `core_subtract/3`, `core_flatten/2`, `core_zip/3`, `core_keys/2`, `core_values/2`, and the higher-order `core_include/3`, `core_exclude/3`, `core_foldl/4`, `core_forall/2`. Install it like any battery, or consult it first when running standalone; the higher-order four meta-call their goal and are documented as such.

### Tooling

- `make lint` now also runs `scripts/check_portability.sh`, which flags any battery outside `core` that calls a predicate Scryer does not have (`msort`, `max_list`, `min_list`, `last`, `include`, `exclude`, `forall`, `aggregate_all`, `subtract`, `sumlist`, `predsort`, `sort/4`) or has only in a library a battery cannot import (`between`, `numlist`, the pairs family, `group_pairs_by_key`), and the `N is Expr` literal-left form that miscompiles on Scryer 0.10. It is a ratchet: `scripts/portability_baseline.txt` lists the files that predate the rule, reported as LEGACY; a clean file still on the list fails the check so the list only shrinks.
- `make scryer-smoke` runs `scripts/scryer_smoke.sh` over `test/scryer/*.smoke`: each spec names battery files and a fact set with a `smoke/0` goal, concatenated into a single load, executed on scryer-prolog. Specs for `core`, `duty`, `assign`, and `rostering`.
- CONTRIBUTING gains the portable-subset table and the two-engine test rule.

## 2026-09-05

### Modules

**duty** v1.0.0 (business) — duty-time and readiness rules for people and the equipment they use. Duty conflicts and unavailability windows over half-open intervals (same `start`/`end` convention as `temporal`, so the two compose); policy limits (`max_duty`, `min_rest`, `rolling_window`, `rolling_limit`) resolved worker → role → global `duty_policy`; rest measured from committed duty only; rolling limits that clip periods straddling the window edge; qualification currency with optional expiry; role gating. `fit_for_duty/4` is the verdict, `unfit_reason/5` yields one term per failing check, `available_staff/4` enumerates, and `policy_gap/2` exposes unconfigured limits so a caller who needs a complete policy can refuse rather than pass vacuously. Pure ISO; no directives beyond `dynamic`.

**assign** v1.0.0 (reasoning) — budgeted constraint search over cell facts. Variables carry a `domain` attribute, `distinct` relations form all-different groups, and three open hook predicates (`assign_reject/2`, `assign_reject_pair/4`, `assign_cost/3`) constrain and price assignments — their bodies can call any other battery, which is how `assign` composes with `duty` to fill a roster. Depth-first over an explicit agenda so the node budget is a true global bound, minimum-remaining-values ordering, forward checking, cheapest-first value order, and branch and bound in `assign_best/3`. Results are explicit terms: `solution/2`, `unsat/1`, `unsat(empty_domain(V))`, `budget_exhausted/1`, `best/4`. `assign_violations/2` audits an assignment made elsewhere. Pure ISO; no `call/N`.

**rostering** v1.0.0 (business, requires duty and assign) — the roster layer: seat requirements per shift, coverage and gaps, violations that surface every `duty` unfit reason plus `clash/1` and `role_not_needed/1`, a compatibility test between two shifts for one worker (overlap or rest below `min_rest`), candidates filtered through `fit_for_duty/4`, a weight-free ranking key compared by standard order (preference, headroom, load, seniority), greedy `fill_shift/3` and `propose_roster/3` that honour incompatibility between their own picks and report unfilled seats, `replacement_for/3`, `swap_valid/4`, clipped `assigned_load/4` and `load_imbalance/5`, and `roster_model/2`, which emits the `assign` model for open seats so exact fill is one hook and one `assign_solve/2` away. Pure ISO; reuses `duty` rather than redefining it.

### Tests

- 37 duty tests across conflicts, policy resolution, duty length, rest, rolling limits, qualifications, and end-to-end verdicts.
- 21 assign tests across domains, satisfy, optimise, violations, and a composition suite that fills two shifts over `duty` with fitness and rest constraints.
- 33 rostering tests across coverage, compatibility, violations, ranking, greedy fill, replacements and swaps, load, and the assign model solved end to end.
- Scryer smoke: both batteries concatenated flat with a fact set pass on scryer-prolog. `max_list/2` is SWI-only and is avoided in favour of a pure ISO fold.


## 2026-08-13

### Modules

**d20** — new category: the SRD 5.1 rules layer as five composing batteries. All stat blocks and mechanics from the Systems Reference Document 5.1 (CC BY 4.0, Wizards of the Coast LLC). Pure ISO — runs on SWI and Scryer alike; dice stay client-side, the cell is stateless.

- `d20-core` — ability modifiers (floored division, so a score of 7 is -2, not -1), proficiency by level, skills with proficiency/expertise and stat-block overrides, saving throws, passive perception, spell save DC, attack bonuses (finesse-aware, stat-block override first), checks/saves vs DC, and opposed contests with RAW tie semantics.
- `d20-conditions` — all 15 conditions plus the six-level cumulative exhaustion table as queryable `condition_effect/3` data; action/reaction gating and condition-derived advantage.
- `d20-combat` — AC derivation, natural 1/20 hit resolution, damage with resistance/immunity/vulnerability (physical category catches the three subtypes; halving rounds down per RAW), crits double dice only, initiative (descending, keysort-based), `d20_attack_roll_mode/3` resolving the full advantage/disadvantage matrix with RAW cancellation, death-save classification, and massive-damage instant death.
- `d20-monsters` — 16 stat blocks CR 0–13 with full SRD attack profiles (`d20_monster_attack/5`: bonus, damage dice for the client to roll, flat damage bonus, type; Multiattack via `attacks_per_action`).
- `d20-xp` — XP by CR (0–30), encounter thresholds for levels 1–20, action-economy multipliers, and name-based `party_encounter_difficulty/4`.

Generic predicate names take the `d20_` prefix (`d20_resistance`, `d20_can_attack`, `d20_is_defeated`, `d20_initiative_order`, `d20_damage_category`) so the category composes alongside `combat` and `prob-detection` in one namespace — verified by loading everything in a single test process.

### Tests

- 124 d20 tests including *The Goblin Ambush* — an integration suite that runs a complete RAW martial combat across all five batteries and doubles as the category's definition of done. Full suite: 852 green.
- Scryer smoke test: all five batteries concatenated flat (mirroring cell install) pass 19/19 checks on scryer-prolog.


## 2026-07-05

### Fixes

- `fixpoint` **v1.0.1**: three guard holes closed, all variants of the same hazard — evaluating a goal against a still-growing answer set can silently produce wrong or incomplete results, which is strictly worse than not terminating:
  - `setof`/`bagof`/`findall`/`forall` whose subgoal mentions a derived predicate now throw `fixpoint_aggregation_over_derived_unsupported` instead of natively re-proving the recursive predicate (which loops on cyclic data — the exact failure the battery exists to prevent). Aggregate after saturation via `fixpoint_answers/2` instead. Aggregation over base goals is unaffected.
  - The negation guard now walks the whole negated goal: `\+ (reach(X, Y), blocked(Y))` is refused like `\+ reach(X, Y)` (previously slipped through to a native call).
  - The auto-cone walk no longer classifies Prolog-defined *built-ins* as derived: SWI's permissive `clause/2` exposes the implementation of e.g. `length/2`, and a rule body calling it would previously pull that implementation into the saturation set (instantiation errors). Gated with a catch-wrapped `predicate_property/2` probe that degrades to strict-ISO behavior on engines without it.
  - New: `call/N` over a derived predicate is unwrapped and looked up in the answer set (previously re-proven natively — same loop risk).

### Docs

- Corrected every claim that Scryer lacks tabling — it has had it for years via [`library(tabling)`](https://www.scryer.pl/tabling). Thanks to Markus Triska for the correction. The fixpoint battery's actual rationale is unchanged: directives are stripped at cell install on both engines, and `:- table` is an engine extension rather than part of ISO. The fixpoint README now points standalone (CLI) users at real engine tabling where it serves them better.

## 2026-07-04

### Modules

**Reasoning**
- `explain` -- Provenance meta-interpreter: `why/2` returns the flat list of facts supporting any conclusion; `explain/2` returns full proof trees with alternative proofs on backtracking. Pure ISO -- runs on SWI and Scryer alike.
- `fixpoint` -- Bottom-up Datalog-style saturation of stored rules: tabling's termination benefit without tabling. Textbook recursive rules (transitive closure, left-recursive ancestry) work verbatim on cyclic data where plain resolution loops; recursive subgoals are looked up in the growing answer set, each answer derived exactly once. Negation over derived predicates is refused with a clear error (stratification is future work). Pure ISO; the sanctioned alternative the `:- table` lint error now points at.

**Probabilistic**
- `prob-core-iso` -- ProbLog-lite runtime in pure ISO Prolog: noisy-or `psuccess/2`, legacy `pmax/2`, `pnot/2`, `pand/2`, `expected/3` over reified `prob_rule/2` clauses, plus the reference `::` -> `prob_rule` transform. Enables ProbLog notation on ISO-pinned (Scryer) cells with no SWI escalation. **Licensed Apache-2.0** (runtime carve-out; see License below).
- `prob-decide` -- DTProbLog-lite decision layer over `prob-core-iso`: expected utility `eu/2` and `best_action/2` argmax across weighted outcomes.

### `battery` CLI

New Rust CLI (`cli/`, published to crates.io as [`logic-batteries`](https://crates.io/crates/logic-batteries), binary `battery`) for installing batteries into any SWI/Scryer Prolog project -- no DataGrout required:

- `battery install <id>... [--dir D] [--repo R] [-f]` -- copies a battery's rule files into a project directory; refuses to clobber unrelated files without `-f`
- Every installed file is content-hashed into `batteries.lock.json`; `battery remove` deletes only files whose checksum still matches install (modified files are kept and warned about unless `-f`)
- `battery installed` lists a directory's batteries and flags modified ones; `battery list` shows the registry
- `%% Requires:` manifest headers surface as dependency hints at install time

### Manifest ABI rename

- `tether_module/3` and `tether_export/3` are now `battery_module/3` and `battery_export/3` across every module -- the manifest ABI is named for the product, and stays neutral between installers (DataGrout, the CLI, or a bare consult). The DataGrout platform accepts both spellings, so batteries published before the rename keep installing and describing correctly.
- New authoring convention: batteries declare their **input predicates** `:- dynamic(...)` so standalone (consult) users can assert facts after loading. DataGrout strips directives at install time, so cells are unaffected.

### Fixes

- `prob-economy` **v1.0.1**: replaced the SWI-only `max_list/2` with a pure-ISO fold (internal `pe_max_list/3`), so the battery's `supply_disruption/2` and `demand_spike/2` run on Scryer/ISO-pinned cells (it installed there but those predicates failed at query time). No API change.
- `fsm` **v1.0.1**: `fsm_reachable/3` rewritten as a bottom-up BFS fixpoint, dropping its `:- table` directive. The old recursive definition was only cycle-safe under tabling — which never reached logic cells, because the installer strips directives on both engines (SWI and Scryer each support tabling outside cells) — so reachability and `fsm_cycle/2` queries on any machine with a cycle longer than a self-loop hung until the query watchdog. The fixpoint has tabling-equivalent semantics (each reachable state derived exactly once), always terminates, and runs in pure ISO on SWI and Scryer alike.

### Licensing

- Tiered licensing, documented in the README license table: content batteries remain Elastic License 2.0; `prob-core-iso` is carved out as Apache-2.0 (core runtime, embeddable anywhere); the `battery` CLI is MIT.
- New `CONTRIBUTING.md` with the battery authoring guide and contribution terms (DCO sign-off + contribution license grant).
- Registry entries may carry an explicit `license` field; absent means the repository default.

## 2026-05-11

### Modules

**Reasoning**
- `temporal` -- Event ordering, overlap, gaps, and deadline reasoning over timestamped facts
- `taxonomy` -- Hierarchical classification with transitive membership and property inheritance
- `fsm` moved from the repository root category into `reasoning/`

**Probabilistic** (new category)
- `prob-loot` -- Drop probabilities and expected yields, layered on `loot-tables`
- `prob-detection` -- Guard perception and stealth probability from environment and alert state
- `prob-economy` -- Market uncertainty: supply disruption and demand spike probabilities
- `prob-npc` -- NPC trust and disposition probability from faction standing

## 2026-05-09

Initial public release.

### Modules

**Reasoning**
- `fsm` -- General-purpose finite state machine (25 predicates)

**Games** (15 modules)
- `inventory` -- Item carrying, weight, and slot constraints
- `loot-tables` -- Drop weights, rarity tiers, condition-gated loot
- `quests` -- Prerequisite chains, objectives, and turn-in
- `combat` -- Damage types, resistances, status effects, turn order
- `progression` -- XP curves, level gates, stat scaling, prestige
- `economy` -- Crafting costs, supply/demand pricing
- `npc-state` -- Affinity tracking and dialogue availability
- `puzzle-fsm` -- FSM transitions, win conditions, hints
- `world` -- Time of day, weather, season, moon phase
- `faction` -- Reputation scores, standing tiers, area access
- `dialogue` -- Context-aware lines, gated choices, memory
- `crafting` -- Recipe knowledge, skill requirements, discovery
- `permissions` -- Role-based access, inheritance, ownership
- `ai-director` -- Pacing states, spawn eligibility, difficulty scaling
- `dungeon` -- Room connectivity, key locks, clearance tracking

**Business** (8 modules)
- `lead-scoring` -- Weighted scoring, tier derivation, disqualification
- `invoice-rules` -- Overdue detection, late fees, escalation levels
- `approval-chains` -- Multi-step approvals, delegation, rejection tracking
- `inventory-mgmt` -- Stock levels, reorder triggers, supplier selection
- `pricing-rules` -- Tier pricing, discounts, bulk breaks, floor/ceiling
- `loyalty` -- Points balance, tier benefits, redemption costs
- `scheduling` -- Slot availability, conflicts, advance booking windows
- `compliance` -- Policy checks, retention windows, consent registry

### Toolsuite

- `batteries.*` MCP toolsuite spec (`tools/batteries.json`) -- search, install, list, and remove batteries directly from an LC session

### Infrastructure

- Safety linter (`make lint`) -- static check for prohibited predicates across all `.pl` files
- Full Prolog test suite under `test/` with per-module and integration tests
- CI via GitHub Actions -- lint + tests on every push and PR
