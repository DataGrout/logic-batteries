# Module: d20-xp v1.0.0

SRD 5.1 encounter building. Full XP-by-CR table (CR 0–30), difficulty thresholds
per party level (easy/medium/hard/deadly), action-economy XP multiplier, and
encounter difficulty rating. With `d20-monsters` installed, rate an encounter
by monster name list in one query.

All mechanics are from the **SRD 5.1**, published under **CC BY 4.0** by Wizards of the Coast LLC.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["d20-xp"],
    "namespace": "my-campaign"
})
# For name-based difficulty queries, also install d20-monsters:
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["d20-xp", "d20-monsters"],
    "namespace": "my-campaign"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `xp_for_cr(CR, XP)` | Base XP for a monster of this CR (CR 0–30) |
| `encounter_threshold(PartyLevel, Difficulty, XPPerPlayer)` | SRD threshold table |
| `xp_multiplier(MonsterCount, Multiplier)` | Action-economy multiplier (1–4×) |
| `adjusted_xp(XPList, AdjustedTotal, Multiplier)` | Total XP after multiplier |
| `encounter_difficulty(PartyLevel, PartySize, XPList, Difficulty)` | trivial/easy/medium/hard/deadly |
| `party_encounter_difficulty(Level, Size, MonsterNames, Difficulty)` | Name-based (requires d20-monsters) |

## Usage

```python
# How hard is 2 skeletons + 1 shadow for a 4-person level-3 party?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "party_encounter_difficulty(3, 4, [skeleton, skeleton, shadow], Difficulty)"
})
# → Difficulty = hard

# What XP does a CR 5 monster award?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "xp_for_cr(5, XP)"
})
# → XP = 1800

# What's the deadly threshold for a level-5 party?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "encounter_threshold(5, deadly, Thresh)"
})
# → Thresh = 1100 (per player)

# Compute adjusted XP for 6 goblins (50 XP each, ×2 multiplier for 3–6 monsters)
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "adjusted_xp([50,50,50,50,50,50], Adj, Mult)"
})
# → Adj = 600, Mult = 2.0

# Build a medium encounter for 4 level-3 players — what's the XP budget?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "encounter_threshold(3, medium, PerPlayer), Budget is PerPlayer * 4"
})
# → Budget = 600 total (before monster count multiplier)
```

## XP Multiplier Table

| Monsters | Multiplier |
|---|---|
| 1 | ×1 |
| 2 | ×1.5 |
| 3–6 | ×2 |
| 7–10 | ×2.5 |
| 11–14 | ×3 |
| 15+ | ×4 |
