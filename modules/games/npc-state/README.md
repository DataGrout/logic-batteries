# Module: npc-state v1.0.0

Relationship tracking, faction membership, NPC disposition, and dialogue prerequisites.

## Install

```lua
dg:batteries().install("npc-state", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```

> Lua examples use [Tether](https://github.com/datagrout/tether), the Lua client for DataGrout.

## Exported Predicates

| Predicate | Description |
|---|---|
| `relationship_level(NPC, Player, Level)` | Numeric relationship score between NPC and Player |
| `npc_friendly(NPC, Player)` | NPC has a friendly disposition toward Player |
| `npc_hostile(NPC, Player)` | NPC has a hostile disposition toward Player |
| `faction_member(Entity, Faction)` | Entity belongs to Faction |
| `dialogue_available(NPC, Player, Topic)` | Topic is an unlocked conversation option |

## Relationship Scores

Scores are numeric. Default is 0 (neutral). Positive scores → friendly, negative → hostile.

```lua
-- Set a relationship score (keyed as npc_player)
dg:assert("my-game", { type="attribute", entity="merchant_alice", attribute="score", value=75 })
dg:assert("my-game", { type="attribute", entity="bandit_alice",   attribute="score", value=-80 })
```

### Thresholds

```lua
-- Default thresholds (override to change globally)
-- Friendly: score >= 25
-- Hostile:  score <= -25
dg:assert("my-game", { type="attribute", entity="relationship", attribute="friendly_threshold", value=25  })
dg:assert("my-game", { type="attribute", entity="relationship", attribute="hostile_threshold",  value=-25 })
```

### Always-on overrides

```lua
-- Bypass score entirely — always friendly/hostile regardless of score
dg:assert("my-game", { type="attribute", entity="innkeeper", attribute="always_friendly", value=true })
dg:assert("my-game", { type="attribute", entity="bandit",    attribute="always_hostile",  value=true })
```

## Factions

```lua
dg:assert("my-game", { type="attribute", entity="merchant", attribute="faction", value="traders_guild" })
dg:assert("my-game", { type="attribute", entity="guard",    attribute="faction", value="city_watch"    })

-- Faction-level relations (for your own logic — not consumed by this module's predicates)
dg:assert("my-game", { type="attribute", entity="traders_guild", attribute="allied_with",  value="merchants_guild" })
dg:assert("my-game", { type="attribute", entity="bandits",       attribute="at_war_with",  value="kingdom"         })
```

## Dialogue Prerequisites

```lua
-- Any topic associated with an NPC
dg:assert("my-game", { type="relation", subject="merchant", relation="has_dialogue", object="buy_items" })

-- Requires friendly disposition
dg:assert("my-game", { type="relation", subject="merchant", relation="has_dialogue", object="secret_sale" })
dg:assert("my-game", { type="attribute", entity="secret_sale", attribute="requires_friendly", value=true })

-- Requires minimum relationship score
dg:assert("my-game", { type="relation", subject="merchant", relation="has_dialogue", object="guild_info" })
dg:assert("my-game", { type="attribute", entity="guild_info", attribute="requires_relationship", value=60 })

-- Requires a completed quest
dg:assert("my-game", { type="relation", subject="merchant", relation="has_dialogue", object="reward_topic" })
dg:assert("my-game", { type="attribute", entity="reward_topic", attribute="requires_quest", value="find_artifact" })

-- Requires player to carry an item
dg:assert("my-game", { type="relation", subject="merchant", relation="has_dialogue", object="members_discount" })
dg:assert("my-game", { type="attribute", entity="members_discount", attribute="requires_item", value="guild_badge" })
```

## Usage

```lua
-- What is the current relationship score?
dg:query("my-game", "relationship_level(merchant, alice, L)", function(results)
  if results[1] then updateRelationshipBar(results[1].L) end
end)

-- Is the merchant friendly toward alice?
dg:query("my-game", "npc_friendly(merchant, alice)", function(results)
  if #results > 0 then showFriendlyGreeting() else showNeutralGreeting() end
end)

-- What dialogue topics are available?
dg:query("my-game", "dialogue_available(merchant, alice, Topic)", function(results)
  for _, r in ipairs(results) do addDialogueOption(r.Topic) end
end)

-- Is this NPC a guild member?
dg:query("my-game", "faction_member(merchant, traders_guild)", function(results)
  if #results > 0 then showGuildBadge() end
end)

-- Improve relationship after a good deed
local function improveRelationship(npc, player, amount)
  dg:query("my-game", "relationship_level(" .. npc .. ", " .. player .. ", Current)", function(results)
    local current = results[1] and results[1].Current or 0
    local key = npc .. "_" .. player
    dg:assert("my-game", {
      type="attribute", entity=key, attribute="score",
      value=math.min(100, current + amount)
    })
  end)
end
```

## Composing with Other Modules

Works naturally with `quests` (quest completion unlocks dialogue), `inventory` (carried items gate topics), and `economy` (friendly NPCs offer discounted prices).
