# Module: pricing-rules v1.0.0

Customer tier pricing, percentage and flat discounts, tier-gated discounts, bulk quantity breaks, floor/ceiling clamping, and final effective price calculation. Compose the pieces you need — not all configuration is required.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["pricing-rules"],
    "namespace": "my-namespace"
})
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `effective_price(Item, Customer, Price)` | Final price after tier multiplier and all applicable discounts |
| `price_capped(Item, Customer, Price)` | Effective price clamped to configured floor/ceiling |
| `price_tier(Item, Customer, Tier)` | Customer's pricing tier: `standard`/`member`/`vip` |
| `discount_applicable(Item, Discount)` | A discount rule applies to Item |
| `bulk_discount(Item, Qty, PctOff)` | Percentage discount for purchasing Qty units |

## Tier Multipliers

| Tier | Default multiplier |
|---|---|
| `standard` | 1.0 (no discount) |
| `member` | 0.9 (10% off) |
| `vip` | 0.8 (20% off) |

Override:
```
{ type="attribute", entity="pricing", attribute="vip_multiplier", value=0.75 }
```

## Setup

### Item base price

```
{ type="attribute", entity="widget", attribute="base_price",  value=100 }
{ type="attribute", entity="widget", attribute="price_floor", value=50  }
{ type="attribute", entity="widget", attribute="price_ceil",  value=200 }
```

### Customer tier

```
{ type="attribute", entity="customer_123", attribute="pricing_tier", value="vip" }
```

### Discount rules

```
# Percentage discount
{ type="relation", subject="widget", relation="has_discount", object="summer_sale" }
{ type="attribute", entity="summer_sale", attribute="pct_off", value=20 }

# Flat discount
{ type="relation", subject="widget", relation="has_discount", object="loyalty_coupon" }
{ type="attribute", entity="loyalty_coupon", attribute="flat_off", value=10 }

# Tier-gated discount (only applies if customer is member or vip)
{ type="relation", subject="widget", relation="has_discount", object="member_sale" }
{ type="attribute", entity="member_sale", attribute="pct_off",        value=15   }
{ type="attribute", entity="member_sale", attribute="requires_tier",  value="member" }
```

### Bulk quantity breaks

Up to 5 tiers, numbered `bulk_qty_N` / `bulk_pct_N`:

```
{ type="attribute", entity="widget", attribute="bulk_qty_1", value=10 }
{ type="attribute", entity="widget", attribute="bulk_pct_1", value=5  }
{ type="attribute", entity="widget", attribute="bulk_qty_2", value=50 }
{ type="attribute", entity="widget", attribute="bulk_pct_2", value=15 }
```

`bulk_discount` returns the highest percentage the quantity qualifies for (not additive).

## Querying

```
# Final price for a customer
effective_price(widget, customer_123, Price)

# Price with floor/ceiling enforced
price_capped(widget, customer_123, Price)

# What tier is this customer?
price_tier(widget, customer_123, Tier)

# Bulk discount for a given order quantity
bulk_discount(widget, 25, PctOff)
```

## Calculation Order

1. Apply tier multiplier to base price → `TierPrice`
2. Sum all applicable discount amounts (flat or pct of base)
3. `FinalPrice = max(0, TierPrice - TotalDiscounts)`
4. If `price_capped` is used, clamp to `[floor, ceil]`

## Agent Use Cases

**Quote agent**: When asked for a price, the agent queries `effective_price` for the customer's tier and current promotions — no need to embed pricing logic in the prompt.

**Promotion management**: Add or remove discount rules by asserting or retracting `relation(item, has_discount, rule)` facts. The change is live immediately.

**Bulk order advisor**: An agent can call `bulk_discount(item, Qty, Pct)` with increasing quantities to find the break-even point for a discount tier and recommend order sizing.
