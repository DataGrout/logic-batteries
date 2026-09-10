# Module: progression v1.0.0

Levels from XP along a configurable curve, stats that scale with level,
level-gated unlocks, and prestige conditions.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["progression"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("progression", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `level_for_xp(XP, Level)` | The highest level whose cumulative XP is at most XP, capped at `max_level` |
| `xp_to_next_level(Player, Needed)` | XP still needed for the next level; fails at max level |
| `stat_at_level(Stat, Level, Value)` | A per-level override if one exists, else the stat's curve |
| `unlock_available(Player, Unlock)` | The player's level meets `unlock_at_level`, and the class gate if any |
| `can_prestige(Player)` | The configured level condition holds, and the quest gate if any |

A player's level is the `level` attribute when present, otherwise derived from
`xp`. Assert one or the other, not both.

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `xp` | player | integer | Total experience; the level is derived from it when no `level` is set. Absent reads as 0 |
| `level` | player | integer | Explicit level; takes precedence over `xp` |
| `class` | player | a class id | Matched against `unlock_requires_class` |
| `type` | `xp_curve` | `linear` \| `exponential` | Which formula; default `linear` |
| `base_xp` | `xp_curve` | integer | XP from level 1 to 2; default 100 |
| `increment` | `xp_curve` | integer | Linear: each further level costs this much more; default 50 |
| `multiplier` | `xp_curve` | number | Exponential: each further level costs this times more; default 1.5 |
| `max_level` | `xp_curve` | integer | Cap; default 100 |
| `xp_required` | `level_<N>` | integer | Cumulative XP to reach level N, on an *entity* named `level_2`, `level_3`, …; overrides the curve for that level |
| `base_value` | stat | number | The stat's value at level 1; default 0 (linear) or 1 (exponential) |
| `per_level` | stat | number | Linear: added per level above 1; default 0 |
| `scale` | stat | `exponential` | Switches the stat to `base × multiplier^(level−1)` |
| `multiplier` | stat | number | Exponential stat growth; default 1.1 |
| `level_<N>` | stat | number | Exact value at level N, as an *attribute* named `level_5` on the stat; overrides the formula |
| `unlock_at_level` | unlock | integer | The level at which the unlock becomes available |
| `unlock_requires_class` | unlock | a class id | Optional: the player's `class` must match |
| `requires_max_level` | `prestige` | `true` | Prestige needs the player at `max_level` |
| `requires_level` | `prestige` | integer | Or at least this level. One of the two must be set or nobody can prestige |
| `requires_quest` | `prestige` | a quest id | Optional quest gate |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `completed_quest` | player → quest | Satisfies `requires_quest` |

`xp_curve` and `prestige` are fixed entity names. Note the two different
`level_<N>` shapes: for XP breakpoints it is an *entity* carrying
`xp_required`; for stat overrides it is an *attribute name* on the stat.

## Setup

```
# The curve: level 2 at 100, then +50 per level (250, 450, 700, …)
{ type="attribute", entity="xp_curve", attribute="type",      value="linear" }
{ type="attribute", entity="xp_curve", attribute="base_xp",   value=100 }
{ type="attribute", entity="xp_curve", attribute="increment", value=50 }
{ type="attribute", entity="xp_curve", attribute="max_level", value=50 }

# Or hand-placed breakpoints for particular levels
{ type="attribute", entity="level_10", attribute="xp_required", value=5000 }

# Stats
{ type="attribute", entity="strength",    attribute="base_value", value=10 }
{ type="attribute", entity="strength",    attribute="per_level",  value=5 }
{ type="attribute", entity="magic_power", attribute="scale",      value="exponential" }
{ type="attribute", entity="magic_power", attribute="base_value", value=10 }
{ type="attribute", entity="magic_power", attribute="multiplier", value=1.2 }
{ type="attribute", entity="max_hp",      attribute="level_3",    value=220 }

# Unlocks
{ type="attribute", entity="double_jump", attribute="unlock_at_level",       value=5 }
{ type="attribute", entity="fireball",    attribute="unlock_at_level",       value=10 }
{ type="attribute", entity="fireball",    attribute="unlock_requires_class", value="mage" }

# Prestige
{ type="attribute", entity="prestige", attribute="requires_max_level", value=true }
{ type="attribute", entity="prestige", attribute="requires_quest",     value="defeat_final_boss" }

# The player
{ type="attribute", entity="alice", attribute="xp",    value=850 }
{ type="attribute", entity="alice", attribute="class", value="mage" }
```

## Querying

```
# Level from raw XP
level_for_xp(850, L)
   L = 5

# How far to the next?
xp_to_next_level(alice, Needed)
   Needed = 150

# A stat at that level
stat_at_level(strength, 5, V)
   V = 30

# What has she unlocked?
unlock_available(alice, U)
   U = double_jump

# Ready to prestige?
can_prestige(alice)
   false
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "unlock_available(alice, U)", function(rs) for _, r in ipairs(rs) do grantUnlock(r.U) end end)
```

## Semantics worth knowing

**Unlocks gate on `unlock_at_level`, not `requires_level`.** `requires_level`
is read only on the `prestige` entity. An unlock carrying `requires_level` is
never available.

**Breakpoints end the curve.** `level_for_xp` walks upward and stops at the
first level whose cumulative XP it cannot compute; it does not skip gaps. If you
mix breakpoints and a curve, the curve fills every level you did not place.

**`xp_to_next_level` means two things.** With `xp` asserted it is the gap from
current XP to the next threshold; with only `level` asserted it is the full
cost of the next level.

**Prestige needs a level rule.** With neither `requires_max_level` nor
`requires_level` on `prestige`, `can_prestige` fails for everyone.

## Composing with Other Modules

`combat` reads stat values you derive here; `quests` asserts
`completed_quest`; `crafting` reads the player's `level` for discovery.
