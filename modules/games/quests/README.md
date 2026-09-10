# Module: quests v1.0.0

Quest availability, prerequisites, ordered objectives, and turn-in. Everything
here is derived from facts you assert; the battery itself writes nothing.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["quests"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("quests", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `quest_available(Player, Quest)` | Quest exists, Player has not started or finished it, and every prerequisite is met |
| `quest_in_progress(Player, Quest)` | Player has accepted Quest and not completed it |
| `quest_complete(Player, Quest)` | Player has completed Quest |
| `next_objective(Player, Quest, Obj)` | The lowest-`order` objective of Quest that Player has not completed |
| `quest_blocked_by(Player, Quest, Reason)` | Why Quest is not available — see reasons below |
| `can_turn_in(Player, Quest)` | In progress and no objective left |

`quest_blocked_by/3` reasons: `'already complete'`, `requires_quest(Q)`,
`requires_level(L)`, `requires_item(I)`.

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `requires_quest` | quest | a quest id | Prerequisite: the player must have completed this quest first |
| `requires_level` | quest | integer | Prerequisite: the player's `level` must be at least this |
| `requires_item` | quest | an item id | Prerequisite: the player must hold this item (`has_item`) |
| `quest` | objective | a quest id | Which quest the objective belongs to |
| `order` | objective | integer | Position in the quest; `next_objective` returns the lowest incomplete |
| `level` | player | integer | Checked against `requires_level`. A player with no level cannot take any level-gated quest |
| `status` | `<player>_<quest>` | `in_progress` \| `complete` | The player's progress on the quest. Assert `in_progress` on accept, `complete` on turn-in |
| `complete` | `<player>_<objective>` | `true` | The player has finished this objective |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `quest_exists` | `world` → quest | Registers a quest. Only quests with this relation are ever available |
| `has_item` | player → item | Satisfies a `requires_item` prerequisite |

Player-specific state lives on a composite entity: the player id and the quest
or objective id joined with `_` (`alice_slay_dragon`, `alice_slay_dragon_obj1`).
Keep ids free of `_` or accept that `alice_b` + `dragon` and `alice` + `b_dragon`
collide.

Anything else you attach to a quest or objective — `description`, rewards, a
giver — is yours to read; this battery does not look at it.

## Setup

```
# The quest exists
{ type="relation",  subject="world",       relation="quest_exists",   object="slay_dragon" }

# Prerequisites (each optional)
{ type="attribute", entity="slay_dragon",  attribute="requires_level", value=10 }
{ type="attribute", entity="slay_dragon",  attribute="requires_quest", value="find_sword" }
{ type="attribute", entity="slay_dragon",  attribute="requires_item",  value="dragon_bane" }

# Objectives, in order
{ type="attribute", entity="slay_dragon_obj1", attribute="quest", value="slay_dragon" }
{ type="attribute", entity="slay_dragon_obj1", attribute="order", value=1 }
{ type="attribute", entity="slay_dragon_obj2", attribute="quest", value="slay_dragon" }
{ type="attribute", entity="slay_dragon_obj2", attribute="order", value=2 }

# The player
{ type="attribute", entity="alice", attribute="level", value=12 }
{ type="relation",  subject="alice", relation="has_item", object="dragon_bane" }
```

As the player progresses:

```
# alice accepts the quest
{ type="attribute", entity="alice_slay_dragon",      attribute="status",   value="in_progress" }

# alice finishes the first objective
{ type="attribute", entity="alice_slay_dragon_obj1", attribute="complete", value=true }

# alice turns the quest in
{ type="attribute", entity="alice_slay_dragon",      attribute="status",   value="complete" }
```

## Querying

```
# What can alice take on right now?
quest_available(alice, Quest)

# Why not this one?
quest_blocked_by(alice, slay_dragon, Reason)
   Reason = requires_quest(find_sword)

# What is she meant to do next?
next_objective(alice, slay_dragon, Obj)
   Obj = slay_dragon_obj2

# Ready to hand in?
can_turn_in(alice, slay_dragon)
```

The same from Tether, for a game loop that already speaks it:

```lua
dg:assert("my-game", { type="attribute", entity="alice_slay_dragon", attribute="status", value="in_progress" })
dg:query("my-game", "next_objective(alice, slay_dragon, Obj)", function(r) if r[1] then track(r[1].Obj) end end)
```

## Semantics worth knowing

**Availability needs a status fact to move on.** A quest stays `quest_available`
until you assert `status = in_progress`; asserting objective completions alone
does not start it, and `can_turn_in` requires it to have been started.

**A level requirement with no player level is a silent block.** If a quest has
`requires_level` and the player has no `level` fact, the quest is unavailable
and `quest_blocked_by` returns no reason — the comparison has nothing to
compare. Assert a level for every player.

**Objectives are ordered, not sequenced.** `next_objective` is the lowest
`order` not yet complete; completing objective 2 before 1 is allowed and
`next_objective` will still point at 1. Ties in `order` return both.

**Prerequisites are all-of.** Every `requires_*` present must hold. A quest with
none is available to anyone.

## What this battery does not do

- No rewards, XP, or unlocks on completion — see `progression`.
- No quest chains beyond a single `requires_quest`; chain by asserting one on each link.
- No repeatable or timed quests; a completed quest stays complete.
- No objective counters (`kill 5 wolves`) — an objective is complete or not. Count upstream and assert `complete` when done.
