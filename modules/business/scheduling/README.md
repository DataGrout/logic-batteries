# Module: scheduling v1.0.0

Time slot availability, booking conflict detection, advance window enforcement, role-gated prerequisites, and resource utilisation percentage. Assert resource configuration and existing bookings; query the rules to validate and make new bookings.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["scheduling"],
    "namespace": "my-namespace"
})
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `slot_available(Resource, Date, Slot)` | The time slot is open for booking |
| `booking_conflict(Resource, Date, Slot)` | Another booking blocks this slot |
| `can_book(Customer, Resource, Date, Slot)` | Customer meets all booking prerequisites |
| `next_available_slot(Resource, Date, Slot)` | First open slot on or after Date |
| `resource_utilization(Resource, Date, Pct)` | Percentage of slots booked on Date |

## Date Format

Dates are `YYYYMMDD` integers. This makes ordering and arithmetic straightforward without calendar dependencies:

```
20260510  →  May 10, 2026
```

## Setup

### Resource slots

```
{ type="attribute", entity="meeting_room_a", attribute="slots",       value=[9,10,11,13,14,15,16] }
{ type="attribute", entity="meeting_room_a", attribute="advance_days", value=1   }  -- book at least 1 day ahead
{ type="attribute", entity="meeting_room_a", attribute="max_advance",  value=30  }  -- no more than 30 days out
```

### Existing bookings

```
{ type="relation", subject="meeting_room_a", relation="booked_at",    object="booking_001"   }
{ type="attribute", entity="booking_001",     attribute="date",        value=20260510         }
{ type="attribute", entity="booking_001",     attribute="slot",        value=10               }
{ type="attribute", entity="booking_001",     attribute="customer",    value="customer_123"   }
```

### Current date (required for advance window checks)

```
{ type="attribute", entity="today", attribute="date", value=20260510 }
```

### Role-gated resources

```
{ type="attribute", entity="vip_suite", attribute="requires_role", value="premium" }
{ type="attribute", entity="customer_123", attribute="role",       value="premium" }
```

## Querying

```
# Is a slot open?
slot_available(meeting_room_a, 20260511, 10)

# Can this customer book it?
can_book(customer_123, meeting_room_a, 20260511, 10)

# What's the next available slot from a given date?
next_available_slot(meeting_room_a, 20260510, Slot)

# How full is the resource today?
resource_utilization(meeting_room_a, 20260510, Pct)
```

## Booking Pattern

When a booking is confirmed, assert the booking facts:

```
# New booking
{ type="relation", subject="meeting_room_a", relation="booked_at",  object="booking_002" }
{ type="attribute", entity="booking_002",     attribute="date",      value=20260511       }
{ type="attribute", entity="booking_002",     attribute="slot",      value=10             }
{ type="attribute", entity="booking_002",     attribute="customer",  value="customer_456" }
```

To cancel, retract the `booked_at` relation and the booking's attributes. `slot_available` will reflect the change on the next query.

## Agent Use Cases

**Booking agent**: When a customer requests an appointment, call `can_book` to validate, then `slot_available` to confirm, then assert the booking facts. The LC is the single source of truth — no separate availability check needed.

**Scheduling assistant**: "When's the next free slot for the meeting room?" → `next_available_slot` returns the answer directly, searching forward from today.

**Capacity planning**: `resource_utilization` per day gives a daily load picture. An agent can surface over-booked days or suggest redistribution.
