# Logic Batteries

[![CI](https://github.com/datagrout/logic-batteries/actions/workflows/ci.yml/badge.svg)](https://github.com/datagrout/logic-batteries/actions/workflows/ci.yml)

**Pre-built Prolog rule modules for DataGrout logic cells. The npm of living software.**

Insert a battery into a logic cell and it has new capabilities immediately — no schema setup, no migration, no boilerplate. Assert facts into the same namespace and the battery's predicates reason over them.

## Batteries Included

### Reasoning

| Module | Predicates | Description |
|---|---|---|
| [fsm](./modules/fsm/) | 25 | General-purpose finite state machine |

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

Toolsuite spec: [`tools/batteries.json`](./tools/batteries.json)

## Install

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

Batteries must stay within the predicate whitelist provided by the LC runtime. Rules that call predicates outside this set — process execution, file I/O, networking, global mutable state, or runtime fact modification — are not permitted. This ensures batteries are safe to load in any environment, not just the managed runtime.

`make lint` runs a static check over all battery files and fails if any prohibited predicates are present. CI enforces this on every push.

## License

[Elastic License 2.0](./LICENSE) — free to use; cannot be used to provide a competing managed Logic Cell service.
