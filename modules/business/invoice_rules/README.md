# Module: invoice-rules v1.0.0

Overdue detection, days-overdue calculation, late fee computation, escalation level derivation, and total amount due. Assert invoice and billing configuration facts; query the rules to drive collection workflows.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["invoice-rules"],
    "namespace": "my-namespace"
})
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `invoice_overdue(Invoice)` | Invoice is past its due date and unpaid |
| `days_overdue(Invoice, Days)` | Days past due (0 if not overdue) |
| `late_fee(Invoice, Fee)` | Late charge added to the invoice balance |
| `escalation_level(Invoice, Level)` | `reminder`/`warning`/`collections` based on days overdue |
| `payment_due_amount(Invoice, Amount)` | Total now due including any late fee |

## Default Escalation Thresholds

| Level | Trigger |
|---|---|
| `reminder` | Any overdue invoice |
| `warning` | ≥ 15 days overdue |
| `collections` | ≥ 60 days overdue |

Override:
```
{ type="attribute", entity="billing", attribute="warning_days",     value=30 }
{ type="attribute", entity="billing", attribute="collections_days", value=90 }
```

## Setup

### Invoice facts

```
{ type="attribute", entity="inv_001", attribute="amount",    value=1500  }
{ type="attribute", entity="inv_001", attribute="due_year",  value=2026  }
{ type="attribute", entity="inv_001", attribute="due_month", value=3     }
{ type="attribute", entity="inv_001", attribute="due_day",   value=10    }
{ type="attribute", entity="inv_001", attribute="paid",      value=false }
```

### Current date

Assert today's date at runtime:
```
{ type="attribute", entity="today", attribute="year",  value=2026 }
{ type="attribute", entity="today", attribute="month", value=4    }
{ type="attribute", entity="today", attribute="day",   value=25   }
```

**For production billing**, use absolute day counts to avoid the ~1-day approximation error from the month-length simplification (all months treated as 30 days):
```
{ type="attribute", entity="today",   attribute="absolute_days",     value=738970 }
{ type="attribute", entity="inv_001", attribute="due_absolute_days", value=738924 }
```
When `absolute_days` is present it takes priority over year/month/day.

### Late fee configuration

```
# Flat fee (default: 50)
{ type="attribute", entity="billing", attribute="late_fee_flat", value=75 }

# Or percentage of invoice amount (overrides flat)
{ type="attribute", entity="billing", attribute="late_fee_pct",  value=0.015 }

# Optional cap
{ type="attribute", entity="billing", attribute="late_fee_cap",  value=200 }
```

## Querying

```
# Check overdue and get escalation level
invoice_overdue(inv_001)
escalation_level(inv_001, Level)

# Get total due including late fee
payment_due_amount(inv_001, Amount)

# List all overdue invoices (requires asserting each invoice in the namespace)
invoice_overdue(Invoice)
```

## Agent Use Cases

**Collection agent**: Poll all invoices daily. For each overdue invoice, check `escalation_level` and dispatch the appropriate action (send reminder email, hand to collections, pause service).

**AR dashboard**: Query `days_overdue` and `payment_due_amount` for all open invoices to build an aging report — no application code needed for the logic.

**Policy changes**: Adjust `warning_days`, `late_fee_pct`, or `late_fee_cap` by asserting new billing configuration. The change takes effect immediately without redeploying the module.
