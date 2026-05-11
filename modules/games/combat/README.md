# Module: combat v1.0.0

Damage calculation, resistances, status effects, turn order, and defeat detection.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["combat"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install("combat", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `effective_damage(Attacker, Target, Base, Final)` | Final damage after resistances, armor, and buffs |
| `can_attack(Attacker, Target)` | True if Attacker may act against Target this turn |
| `status_effect_active(Entity, Effect)` | Entity currently has Effect applied |
| `turn_order(Combatants, Ordered)` | Combatants sorted by speed descending, ties by name |
| `is_defeated(Entity)` | Entity has 0 or fewer HP |
| `resistance(Entity, DamageType, Factor)` | Factor (0.0–2.0) applied to DamageType against Entity |

## Setup

### HP and stats

```lua
dg:assert("my-game", { type="attribute", entity="goblin", attribute="hp",    value=40 })
dg:assert("my-game", { type="attribute", entity="goblin", attribute="speed", value=8  })
dg:assert("my-game", { type="attribute", entity="knight", attribute="hp",    value=120 })
dg:assert("my-game", { type="attribute", entity="knight", attribute="speed", value=5  })
dg:assert("my-game", { type="attribute", entity="knight", attribute="armor", value=10 })
```

### Damage types and resistances

```lua
-- Per-entity resistance/weakness (factor applied to incoming damage of that type)
dg:assert("my-game", { type="attribute", entity="goblin", attribute="resist_fire", value=0.5 }) -- fire does half
dg:assert("my-game", { type="attribute", entity="goblin", attribute="weak_water",  value=2.0 }) -- water does double
dg:assert("my-game", { type="attribute", entity="dragon", attribute="immune_fire", value=0   }) -- fire does nothing

-- Elemental type chart (type-wide interactions)
dg:assert("my-game", { type="relation", subject="fire",      relation="strong_against", object="ice"   })
dg:assert("my-game", { type="relation", subject="lightning", relation="strong_against", object="water" })
dg:assert("my-game", { type="relation", subject="fire",      relation="weak_against",   object="water" })

-- Assign an entity's element
dg:assert("my-game", { type="attribute", entity="ice_golem", attribute="element", value="ice" })
```

### Attacker damage type

```lua
dg:assert("my-game", { type="attribute", entity="fire_mage", attribute="damage_type", value="fire" })
-- default is "physical" if not set
```

### Status effects

```lua
-- Apply a status effect to an entity
dg:assert("my-game", { type="relation", subject="goblin", relation="has_status", object="poisoned" })
dg:assert("my-game", { type="attribute", entity="poisoned", attribute="active", value=true })

-- Stun blocks attacking
dg:assert("my-game", { type="relation", subject="knight", relation="has_status", object="stunned" })
dg:assert("my-game", { type="attribute", entity="stunned", attribute="active",    value=true })
dg:assert("my-game", { type="attribute", entity="stunned", attribute="prevents",  value="attack" })
```

## Usage

```lua
-- Calculate damage before applying it
dg:query("my-game", "effective_damage(fire_mage, ice_golem, 50, Final)", function(results)
  if results[1] then applyDamage("ice_golem", results[1].Final) end
end)

-- Who goes first this round?
dg:query("my-game",
  "turn_order([goblin, knight, fire_mage], Ordered)",
  function(results)
    if results[1] then startTurn(results[1].Ordered) end
  end)

-- Can this entity attack?
dg:query("my-game", "can_attack(knight, goblin)", function(results)
  if #results > 0 then showAttackOption() end
end)

-- Has someone been defeated?
dg:query("my-game", "is_defeated(Entity)", function(results)
  for _, r in ipairs(results) do removeFromCombat(r.Entity) end
end)

-- What is the fire resistance of the ice golem?
dg:query("my-game", "resistance(ice_golem, fire, Factor)", function(results)
  if results[1] then print("Factor: " .. results[1].Factor) end
end)
```

## Resistance Precedence

When multiple rules apply to a single entity + damage type, the module uses the first matching rule in this order:

1. `immune_<type>` attribute → Factor = 0
2. `resist_<type>` attribute → Factor = value
3. `weak_<type>` attribute → Factor = value
4. Type chart (`strong_against` element) → Factor = 2.0
5. Type chart (`weak_against` element) → Factor = 0.5
6. Default → Factor = 1.0

## Composing with Other Modules

Works naturally with `progression` (stat values from `stat_at_level`), `inventory` (equipped weapons set damage type), and `npc-state` (hostile NPCs become valid attack targets).
