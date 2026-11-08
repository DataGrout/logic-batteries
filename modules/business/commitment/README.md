# Module: commitment v1.0.0

Tracks commitments, such as action items, promises made in messages, and notice dates in contracts: when each falls due, whether it is open, overdue or due soon, and whether it was done late. Due dates can be stated, relative to when the commitment was made ("within 30 days"), or measured back from an event ("give notice 60 days before renewal").

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["commitment"],
    "namespace": "my-namespace"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `due_on(Commitment, Day)` | The day Commitment falls due |
| `outstanding(Commitment)` | Neither done nor cancelled |
| `overdue(Commitment)` | Open, with its due day before today |
| `overdue_days(Commitment, Days)` | Days overdue, 0 when not overdue |
| `due_soon(Commitment)` | Open, and due within the next `due_soon_days` days, today included |
| `done_late(Commitment)` | Done after its due day |
| `owner_of(Commitment, Owner)` | Who committed |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `owner` | commitment | atom | Who committed |
| `due` | commitment | day count | The due day, when stated as a date |
| `due_in_days` | commitment | integer | Due this many days after `made_on` |
| `made_on` | commitment | day count | The day the commitment was made |
| `event_on` | commitment | day count | An event the commitment is measured against, such as a renewal date |
| `days_before` | commitment | integer | Due this many days before `event_on`; absent, it is due on `event_on` |
| `done` | commitment | `true`/`false` | Default `false` |
| `done_on` | commitment | day count | The day it was done |
| `cancelled` | commitment | `true`/`false` | Default `false`; a cancelled commitment is never overdue |
| `absolute_days` | `today` | day count | Today, the shared convention |
| `due_soon_days` | `commitments` | integer | **Tunable.** Default 7 |

The due day is the stated `due`; failing that `made_on + due_in_days`; failing that `event_on - days_before`. A `due_in_days` with no `made_on` gives no due day.

## Example

```prolog
attribute(today, absolute_days, 20765).

attribute(c1, owner, ravi).
attribute(c1, due, 20756).

attribute(c4, owner, jordan).
attribute(c4, event_on, 20828).
attribute(c4, days_before, 60).
```

```prolog
?- overdue_days(c1, D).
D = 9.
?- due_on(c4, D), due_soon(c4).
D = 20768.
```

## Notes

- A commitment with no due date of any kind is not a commitment to the rules; on DataGrout a question about it comes back unknown, naming the missing due date.
- `done` defaults to false, so "overdue" for a commitment whose completion the material never mentions rests on that default, and DataGrout reports it as an assumption.
