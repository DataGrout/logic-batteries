# Module: dialogue v1.0.0

Context-aware NPC line selection, player choice filtering, topic navigation, and conversation memory. Pairs with npc-state for relationship-gated dialogue.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["dialogue"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install("dialogue", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `npc_says(NPC, Player, Topic, Line)` | The line NPC speaks for Topic, adjusted for context |
| `player_choices(NPC, Player, Topic, Choices)` | Available player responses (prerequisites filtered) |
| `choice_leads_to(Topic, Choice, NextTopic)` | Navigation: choosing Choice from Topic goes to NextTopic |
| `npc_remembers(NPC, Player, Topic)` | NPC has previously discussed Topic with Player |
| `dialogue_complete(NPC, Player, Topic)` | No further non-ending choices remain in Topic |

## Setup

### Dialogue topics and lines

```lua
local ns = "my-game"

-- Base line for a topic
dg:assert(ns, { type="attribute", entity="buy_items", attribute="line",
                value="What would you like?" })

-- Context-sensitive overrides (checked before base line)
dg:assert(ns, { type="attribute", entity="buy_items", attribute="line_friendly",
                value="Great to see you! What can I get you?" })
dg:assert(ns, { type="attribute", entity="buy_items", attribute="line_hostile",
                value="Make it quick." })
dg:assert(ns, { type="attribute", entity="buy_items", attribute="line_repeat",
                value="Back again? Let me know what you need." })
```

### Player choices and navigation

```lua
dg:assert(ns, { type="relation", subject="buy_items", relation="has_choice", object="ask_price"  })
dg:assert(ns, { type="relation", subject="buy_items", relation="has_choice", object="browse"     })
dg:assert(ns, { type="relation", subject="buy_items", relation="has_choice", object="leave"      })

-- Navigation
dg:assert(ns, { type="attribute", entity="ask_price", attribute="leads_to", value="show_prices" })

-- This choice exits dialogue
dg:assert(ns, { type="attribute", entity="leave", attribute="ends_dialogue", value=true })
```

### Gated choices

```lua
-- Requires player to have enough gold
dg:assert(ns, { type="attribute", entity="rare_item", attribute="requires_gold", value=50 })

-- Requires player to hold a specific item
dg:assert(ns, { type="attribute", entity="secret_trade", attribute="requires_item", value="golden_token" })
```

### NPC personality flags

```lua
-- NPC always uses the friendly line variant
dg:assert(ns, { type="attribute", entity="merchant_alice", attribute="always_friendly", value=true })
```

### Memory (NPC remembers past conversations)

Memory is keyed as `<npc>_<player>`:

```lua
dg:assert(ns, { type="relation", subject="merchant_alice_player1",
                relation="discussed", object="secret_sale" })
```

## Querying

```lua
-- Get what the NPC says
dg:query(ns, "npc_says(merchant_alice, player1, buy_items, Line)", function(result)
  showDialogueBubble(result.Line)
end)

-- Get available choices for the player
dg:query_all(ns, "player_choices(merchant_alice, player1, buy_items, Choices)", function(result)
  showChoiceMenu(result.Choices)
end)

-- Navigate when player selects a choice
dg:query(ns, "choice_leads_to(buy_items, ask_price, Next)", function(result)
  loadTopic(result.Next)
end)
```

## Line Selection Priority

1. NPC has `always_friendly` → `line_friendly` variant
2. NPC has `always_hostile` → `line_hostile` variant
3. NPC remembers topic from prior conversation → `line_repeat` variant
4. Base `line`
5. Empty string (silent — useful for topics that are navigational only)

## Choice Filtering

`player_choices` returns only choices where:
- The choice does not have `ends_dialogue = true`
- All prerequisites are met (gold threshold, required item)

Choices with `ends_dialogue = true` still navigate via `choice_leads_to` — show them as a separate "Exit" button rather than in the choice list.
