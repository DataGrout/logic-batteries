# Logic Batteries

[![CI](https://github.com/datagrout/logic-batteries/actions/workflows/ci.yml/badge.svg)](https://github.com/datagrout/logic-batteries/actions/workflows/ci.yml)
[![crates.io](https://img.shields.io/crates/v/logic-batteries.svg)](https://crates.io/crates/logic-batteries)

**Pre-built Prolog rule modules for DataGrout logic cells. The npm of living software.**

Insert a battery into a logic cell and it has new capabilities immediately — no schema setup, no migration, no boilerplate. Assert facts into the same namespace and the battery's predicates reason over them.

## Batteries Included

### Reasoning

| Module | Predicates | Description |
|---|---|---|
| [fsm](./modules/reasoning/fsm/) | 25 | General-purpose finite state machine — reachability, shortest paths, cycle detection |
| [temporal](./modules/reasoning/temporal/) | 12 | Event ordering, overlap, gaps, and deadline reasoning over timestamped facts |
| [taxonomy](./modules/reasoning/taxonomy/) | 10 | Hierarchical classification with transitive membership and property inheritance |
| [explain](./modules/reasoning/explain/) | 6 | Provenance meta-interpreter — `why/2` returns the facts supporting any conclusion; `explain/2` returns full proof trees |
| [fixpoint](./modules/reasoning/fixpoint/) | 4 | Bottom-up Datalog saturation — tabling's termination benefit without tabling; cyclic/left-recursive rules work verbatim |

### Probabilistic

Query exact probabilities instead of thresholds — zero LLM calls per tick. Weighted rules use ProbLog `P::Head` notation; on ISO cells they are reified through `prob-core-iso`, so probabilistic reasoning runs on SWI **and** Scryer alike.

| Module | Predicates | Description |
|---|---|---|
| [prob-core-iso](./modules/probabilistic/prob-core-iso/) | 6 | ProbLog-lite runtime in pure ISO — noisy-or `psuccess/2`, `pmax/2`, negation, conjunction, expected value over reified weighted rules |
| [prob-decide](./modules/probabilistic/prob-decide/) | 4 | Decision theory over `prob-core-iso` — expected utility `eu/2` and `best_action/2` argmax across weighted outcomes |
| [prob-loot](./modules/probabilistic/prob-loot/) | 4 | Drop probabilities and expected yields — layered on `loot-tables` |
| [prob-detection](./modules/probabilistic/prob-detection/) | 4 | Guard perception and stealth probability from environment and alert state — requires `combat` |
| [prob-economy](./modules/probabilistic/prob-economy/) | 5 | Market uncertainty: supply disruption and demand spike probabilities — requires `economy` |
| [prob-npc](./modules/probabilistic/prob-npc/) | 5 | NPC trust and disposition probability from faction standing — requires `npc-state` and `faction` |

### Games

| Module | Predicates | Description |
|---|---|---|
| [inventory](./modules/games/inventory/) | 7 | Item carrying, weight, slot constraints |
| [loot-tables](./modules/games/loot-tables/) | 6 | Drop weights, rarity, condition-gated loot |
| [quests](./modules/games/quests/) | 6 | Prerequisite chains, objectives, turn-in |
| [progression](./modules/games/progression/) | 5 | XP curves, level gates, stat scaling, prestige |
| [combat](./modules/games/combat/) | 6 | Damage types, resistances, status effects, turn order |
| [economy](./modules/games/economy/) | 5 | Crafting costs, supply/demand pricing |
| [npc-state](./modules/games/npc-state/) | 5 | Affinity tracking, dialogue availability |
| [puzzle-fsm](./modules/games/puzzle-fsm/) | 5 | FSM transitions, win conditions, hints |
| [world](./modules/games/world/) | 6 | Time of day, weather, season, moon phase |
| [faction](./modules/games/faction/) | 5 | Reputation scores, standing tiers, area access |
| [dialogue](./modules/games/dialogue/) | 5 | Context-aware lines, gated choices, memory |
| [crafting](./modules/games/crafting/) | 5 | Recipe knowledge, skill requirements, discovery |
| [permissions](./modules/games/permissions/) | 5 | Role-based access, inheritance, ownership |
| [ai-director](./modules/games/ai_director/) | 5 | Pacing states, spawn eligibility, difficulty scaling |
| [dungeon](./modules/games/dungeon/) | 5 | Room connectivity, key locks, clearance tracking |

### Business

| Module | Predicates | Description |
|---|---|---|
| [lead-scoring](./modules/business/lead_scoring/) | 5 | Weighted scoring, tier derivation, disqualification |
| [invoice-rules](./modules/business/invoice_rules/) | 5 | Overdue detection, late fees, escalation levels |
| [approval-chains](./modules/business/approval_chains/) | 5 | Multi-step approvals, delegation, rejection tracking |
| [inventory-mgmt](./modules/business/inventory_mgmt/) | 5 | Stock levels, reorder triggers, supplier selection |
| [pricing-rules](./modules/business/pricing_rules/) | 5 | Tier pricing, discounts, bulk breaks, floor/ceiling |
| [loyalty](./modules/business/loyalty/) | 5 | Points balance, tier benefits, redemption costs |
| [scheduling](./modules/business/scheduling/) | 5 | Slot availability, conflicts, advance windows |
| [compliance](./modules/business/compliance/) | 5 | Policy checks, retention windows, consent registry |

## batteries.* MCP Toolsuite

The `batteries.*` toolsuite lets agents search, install, and manage batteries directly from an LC session — no manual Prolog URL handling needed.

| Tool | Description |
|---|---|
| `batteries.search(query?, category?, tags?)` | Search by keyword, category, or tags — omit query to browse all |
| `batteries.install_many(ids[], namespace)` | Install one or more batteries into a namespace |
| `batteries.installed(namespace)` | List all batteries currently installed in a namespace |
| `batteries.remove(id, namespace)` | Retract a battery's rules from a namespace |

Installation state is tracked directly in the LC: `attribute('_batteries', battery_id, version)`. This makes `batteries.installed` a plain `lc.query` call and keeps state co-located with the rules.

## Install

### `battery` CLI (any Prolog project — no DataGrout required)

Batteries are plain ISO/SWI Prolog files, so they also work in bare `swipl` /
`scryer-prolog` projects. The [`battery` CLI](./cli/) copies a battery's rule
files into your project directory and content-hashes them into
`batteries.lock.json`:

```console
$ battery install prob-core-iso prob-decide --dir my-app/
✓ installed prob-core-iso 1.0.0 (2 files)
✓ installed prob-decide 1.0.0 (1 file)
$ battery remove prob-decide --dir my-app/
```

`remove` only deletes files whose checksum still matches what was installed —
a battery you've modified is kept (and warned about) unless you pass `-f`.
`battery installed` lists what's in a directory and flags modified entries;
`battery list` shows the registry. Install with `cargo install logic-batteries`, or build from
[`cli/`](./cli/).

### Tether (Luau / Roblox)

[Tether](https://github.com/datagrout/tether) is the Lua client for DataGrout. The `dg` object in module README examples is a Tether client instance.

```lua
dg:batteries().install("inventory", "my-namespace", function(result)
  print(result.installed_count .. " batteries installed")
end)
```

### Any DG client

```json
{
  "tool": "batteries.install_many",
  "ids": ["inventory"],
  "namespace": "my-namespace"
}
```

## What Is This

A DataGrout logic cell is a persistent, queryable Prolog fact store — the reasoning substrate for your application or agent. You assert facts into it (`logic.assert`) and query them (`logic.query`). It's the brain.

Logic Batteries provides pre-built reasoning engines that run inside that brain. Each battery is a self-contained Prolog library that operates over facts you assert into the same namespace. Load the FSM battery and your LC becomes a finite state machine engine. Load the game batteries and it becomes your game's rules engine.

Batteries are designed to compose. A game using `quests` + `inventory` + `loot-tables` + `npc-state` has four batteries sharing a single fact namespace — quest completion triggers dialogue unlocks, loot items land in inventory, NPC disposition gates quest availability. The composition happens through Prolog unification over shared facts. No event bus. No integration code. Just facts and rules.

These aren't examples or recipes. They're programs you load into a living reasoning substrate.

## Contributing Batteries

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the full authoring guide and contribution terms (DCO sign-off + contribution license grant).

The short version: every battery declares a manifest in its rule file — `battery_module(Id, Version, Mode)` plus one `battery_export(Id, 'pred/arity', 'doc string')` per public predicate (read by `batteries.describe` and the CLI as authoritative documentation) — and declares its *input* predicates `:- dynamic(...)` so standalone (consult) users can assert facts after loading. Batteries must stay within the LC runtime's predicate whitelist: no process execution, file I/O, networking, global mutable state, or runtime fact modification. `make lint` enforces this on every push.

## License

Three deliberate tiers — permissive tooling and runtime, protected content:

| What | License | Why |
|---|---|---|
| Content batteries (default) | [Elastic License 2.0](./LICENSE) | Free to use — including vendored into your projects via the CLI — but can't seed a competing managed Logic Cell service |
| [prob-core-iso](./modules/probabilistic/prob-core-iso/) | [Apache-2.0](./modules/probabilistic/prob-core-iso/LICENSE) | Core runtime, not content — embed it anywhere, no restrictions |
| [`battery` CLI](./cli/) | [MIT](./cli/LICENSE) | Commodity tooling — the batteries it installs carry their own license |

Registry entries may carry an explicit `license` field; when absent, the
repository default (Elastic License 2.0) applies.
