# Module: loyalty v1.0.0

Lifetime points accumulation, tier derivation, reduced redemption costs at higher tiers, reward eligibility, and inherited tier benefits. The tier a customer holds determines both their status benefits and how cheaply they can redeem rewards.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["loyalty"],
    "namespace": "my-namespace"
})
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `loyalty_tier(Customer, Tier)` | Tier is `bronze`/`silver`/`gold`/`platinum` based on lifetime points |
| `points_balance(Customer, Points)` | Current redeemable points (lifetime earned minus redeemed) |
| `reward_eligible(Customer, Reward)` | Customer has enough points for Reward at their tier's discount |
| `points_to_redeem(Customer, Reward, Points)` | Points required, adjusted for tier multiplier |
| `tier_benefit(Customer, Benefit, Value)` | A named benefit the customer receives at their tier |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `lifetime_points` | customer | integer | Total ever earned; sets the tier and is the base of the balance |
| `redeemed_points` | customer | integer | Total ever redeemed; default 0. Balance is `lifetime_points − redeemed_points` |
| `points_cost` | reward | integer | Base cost before the tier multiplier; `points_to_redeem` is `ceiling(cost × multiplier)` |
| `benefit_value` | benefit | any | The value `tier_benefit` returns for a benefit the customer's tier grants |
| `platinum_threshold` | `loyalty` | integer | Lifetime points for platinum; default 5000 |
| `gold_threshold` | `loyalty` | integer | Default 2000 |
| `silver_threshold` | `loyalty` | integer | Default 500. Below is bronze |
| `platinum_redemption_multiplier` | `loyalty` | fraction | Default 0.7 |
| `gold_redemption_multiplier` | `loyalty` | fraction | Default 0.85 |
| `silver_redemption_multiplier` | `loyalty` | fraction | Default 1.0. Bronze is fixed at 1.0 and cannot be overridden |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `has_benefit` | tier → benefit | Grants the benefit at that tier and every tier above it: platinum receives gold's, silver's and bronze's benefits too. Tiers are the atoms `platinum`, `gold`, `silver`, `bronze` |

`loyalty` is a fixed entity name for thresholds and multipliers; each is
optional and overrides its default individually.

## Default Tier Thresholds

| Tier | Lifetime points required |
|---|---|
| `platinum` | ≥ 5000 |
| `gold` | ≥ 2000 |
| `silver` | ≥ 500 |
| `bronze` | < 500 |

Override:
```
{ type="attribute", entity="loyalty", attribute="gold_threshold", value=3000 }
```

## Default Redemption Multipliers

Higher tiers need fewer points to redeem rewards:

| Tier | Multiplier |
|---|---|
| `bronze` / `silver` | 1.0 (full cost) |
| `gold` | 0.85 (15% fewer points) |
| `platinum` | 0.7 (30% fewer points) |

## Setup

### Customer points

```
{ type="attribute", entity="customer_123", attribute="lifetime_points", value=2500 }
{ type="attribute", entity="customer_123", attribute="redeemed_points", value=500  }
```

### Rewards catalog

```
{ type="attribute", entity="free_coffee",   attribute="points_cost", value=100 }
{ type="attribute", entity="free_shipping", attribute="points_cost", value=200 }
```

### Tier benefits

Benefits are attached to tiers via relations. Higher tiers automatically inherit benefits from lower tiers via `tier_outranks`:

```
{ type="relation", subject="gold",     relation="has_benefit", object="early_access"      }
{ type="attribute", entity="early_access",      attribute="benefit_value", value=true      }

{ type="relation", subject="platinum", relation="has_benefit", object="dedicated_support" }
{ type="attribute", entity="dedicated_support", attribute="benefit_value", value=true      }
```

A platinum customer automatically has both `early_access` (gold benefit) and `dedicated_support` (platinum benefit).

## Querying

```
# What tier is this customer?
loyalty_tier(customer_123, Tier)

# How many redeemable points do they have?
points_balance(customer_123, Balance)

# Can they get free shipping?
reward_eligible(customer_123, free_shipping)

# How many points would it cost at their tier?
points_to_redeem(customer_123, free_shipping, Cost)

# What benefits do they receive?
tier_benefit(customer_123, Benefit, Value)
```

## Agent Use Cases

**Redemption agent**: When a customer asks to redeem a reward, check `reward_eligible` first. If eligible, record the redemption by updating `redeemed_points`. The balance and eligibility recalculate on the next query.

**Tier promotion agent**: After any purchase that adds points, query `loyalty_tier`. If it changed, trigger a tier-up notification and assert any new benefits. No tier transition logic needed in code.

**Benefit query agent**: "What perks do I have?" → `tier_benefit(customer, Benefit, Value)` returns all applicable benefits including inherited ones from lower tiers.
