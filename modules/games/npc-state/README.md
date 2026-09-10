# Module: npc-state v1.0.0

A numeric relationship between an NPC and a player, disposition derived from
it, faction membership, and dialogue topics gated on all three.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["npc-state"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("npc-state", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `relationship_level(NPC, Player, Level)` | The score; 0 when none is set |
| `npc_friendly(NPC, Player)` | `always_friendly`, or score at or above `friendly_threshold` and not `always_hostile` |
| `npc_hostile(NPC, Player)` | `always_hostile`, or score at or below `hostile_threshold` and not `always_friendly` |
| `faction_member(Entity, Faction)` | The entity's `faction` attribute |
| `dialogue_available(NPC, Player, Topic)` | The NPC `has_dialogue` the topic and the player meets its prerequisites |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `score` | `<npc>_<player>` | number | The relationship, on a composite entity: `merchant_alice`. Absent reads as 0 |
| `always_friendly` | NPC | `true` | Friendly to everyone regardless of score |
| `always_hostile` | NPC | `true` | Hostile to everyone regardless of score |
| `faction` | any entity | a faction id | Membership; one faction per entity |
| `requires_friendly` | topic | `true` | The NPC must be `npc_friendly` to the player |
| `requires_relationship` | topic | number | Score must be at least this |
| `requires_quest` | topic | a quest id | The player must have `completed_quest` it |
| `requires_item` | topic | an item id | The player must `has_item` it |
| `friendly_threshold` | `relationship` | number | Default 25 |
| `hostile_threshold` | `relationship` | number | Default −25. Scores strictly between the two are neutral |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `has_dialogue` | NPC → topic | The NPC can talk about the topic at all |
| `completed_quest` | player → quest | Satisfies `requires_quest` |
| `has_item` | player → item | Satisfies `requires_item` |

`relationship` is a fixed entity name for the two thresholds. Faction-to-faction
relations (`allied_with`, `at_war_with`) are the `faction` battery's; nothing
here reads them.

## Setup

```
# Relationships, on <npc>_<player>
{ type="attribute", entity="merchant_alice", attribute="score", value=75 }
{ type="attribute", entity="bandit_alice",   attribute="score", value=-80 }

# Fixed dispositions
{ type="attribute", entity="innkeeper", attribute="always_friendly", value=true }
{ type="attribute", entity="bandit",    attribute="always_hostile",  value=true }

# Factions
{ type="attribute", entity="merchant", attribute="faction", value="traders_guild" }

# Topics and their gates
{ type="relation",  subject="merchant", relation="has_dialogue", object="buy_items" }
{ type="relation",  subject="merchant", relation="has_dialogue", object="secret_sale" }
{ type="attribute", entity="secret_sale", attribute="requires_friendly", value=true }
{ type="relation",  subject="merchant", relation="has_dialogue", object="guild_info" }
{ type="attribute", entity="guild_info", attribute="requires_relationship", value=60 }
{ type="relation",  subject="merchant", relation="has_dialogue", object="reward_topic" }
{ type="attribute", entity="reward_topic", attribute="requires_quest", value="find_artifact" }

# Tuning (optional)
{ type="attribute", entity="relationship", attribute="friendly_threshold", value=25 }
{ type="attribute", entity="relationship", attribute="hostile_threshold",  value=-25 }
```

## Querying

```
# How does the merchant feel about alice?
relationship_level(merchant, alice, L)
   L = 75
npc_friendly(merchant, alice)

# What will he talk about? (reward_topic needs the quest)
dialogue_available(merchant, alice, Topic)
   Topic = buy_items ;
   Topic = secret_sale ;
   Topic = guild_info

# Guild member?
faction_member(merchant, F)
   F = traders_guild
```

Changing a relationship is an assert of the new `score`; read the current one
first if you are adding to it.

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "dialogue_available(merchant, alice, T)", function(rs) for _, r in ipairs(rs) do addOption(r.T) end end)
```

## Semantics worth knowing

**Both flags means both answers.** An NPC with `always_friendly` and
`always_hostile` set satisfies `npc_friendly` *and* `npc_hostile`; each flag
short-circuits its own predicate before the other is checked. Set one.

**Neutral is a band, not a value.** With the defaults, scores from −24 to 24
are neither friendly nor hostile; both predicates fail.

**Composite keys.** `<npc>_<player>` joins with `_`, so ids containing `_`
can collide. Keep ids free of `_`.

## Composing with Other Modules

`dialogue` for the lines and choices once a topic is available; `faction` for
standing between the player and the NPC's faction; `quests` and `inventory` for
the facts the prerequisites read.
