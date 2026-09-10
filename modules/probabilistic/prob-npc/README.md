# Module: prob-npc v1.0.0

How likely an NPC is to trust a player, tell them something, help them, or cut
them a deal — derived from faction standing and personal relationship, so the
game asks the cell instead of asking a model to guess.

**Requires:** `faction` (for `faction_standing/3`) and `npc-state` (for
`npc_friendly/2`, `npc_hostile/2`, `relationship_level/3`).

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["npc-state", "faction", "prob-npc"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install_many({"npc-state", "faction", "prob-npc"}, "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `trust_probability(NPC, Player, P)` | Standing base plus `relationship / 500`, clamped to 0.01–0.99 |
| `will_share_info(NPC, Player, Topic)` | Probabilistic; weight falls with the topic's `sensitivity` and needs trust |
| `will_assist(NPC, Player, Task)` | Probabilistic; weight falls with the task's `assistance_cost` and needs trust |
| `npc_price_modifier(NPC, Player, Mod)` | `clamp(1 − (trust − 0.5) × 0.4, 0.70, 1.30)`; below 1 is a discount |
| `disposition_probability(NPC, Player, P)` | Trust, +0.15 if `npc_friendly`, −0.30 if `npc_hostile`, clamped |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `faction` | NPC | a faction id | Trust starts from the player's standing with this faction (via the `faction` battery). Without one, the base is 0.35 |
| `sensitivity` | topic | `low` \| `medium` \| `high` \| `secret` | How guarded the topic is: the sharing weight drops 0.90 (none) → 0.75 → 0.50 → 0.25 → 0.05, and from `medium` up a minimum relationship of 25 / 60 / 90 is also required |
| `assistance_cost` | task | `low` \| `medium` \| `high` | How much the favour costs the NPC: 0.90 (none) → 0.80 → 0.50 → 0.20, with a minimum relationship of 25 for `medium` and 50 for `high` |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `knows_topic` | NPC → topic | The NPC can share the topic at all |
| `can_assist` | NPC → task | The NPC can help with the task at all |

Standing and relationship are read through the `faction` and `npc-state`
batteries — `faction_standing/3`, `npc_friendly/2`, `npc_hostile/2`,
`relationship_level/3` — so the player's `score` facts on `<player>_<faction>`
and `<npc>_<player>` are what drive this one. Install both.

**The trust base by standing:** exalted 0.90, revered 0.80, honored 0.70,
friendly 0.55, neutral 0.35, unfriendly 0.10, hostile 0.02. Deterministic
`trust_probability/3` adds `relationship / 500` to that and clamps to
0.01–0.99. The ProbLog `npc_trusts/2` has no clause for a faction-less NPC that
is hostile, so it is simply absent there rather than low.

## Setup

```
# The NPC's faction, and the player's standing with it (faction battery)
{ type="attribute", entity="merchant",              attribute="faction", value="traders_guild" }
{ type="attribute", entity="alice_traders_guild",   attribute="score",   value=5000 }

# Their personal relationship (npc-state battery), on <npc>_<player>
{ type="attribute", entity="merchant_alice", attribute="score", value=40 }

# What the merchant knows, and how guarded each topic is
{ type="relation",  subject="merchant", relation="knows_topic", object="trade_routes" }
{ type="attribute", entity="trade_routes",    attribute="sensitivity", value="low" }
{ type="relation",  subject="merchant", relation="knows_topic", object="secret_supplier" }
{ type="attribute", entity="secret_supplier", attribute="sensitivity", value="secret" }

# What the blacksmith can do, and what it costs him
{ type="relation",  subject="blacksmith", relation="can_assist", object="forge_weapon" }
{ type="attribute", entity="forge_weapon", attribute="assistance_cost", value="medium" }
```

## Querying

```
# friendly (5000 ≥ 3000) → 0.55, plus 40/500
trust_probability(merchant, alice, P)
   P = 0.63

# A small discount
npc_price_modifier(merchant, alice, Mod)
   Mod = 0.948

# Warmth for the portrait
disposition_probability(merchant, alice, P)
   P = 0.78

# Will he tell her? (secret: weight 0.05, and needs relationship ≥ 90 — she has 40)
probability(will_share_info(merchant, alice, secret_supplier), P)
   P = 0.0
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "disposition_probability(merchant, alice, P)", function(r) if r[1] then setPortraitMood(r[1].P) end end)
```

## Trust by Faction Standing

| Standing | Base |
|---|---|
| `exalted` | 0.90 |
| `revered` | 0.80 |
| `honored` | 0.70 |
| `friendly` | 0.55 |
| `neutral` | 0.35 |
| `unfriendly` | 0.10 |
| `hostile` | 0.02 |

Relationship adds `score / 500` on top — +0.2 at a score of 100.

## Information and Assistance

| `sensitivity` / `assistance_cost` | Share weight | Assist weight | Relationship needed |
|---|---|---|---|
| none | 0.90 | 0.90 | — |
| `low` | 0.75 | 0.80 | — |
| `medium` | 0.50 | 0.50 | ≥ 25 |
| `high` | 0.25 | 0.20 | ≥ 60 share / ≥ 50 assist |
| `secret` | 0.05 | — | ≥ 90 |

Every row also requires `npc_trusts`, itself probabilistic, so the marginal is
the product.

## Semantics worth knowing

**Two trust models.** `trust_probability/3` is arithmetic. `npc_trusts/2`,
which `will_share_info` and `will_assist` depend on, is ProbLog-weighted by
standing (0.90 down to 0.02), or 0.75 / 0.20 for a faction-less NPC that is
friendly / neither. A faction-less hostile NPC has no `npc_trusts` clause at
all — sharing and assisting are impossible, not merely unlikely.

**Disposition can exceed trust.** `npc_friendly` adds a flat 0.15, so a
friendly NPC in a hostile faction still warms up.

**Relationship gates are hard.** Below the required relationship the sharing or
assisting clause does not fire regardless of trust; there is no gradual
fall-off.
