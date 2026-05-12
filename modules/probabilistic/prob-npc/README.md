# Module: prob-npc v1.0.0

Probabilistic NPC belief and trust. Models how likely an NPC is to trust a player, share information, assist with tasks, and offer discounts — all driven by faction standing and relationship score. Agents query trust and disposition without token cost instead of asking the LLM to guess.

**Requires:** `npc-state` and `faction` installed in the same namespace.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["npc-state", "faction", "prob-npc"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install_many({"npc-state", "faction", "prob-npc"}, "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `trust_probability(NPC, Player, P)` | P is probability (0.0–1.0) NPC trusts Player |
| `will_share_info(NPC, Player, Topic)` | Probabilistic: NPC shares Topic with Player |
| `will_assist(NPC, Player, Task)` | Probabilistic: NPC helps Player with Task |
| `npc_price_modifier(NPC, Player, Mod)` | Price multiplier (0.70–1.30); below 1.0 = discount |
| `disposition_probability(NPC, Player, P)` | Overall probability NPC responds positively |

## Setup

```lua
-- NPC faction membership
dg:assert("my-game", { type="attribute", entity="merchant_npc", attribute="faction", value="traders_guild" })

-- Player faction reputation (handled by faction battery)
dg:assert("my-game", { type="attribute", entity="alice_traders_guild", attribute="score", value=5000 })
-- → faction_standing(alice, traders_guild, friendly) → trust ~0.58

-- Topics the NPC knows (with optional sensitivity)
dg:assert("my-game", { type="relation", subject="merchant_npc", relation="knows_topic", object="trade_routes" })
dg:assert("my-game", { type="attribute", entity="trade_routes", attribute="sensitivity", value="low" })

dg:assert("my-game", { type="relation", subject="merchant_npc", relation="knows_topic", object="secret_supplier" })
dg:assert("my-game", { type="attribute", entity="secret_supplier", attribute="sensitivity", value="secret" })

-- Tasks the NPC can help with
dg:assert("my-game", { type="relation", subject="blacksmith_npc", relation="can_assist", object="forge_weapon" })
dg:assert("my-game", { type="attribute", entity="forge_weapon", attribute="assistance_cost", value="medium" })
```

## Usage

```lua
-- What is the trust probability for a merchant?
dg:query("my-game", "trust_probability(merchant_npc, alice, P)", function(results)
  if results[1] then
    print(string.format("Trust: %.0f%%", results[1].P * 100))
  end
end)

-- What price modifier will this merchant apply?
dg:query("my-game", "npc_price_modifier(merchant_npc, alice, Mod)", function(results)
  if results[1] then
    local mod = results[1].Mod
    if mod < 1.0 then
      print(string.format("%.0f%% discount", (1.0 - mod) * 100))
    else
      print(string.format("%.0f%% markup", (mod - 1.0) * 100))
    end
  end
end)

-- Will this NPC share a sensitive topic?
dg:query("my-game", "probability(will_share_info(merchant_npc, alice, secret_supplier), P)",
  function(results)
    print(string.format("Chance of sharing secret: %.0f%%", results[1].P * 100))
  end)

-- Overall disposition check
dg:query("my-game", "disposition_probability(merchant_npc, alice, P)", function(results)
  setDialoguePortraitMood(results[1].P)  -- 0 = hostile, 1 = warm
end)
```

## Trust by Faction Standing

| Standing | Base trust probability |
|---|---|
| exalted | 0.90 |
| revered | 0.80 |
| honored | 0.70 |
| friendly | 0.55 |
| neutral | 0.35 |
| unfriendly | 0.10 |
| hostile | 0.02 |

Personal relationship score (from `npc-state`) boosts trust by up to +20% on top of the faction baseline.

## Information Sharing by Sensitivity

| Topic sensitivity | Minimum trust + relationship |
|---|---|
| none / low | npc_trusts |
| medium | npc_trusts + relationship ≥ 25 |
| high | npc_trusts + relationship ≥ 60 |
| secret | npc_trusts + relationship ≥ 90 |

Base probability for each tier: 0.90 / 0.75 / 0.50 / 0.25 / 0.05.

## Price Modifier Formula

`Mod = clamp(1.0 − (trust − 0.5) × 0.4, 0.70, 1.30)`

At 90% trust → Mod ≈ 0.84 (16% discount). At 10% trust → Mod ≈ 1.16 (16% markup).
