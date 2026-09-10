# Module: temporal v1.0.0

Ordering, overlap, gaps and deadlines over timestamped facts. Assert a
`timestamp` on point events, `start`/`end` on intervals, `deadline` on anything
with one; ask which came first, what overlaps, what is due. Any domain —
tasks, sessions, buffs, log entries — and any time unit, as long as it is one
unit per namespace.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["temporal"],
    "namespace": "my-ns"
})
```

From Tether: `dg:batteries().install("temporal", "my-ns", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `event_before(E1, E2)` | `timestamp(E1) < timestamp(E2)` |
| `event_after(E1, E2)` | The reverse |
| `event_within(Event, Start, End)` | Timestamp in the **closed** range `[Start, End]` |
| `event_concurrent(E1, E2)` | Intervals overlap, **half-open**: `start1 < end2` and `end1 > start2`. Touching intervals do not overlap |
| `deadline_passed(Entity, Now)` | `Now > deadline`, strictly |
| `deadline_imminent(Entity, Now, Window)` | `Now ≤ deadline ≤ Now + Window` |
| `duration_between(E1, E2, D)` | `abs(timestamp2 − timestamp1)` |
| `gap_between(E1, E2, Gap)` | `start(E2) − end(E1)`; negative means they overlap |
| `events_in_order(Events)` | Timestamps non-decreasing along the list |
| `next_event(After, Events, Next)` | The earliest event in the list with timestamp strictly after `After` |
| `latest_event(Events, Latest)` | Highest timestamp in the list |
| `earliest_event(Events, Earliest)` | Lowest timestamp in the list |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `timestamp` | event | number | When a point event happened. `event_before`/`after`, `event_within`, `duration_between`, `events_in_order`, `next`/`latest`/`earliest_event` compare these |
| `start`, `end` | interval | numbers | The interval, for `event_concurrent` and `gap_between`. An entity may carry both a `timestamp` and an interval |
| `deadline` | entity | number | For `deadline_passed` and `deadline_imminent`, against the `Now` you pass |

Numbers in one unit of your choosing — unix seconds, milliseconds, turns,
ticks. The battery never converts, and mixing units in one namespace compares
apples with oranges silently.

## Setup

```
# Point events
{ type="attribute", entity="deploy_v1", attribute="timestamp", value=1700000000 }
{ type="attribute", entity="deploy_v2", attribute="timestamp", value=1700003600 }

# An interval
{ type="attribute", entity="maintenance", attribute="start", value=1700007200 }
{ type="attribute", entity="maintenance", attribute="end",   value=1700010800 }

# Something with a deadline
{ type="attribute", entity="invoice_001", attribute="deadline", value=1700100000 }
```

## Querying

```
# Order
event_before(deploy_v1, deploy_v2)

# Everything in a window (unbound Event enumerates timestamped entities)
event_within(E, 1700000000, 1700010000)
   E = deploy_v1 ;
   E = deploy_v2

# How far apart?
duration_between(deploy_v1, deploy_v2, D)
   D = 3600

# Overdue, and due within the hour, at Now = 1700099000
deadline_passed(X, 1700099000)
   false
deadline_imminent(X, 1700099000, 3600)
   X = invoice_001

# Newest of a set
latest_event([deploy_v1, deploy_v2], L)
   L = deploy_v2
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-ns", "deadline_imminent(E, " .. os.time() .. ", 3600)", function(rs) for _, r in ipairs(rs) do dueSoon(r.E) end end)
```

## Semantics worth knowing

**Two conventions, deliberately different.** `event_within` is closed on both
ends — an event exactly at `Start` or `End` is within. `event_concurrent` is
half-open — an interval ending at 1080 and one starting at 1080 do not overlap,
which is the same convention `duty` and `rostering` use, so shifts asserted
for those batteries answer `event_concurrent` correctly. `gap_between` on that
pair returns 0.

**Deadlines: passed is strict, imminent is inclusive.** At `Now` equal to the
deadline, `deadline_passed` is false and `deadline_imminent` is true for any
window.

**Ties are collapsed in the list predicates.** `next_event`, `latest_event`
and `earliest_event` sort by timestamp and drop duplicate timestamps, so of
two events at the same instant only one is returned — which one follows fact
order.

**Nothing is a clock.** Every `Now` is an argument you pass; the battery has no
notion of the current time.
