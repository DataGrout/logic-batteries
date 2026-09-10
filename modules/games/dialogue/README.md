# Module: dialogue v1.0.0

What an NPC says for a topic, adjusted for disposition and memory; which
replies the player may pick; where each reply leads; whether the topic is
exhausted. Pairs with `npc-state` for relationship-gated lines.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["dialogue"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("dialogue", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `npc_says(NPC, Player, Topic, Line)` | The line for the topic — see selection priority. `""` when the topic has no line |
| `player_choices(NPC, Player, Topic, Choices)` | One list: the topic's choices that do not end dialogue and whose prerequisites the player meets |
| `choice_leads_to(Topic, Choice, NextTopic)` | The choice's `leads_to`, provided the topic actually has that choice |
| `npc_remembers(NPC, Player, Topic)` | The pair has `discussed` the topic |
| `dialogue_complete(NPC, Player, Topic)` | No non-ending choice remains that the player qualifies for |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `line` | topic | text | The base line |
| `line_friendly` | topic | text | Used instead when the NPC is `always_friendly` |
| `line_hostile` | topic | text | Used instead when the NPC is `always_hostile` |
| `line_repeat` | topic | text | Used instead when the NPC `npc_remembers` this topic with this player |
| `always_friendly` | NPC | `true` | Disposition flag |
| `always_hostile` | NPC | `true` | Disposition flag; `always_friendly` wins if both are set |
| `leads_to` | choice | a topic id | Where picking the choice goes |
| `ends_dialogue` | choice | `true` | The choice exits; it is left out of `player_choices` but still navigates via `choice_leads_to` |
| `requires_gold` | choice | integer | The player's `gold` must be at least this |
| `requires_item` | choice | an item id | The player must `has_item` it |
| `gold` | player | integer | Checked against `requires_gold`. A player with no `gold` fact fails every gold gate |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `has_choice` | topic → choice | Attaches a reply to a topic |
| `discussed` | `<npc>_<player>` → topic | Conversation memory, on a composite entity: `merchant_alice_player1` |
| `has_item` | player → item | Satisfies `requires_item` |

`line_morning` appears in the source comments but no clause reads it; there is
no time-of-day context.

## Line Selection Priority

1. NPC `always_friendly` and the topic has `line_friendly`
2. NPC `always_hostile` and the topic has `line_hostile`
3. NPC remembers the topic and it has `line_repeat`
4. `line`
5. `""`

A variant is only used when the topic defines it; a friendly NPC on a topic
with no `line_friendly` falls through to the base line.

## Setup

```
# A topic and its lines
{ type="attribute", entity="buy_items", attribute="line",          value="What would you like?" }
{ type="attribute", entity="buy_items", attribute="line_friendly", value="Great to see you! What can I get you?" }
{ type="attribute", entity="buy_items", attribute="line_hostile",  value="Make it quick." }
{ type="attribute", entity="buy_items", attribute="line_repeat",   value="Back again? Let me know what you need." }

# Replies and where they go
{ type="relation",  subject="buy_items", relation="has_choice", object="ask_price" }
{ type="relation",  subject="buy_items", relation="has_choice", object="secret_trade" }
{ type="relation",  subject="buy_items", relation="has_choice", object="leave" }
{ type="attribute", entity="ask_price",    attribute="leads_to",      value="show_prices" }
{ type="attribute", entity="secret_trade", attribute="requires_item", value="golden_token" }
{ type="attribute", entity="leave",        attribute="ends_dialogue", value=true }

# Disposition
{ type="attribute", entity="merchant_alice", attribute="always_friendly", value=true }

# The player
{ type="attribute", entity="player1", attribute="gold", value=120 }

# Memory, on <npc>_<player>, asserted by you after a conversation
{ type="relation",  subject="merchant_alice_player1", relation="discussed", object="secret_sale" }
```

## Querying

```
# What does she say?
npc_says(merchant_alice, player1, buy_items, Line)
   Line = "Great to see you! What can I get you?"

# What may the player reply? (secret_trade needs the token; leave ends dialogue)
player_choices(merchant_alice, player1, buy_items, Choices)
   Choices = [ask_price]

# The player picked one
choice_leads_to(buy_items, ask_price, Next)
   Next = show_prices

# Nothing left to say here?
dialogue_complete(merchant_alice, player1, buy_items)
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "npc_says(merchant_alice, player1, buy_items, L)", function(r) if r[1] then showBubble(r[1].L) end end)
```

## Semantics worth knowing

**`player_choices` is one answer, a list.** It uses `findall`, so there is one
solution with `Choices` bound to the whole list — not one solution per choice.

**Exits are hidden, not gone.** A choice with `ends_dialogue` never appears in
`player_choices`; show it as a separate leave button and navigate it with
`choice_leads_to` like any other.

**Memory is yours to write.** Nothing here asserts `discussed`; add it when a
topic has been shown if you want `line_repeat` to trigger next time.

**Composite keys.** `<npc>_<player>` joins with `_`, so ids containing `_` can
collide. Keep ids free of `_`.

## Composing with Other Modules

`npc-state` for disposition derived from reputation rather than fixed flags;
`inventory` for `has_item`.
