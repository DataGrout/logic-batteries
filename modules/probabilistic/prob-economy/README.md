# Module: prob-economy v1.0.1

Market uncertainty for simulation games. World state — storms, blocked routes,
conflict, season — becomes a probability that an item's supply is disrupted or
its demand spikes, and those become a price range and an expected price. "What
will iron ingots probably cost with a storm coming?" is one query, no LLM.

**Requires:** `economy`, for `buy_price/2`. `supply_disruption/2`,
`demand_spike/2` and `market_volatility/3` work without it; `price_range/4` and
`expected_price/2` do not.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["economy", "prob-economy"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install_many({"economy", "prob-economy"}, "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `supply_disruption(Item, P)` | The largest matching supply rule's weight; 0.0 when none matches |
| `demand_spike(Item, P)` | The largest matching demand rule's weight; 0.0 when none matches |
| `market_volatility(Item, Ps, Pd)` | Both at once |
| `price_range(Item, Base, Low, High)` | `Base` from `economy`; `Low = Base × (1 − Ps × 0.35)`, `High = Base × (1 + Pd × 0.55)`, rounded |
| `expected_price(Item, Price)` | `Base × (1 − Ps × 0.2 + Pd × 0.3)`, rounded |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `import_dependent` | item | `true` | Supply is disrupted by storms (0.65), a blocked trade route (0.50) and winter (0.25) |
| `perishable` | item | `true` | Supply is disrupted by storms (0.40) and summer (0.30) |
| `category` | item | `healing` \| `weapons` \| `food` \| `tools` | Selects which demand rules apply: healing spikes on conflict (0.75) or rising threat (0.55); weapons on conflict (0.60) or threat (0.45); food in winter (0.35); tools when the route is blocked (0.50). Any other category never spikes |
| `weather` | `world` | `storm` | Supply condition |
| `season` | `world` | `winter` \| `summer` | Supply and demand condition |
| `trade_route_blocked` | `world` | `true` | Supply and demand condition |
| `recent_conflict` | `world` | `true` | Demand condition |
| `threat_rising` | `world` | `true` | Demand condition |

`world` is a fixed entity name; the `world` battery maintains `weather` and
`season`. An item also needs `economy`'s `base_price` for the two price
predicates.

**Two models.** The ProbLog clauses `supply_disruption/1` and `demand_spike/1`
carry the weights above for marginal inference. The deterministic
`supply_disruption/2` and `demand_spike/2` return the *largest* single matching
weight — they do not combine rules, so an import-dependent item in a winter
storm reads 0.65, not more.

## Setup

```
# Items
{ type="attribute", entity="iron_ingot",    attribute="base_price",       value=20 }
{ type="attribute", entity="iron_ingot",    attribute="import_dependent", value=true }
{ type="attribute", entity="health_potion", attribute="base_price",       value=40 }
{ type="attribute", entity="health_potion", attribute="category",         value="healing" }

# The world, kept current by you
{ type="attribute", entity="world", attribute="weather",         value="storm" }
{ type="attribute", entity="world", attribute="recent_conflict", value=true }
```

## Querying

```
# Ingots in a storm: supply 0.65, no demand rule
price_range(iron_ingot, Base, Low, High)
   Base = 20, Low = 15, High = 20
expected_price(iron_ingot, P)
   P = 17

# Potions after a fight: no supply rule, demand 0.75
market_volatility(health_potion, Ps, Pd)
   Ps = 0.0, Pd = 0.75
price_range(health_potion, Base, Low, High)
   Base = 40, Low = 40, High = 56

# Marginal, through ProbLog
probability(supply_disruption(iron_ingot), P)
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "price_range(iron_ingot, B, L, H)", function(r) if r[1] then showRange(r[1].L, r[1].H) end end)
```

## Supply Disruption Rules

| Condition | Weight |
|---|---|
| `import_dependent` + `weather = storm` | 0.65 |
| `import_dependent` + `trade_route_blocked` | 0.50 |
| `import_dependent` + `season = winter` | 0.25 |
| `perishable` + `weather = storm` | 0.40 |
| `perishable` + `season = summer` | 0.30 |

## Demand Spike Rules

| Condition | Weight |
|---|---|
| `category = healing` + `recent_conflict` | 0.75 |
| `category = healing` + `threat_rising` | 0.55 |
| `category = weapons` + `recent_conflict` | 0.60 |
| `category = weapons` + `threat_rising` | 0.45 |
| `category = food` + `season = winter` | 0.35 |
| `category = tools` + `trade_route_blocked` | 0.50 |

## Semantics worth knowing

**Disruption lowers the floor.** As written, supply disruption widens the range
*downward* (`Low = Base × (1 − Ps × 0.35)`) and only demand raises the ceiling.
If your economy wants scarcity to raise prices, that is a rule to change, not a
reading to reinterpret; `expected_price` has the same sign.

**Max, not combination.** Several matching rules do not stack in the
deterministic predicates; only the ProbLog marginals combine evidence.

**No rule, no risk.** An item with no `import_dependent`, `perishable` or
recognised `category` reads 0.0 on both sides and its range collapses to the
base price.
