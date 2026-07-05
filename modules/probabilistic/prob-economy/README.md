# Module: prob-economy v1.0.1

Market uncertainty for simulation games. Models supply disruption and demand spike probabilities driven by world state, then derives price ranges and expected prices. Agents can query "what is the probable price range for iron ingots given an incoming storm?" without any LLM calls.

**Requires:** `economy` installed in the same namespace.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["economy", "prob-economy"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install_many({"economy", "prob-economy"}, "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `supply_disruption(Item, P)` | P is probability (0.0–1.0) supply is disrupted given current world state |
| `demand_spike(Item, P)` | P is probability demand is elevated |
| `price_range(Item, Base, Low, High)` | Probable price bounds under current conditions |
| `market_volatility(Item, Ps, Pd)` | Both disruption and demand probabilities in one call |
| `expected_price(Item, Price)` | Expected buy price weighting supply/demand shifts |

## Setup

```lua
-- Item traits
dg:assert("my-game", { type="attribute", entity="iron_ingot", attribute="base_price", value=20 })
dg:assert("my-game", { type="attribute", entity="iron_ingot", attribute="import_dependent", value=true })
dg:assert("my-game", { type="attribute", entity="iron_ingot", attribute="category", value="materials" })

dg:assert("my-game", { type="attribute", entity="health_potion", attribute="base_price", value=40 })
dg:assert("my-game", { type="attribute", entity="health_potion", attribute="category", value="healing" })

-- World state (update at runtime)
dg:assert("my-game", { type="attribute", entity="world", attribute="weather", value="storm" })
dg:assert("my-game", { type="attribute", entity="world", attribute="recent_conflict", value=true })
```

## Usage

```lua
-- What is the price range for iron ingots during a storm?
dg:query("my-game", "price_range(iron_ingot, Base, Low, High)", function(results)
  if results[1] then
    local r = results[1]
    print(string.format("Iron ingots: base %dg, probable range %d–%dg", r.Base, r.Low, r.High))
    -- "Iron ingots: base 20g, probable range 13–20g" (supply disruption, no demand spike)
  end
end)

-- Full market analysis
dg:query("my-game", "market_volatility(health_potion, Ps, Pd)", function(results)
  if results[1] then
    local r = results[1]
    print(string.format("Health potions — supply risk: %.0f%%, demand pressure: %.0f%%",
      r.Ps * 100, r.Pd * 100))
  end
end)

-- Expected price for purchase decisions
dg:query("my-game", "expected_price(iron_ingot, P)", function(results)
  print("Expected price: " .. results[1].P .. "g")
end)
```

## Supply Disruption Rules

| Condition | Probability |
|---|---|
| `import_dependent` + `weather=storm` | 0.65 |
| `import_dependent` + `trade_route_blocked` | 0.50 |
| `import_dependent` + `season=winter` | 0.25 |
| `perishable` + `weather=storm` | 0.40 |
| `perishable` + `season=summer` | 0.30 |

## Demand Spike Rules

| Condition | Probability |
|---|---|
| `category=healing` + `recent_conflict` | 0.75 |
| `category=healing` + `threat_rising` | 0.55 |
| `category=weapons` + `recent_conflict` | 0.60 |
| `category=weapons` + `threat_rising` | 0.45 |
| `category=food` + `season=winter` | 0.35 |
| `category=tools` + `trade_route_blocked` | 0.50 |

## Price Calculation

- `price_range` Low = `Base × (1 − Ps × 0.35)` — supply squeeze raises cost, not lowers (counterintuitively, scarcity raises price; Low represents the floor under low-volatility conditions)
- `price_range` High = `Base × (1 + Pd × 0.55)` — demand spike ceiling
- `expected_price` = `Base × (1 − Ps × 0.2 + Pd × 0.3)` — weighted expectation
