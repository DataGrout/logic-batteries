# Module: inventory-mgmt v1.0.0

Stock level classification, reorder triggers, order quantity calculation, preferred supplier selection, and days-of-stock forecasting. Assert current stock levels and usage rates; query the rules to drive replenishment workflows.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["inventory-mgmt"],
    "namespace": "my-namespace"
})
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `stock_level(Item, Level)` | Level is `adequate`/`low`/`critical`/`stockout` |
| `needs_reorder(Item)` | Item is at or below its reorder threshold |
| `reorder_quantity(Item, Qty)` | Recommended order quantity |
| `preferred_supplier(Item, Supplier)` | Preferred source for Item |
| `days_of_stock(Item, Days)` | Estimated days until stockout at current usage rate |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `stock` | item | integer | Units on hand. `≤ 0` is `stockout` |
| `reorder_threshold` | item | integer | At or below this the item is `low` and `needs_reorder` |
| `critical_threshold` | item | integer | At or below this the item is `critical`. Default: half of `reorder_threshold`, or 5 when there is neither |
| `reorder_quantity` | item | integer | Recommended order size. When absent, `max_stock − stock`; when that is absent too, 50 |
| `max_stock` | item | integer | Shelf capacity; only used to derive a reorder quantity |
| `daily_usage` | item | integer | Units consumed per day, for `days_of_stock` (`stock // daily_usage`). Absent or zero gives `unknown` |
| `preferred` | supplier | `true` | Marks the supplier `preferred_supplier` returns first; otherwise any `supplied_by` supplier is returned |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `supplied_by` | item → supplier | A supplier of the item |

`lead_time_days` appears in the source comments but no clause reads it.

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
