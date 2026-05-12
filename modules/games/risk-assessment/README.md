# Module: risk-assessment v1.0.0

Combat risk analysis — survival probability, fight-or-flee recommendations, and encounter breakdowns. Works with the `combat` battery and base HP/damage attributes to give the game (and agents) a zero-token cost way to answer "should my character fight this enemy?"

**Requires:** `combat` installed in the same namespace.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["combat", "risk-assessment"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install_many({"combat", "risk-assessment"}, "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `survival_probability(Player, Enemy, HP, P)` | P is probability (0.0–1.0) Player survives; HP is remaining health |
| `recommended_action(Player, Enemy, Action)` | `fight` if P > 0.6, `flee` otherwise |
| `kills_to_exhaust(Player, Enemy, MaxHP, N)` | N enemies defeatable before Player HP reaches 0 |
| `fight_outcome_summary(Player, Enemy, Turns, Damage, P)` | Full encounter breakdown |

## Setup

```lua
-- Assert character stats
dg:assert("my-game", { type="attribute", entity="player", attribute="hp", value=80 })
dg:assert("my-game", { type="attribute", entity="player", attribute="base_damage", value=15 })

dg:assert("my-game", { type="attribute", entity="goblin", attribute="hp", value=30 })
dg:assert("my-game", { type="attribute", entity="goblin", attribute="base_damage", value=10 })

dg:assert("my-game", { type="attribute", entity="warden_boss", attribute="hp", value=200 })
dg:assert("my-game", { type="attribute", entity="warden_boss", attribute="base_damage", value=45 })
```

## Usage

```lua
-- Should the player fight the goblin?
dg:query("my-game", "recommended_action(player, goblin, Action)", function(results)
  if results[1] then
    print("Recommendation: " .. results[1].Action)  -- "fight"
  end
end)

-- What are the player's odds against the warden boss?
dg:query("my-game", "survival_probability(player, warden_boss, HP, P)", function(results)
  if results[1] then
    local r = results[1]
    print(string.format("Survival chance: %.0f%% | HP remaining: %d", r.P * 100, r.HP))
    -- "Survival chance: 23% | HP remaining: 0"
  end
end)

-- Full breakdown before committing to a fight
dg:query("my-game", "fight_outcome_summary(player, warden_boss, Turns, Damage, P)", function(r)
  if r[1] then
    print(string.format("%d turns to kill | %d damage taken | %.0f%% survival",
      r[1].Turns, r[1].Damage, r[1].P * 100))
  end
end)

-- How many goblins can the player chain-kill before dying?
dg:query("my-game", "kills_to_exhaust(player, goblin, 80, N)", function(results)
  print("Can defeat " .. results[1].N .. " goblins before dying")
end)
```

## How Probability Is Calculated

`survival_probability` simulates a turn-based fight using `base_damage` and `hp` attributes:

1. `TurnsToKill = ceil(EnemyHP / PlayerDamage)` — turns to kill the enemy
2. `DamageTaken = TurnsToKill × EnemyDamage` — total damage received
3. If `DamageTaken < PlayerHP`: `P = 1.0 - (DamageTaken / PlayerHP) × 0.5`
4. If `DamageTaken ≥ PlayerHP` (likely death): `P = max(0.05, ...)`

This is intentionally simple — add `armor`, `dodge_chance`, or `crit_chance` attributes from `combat` to extend it.

## Example Composition In Roblox

```lua
-- Show risk UI when player targets an enemy
local function onEnemyTarget(enemy)
  dg:query("my-game", "fight_outcome_summary(player, " .. enemy .. ", Turns, Damage, P)",
    function(results)
      if results[1] then
        local p = results[1].P
        -- Pulse screen intensity based on survival probability
        setDangerGlow(1.0 - p)  -- red = low survival
        showTooltip(string.format("%.0f%% survival", p * 100))
      end
    end)
end
```
