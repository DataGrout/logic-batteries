# Changelog

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
- `fsm` **v1.0.1**: `fsm_reachable/3` rewritten as a bottom-up BFS fixpoint, dropping its `:- table` directive. The old recursive definition was only cycle-safe under tabling — which never reached logic cells (the installer strips directives on both engines) and does not exist on Scryer — so reachability and `fsm_cycle/2` queries on any machine with a cycle longer than a self-loop hung until the query watchdog. The fixpoint has tabling-equivalent semantics (each reachable state derived exactly once), always terminates, and runs in pure ISO on SWI and Scryer alike.

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
