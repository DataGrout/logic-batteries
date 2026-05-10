# Module: inventory-mgmt v1.0.0

Stock level classification, reorder triggers, order quantity calculation, preferred supplier selection, and days-of-stock forecasting. Assert current stock levels and usage rates; query the rules to drive replenishment workflows.

## Install

Add to your DataGrout logic cell via the Hub, or load the raw Prolog directly.

## Exported Predicates

| Predicate | Description |
|---|---|
| `stock_level(Item, Level)` | Level is `adequate`/`low`/`critical`/`stockout` |
| `needs_reorder(Item)` | Item is at or below its reorder threshold |
| `reorder_quantity(Item, Qty)` | Recommended order quantity |
| `preferred_supplier(Item, Supplier)` | Preferred source for Item |
| `days_of_stock(Item, Days)` | Estimated days until stockout at current usage rate |

## Stock Level Classification

| Level | Condition |
|---|---|
| `stockout` | Stock ≤ 0 |
| `critical` | Stock ≤ critical threshold (default: half of reorder threshold) |
| `low` | Stock ≤ reorder threshold |
| `adequate` | Everything else |

`needs_reorder` succeeds for `stockout`, `critical`, and `low`.

## Setup

```
# Stock facts for an item
{ type="attribute", entity="coffee_beans", attribute="stock",             value=80  }
{ type="attribute", entity="coffee_beans", attribute="reorder_threshold", value=20  }
{ type="attribute", entity="coffee_beans", attribute="reorder_quantity",  value=100 }
{ type="attribute", entity="coffee_beans", attribute="max_stock",         value=200 }
{ type="attribute", entity="coffee_beans", attribute="daily_usage",       value=15  }

# Override critical threshold (default: reorder_threshold / 2)
{ type="attribute", entity="coffee_beans", attribute="critical_threshold", value=10 }
```

### Suppliers

```
{ type="relation", subject="coffee_beans", relation="supplied_by",   object="acme_roasters"    }
{ type="attribute", entity="acme_roasters", attribute="preferred",     value=true               }
{ type="attribute", entity="acme_roasters", attribute="lead_time_days", value=3                }

{ type="relation", subject="coffee_beans", relation="supplied_by",   object="generic_supplier" }
```

`preferred_supplier` returns the supplier marked `preferred=true` first; falls back to any `supplied_by` relation.

### Reorder quantity fallback

If no `reorder_quantity` is set, the module calculates `max_stock - current_stock`. If `max_stock` is also absent, it defaults to 50.

## Querying

```
# Check current stock level
stock_level(coffee_beans, Level)

# Find all items that need reordering
needs_reorder(Item)

# Get recommended order and supplier
reorder_quantity(coffee_beans, Qty)
preferred_supplier(coffee_beans, Supplier)

# How many days before stockout?
days_of_stock(coffee_beans, Days)
```

## Agent Use Cases

**Replenishment agent**: Nightly job calls `needs_reorder(Item)` across all items, then `reorder_quantity` and `preferred_supplier` to generate purchase orders. All the business logic lives in the LC — the agent just acts on the answers.

**Forecasting agent**: `days_of_stock` gives a simple horizon. Items with `Days < lead_time_days` need urgent action — the agent can surface these proactively.

**Update pattern**: When stock changes, retract the old `stock` attribute and assert the new value. The level classification and reorder triggers update automatically on the next query.
