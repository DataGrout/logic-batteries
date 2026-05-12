# Module: prob-loot v1.0.0

Probabilistic drop resolution. Wraps `loot-tables` with ProbLog-annotated rarity probabilities so agents can query the actual probability of a drop, compute expected yields, and build UIs that show "Boss Key: 15% drop rate" without any token cost.

**Requires:** `loot-tables` installed in the same namespace.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["loot-tables", "prob-loot"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install_many({"loot-tables", "prob-loot"}, "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `drop_occurs(Source, Item)` | Probabilistic: Item drops from Source (use with ProbLog inference) |
| `drop_probability(Source, Item, P)` | P is the base probability (0.0–1.0) that Item drops from Source |
| `expected_drops(Source, Item, N, Expected)` | Expected number of drops from N kills |

## Default Probabilities by Rarity

| Tier | Probability |
|---|---|
| common | 0.90 (90%) |
| uncommon | 0.65 (65%) |
| rare | 0.35 (35%) |
| epic | 0.10 (10%) |
| legendary | 0.15 (15%) |

Override per-item with an explicit `drop_chance` attribute (0–100).

## Setup

```lua
-- Install both batteries
dg:batteries().install_many({"loot-tables", "prob-loot"}, "my-game")

-- Register what a source can drop (via loot-tables)
dg:assert("my-game", { type="relation", subject="warden_boss", relation="can_drop", object="boss_key" })
dg:assert("my-game", { type="relation", subject="warden_boss", relation="can_drop", object="gold_coin" })

-- Set rarity
dg:assert("my-game", { type="attribute", entity="boss_key", attribute="rarity", value="legendary" })
dg:assert("my-game", { type="attribute", entity="gold_coin", attribute="rarity", value="common" })
```

## Usage

```lua
-- What is the probability that boss_key drops?
dg:query("my-game", "drop_probability(warden_boss, boss_key, P)", function(results)
  if results[1] then
    print("Boss Key drop rate: " .. math.floor(results[1].P * 100) .. "%")
    -- → "Boss Key drop rate: 15%"
  end
end)

-- How many kills to expect a drop?
dg:query("my-game", "expected_drops(warden_boss, boss_key, 100, E)", function(results)
  print("Expected boss keys from 100 kills: " .. results[1].E)
  -- → 15.0
end)

-- ProbLog inference: is this drop occurring in this instance?
-- (requires ProbLog; returns probability bound to P)
dg:query("my-game", "probability(drop_occurs(warden_boss, boss_key), P)", function(results)
  print("Marginal probability: " .. results[1].P)
end)
```

## Composing with Other Batteries

`prob-loot` reads the same `drops/2` and `rarity_tier/2` predicates that `loot-tables` defines. Assert loot tables using the `loot-tables` fact format; `prob-loot` automatically sees them.

Install both batteries then query either deterministic (`drops/2`, `loot_chance/3`) or probabilistic (`drop_occurs/2`, `drop_probability/3`) predicates from the same namespace.
