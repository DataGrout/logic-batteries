# Changelog

## [1.0.0] -- 2026-05-09

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
