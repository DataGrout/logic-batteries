# Module: temporal v1.0.0

Temporal reasoning over timestamped facts. Assert timestamps, deadlines, start/end intervals as attributes; query ordering, overlap, gaps, and sequence validity at zero token cost. Works across any domain — tasks, events, sessions, game buffs, log entries.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["temporal"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install_many({"temporal"}, "my-namespace", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `event_before(E1, E2)` | E1's timestamp < E2's timestamp |
| `event_after(E1, E2)` | E1's timestamp > E2's timestamp |
| `event_within(Event, Start, End)` | Event timestamp falls in [Start, End] |
| `event_concurrent(E1, E2)` | E1 and E2 overlap (uses `start`/`end` attributes) |
| `deadline_passed(Entity, Now)` | Entity's `deadline` attribute < Now |
| `deadline_imminent(Entity, Now, Window)` | Deadline within Window time units of Now |
| `duration_between(E1, E2, D)` | D = \|timestamp(E2) − timestamp(E1)\| |
| `gap_between(E1, E2, Gap)` | Gap = start(E2) − end(E1); negative = overlap |
| `events_in_order(Events)` | Events list is non-decreasing by timestamp |
| `next_event(After, Events, Next)` | First event in Events with timestamp > After |
| `latest_event(Events, Latest)` | Event with highest timestamp |
| `earliest_event(Events, Earliest)` | Event with lowest timestamp |

## Setup

```lua
-- Point-in-time events (timestamp only)
dg:assert("my-ns", { type="attribute", entity="deploy_v1", attribute="timestamp", value=1700000000 })
dg:assert("my-ns", { type="attribute", entity="deploy_v2", attribute="timestamp", value=1700003600 })

-- Interval events (start + end)
dg:assert("my-ns", { type="attribute", entity="maintenance", attribute="start", value=1700007200 })
dg:assert("my-ns", { type="attribute", entity="maintenance", attribute="end",   value=1700010800 })

-- Deadline-bearing entities
dg:assert("my-ns", { type="attribute", entity="invoice_001", attribute="deadline", value=1700100000 })
```

## Usage

```lua
-- Is deploy_v1 before deploy_v2?
dg:query("my-ns", "event_before(deploy_v1, deploy_v2)", function(results)
  print(#results > 0 and "yes" or "no")  -- "yes"
end)

-- Which events fall within a time window?
dg:query("my-ns",
  "event_within(E, 1700000000, 1700010000), entity(E)",
  function(results)
    for _, r in ipairs(results) do print(r.E) end
  end)

-- How long between deploys?
dg:query("my-ns", "duration_between(deploy_v1, deploy_v2, D)", function(results)
  print("Gap: " .. results[1].D .. " seconds")  -- "Gap: 3600 seconds"
end)

-- Are any invoices overdue?
local now = os.time()
dg:query("my-ns", "deadline_passed(Invoice, " .. now .. ")", function(results)
  for _, r in ipairs(results) do
    print("Overdue: " .. r.Invoice)
  end
end)

-- Upcoming deadlines in the next hour
dg:query("my-ns", "deadline_imminent(E, " .. now .. ", 3600)", function(results)
  for _, r in ipairs(results) do print("Due soon: " .. r.E) end
end)

-- Find the most recent event in a set
dg:query("my-ns",
  "latest_event([deploy_v1, deploy_v2], Latest)",
  function(results)
    print("Latest: " .. results[1].Latest)  -- "deploy_v2"
  end)
```

## Attribute Conventions

| Attribute | Type | Used by |
|---|---|---|
| `timestamp` | integer (unix epoch or any ordinal) | `event_before`, `event_after`, `event_within`, `duration_between`, `events_in_order`, `next_event`, `latest_event`, `earliest_event` |
| `start` | integer | `event_concurrent`, `gap_between` |
| `end` | integer | `event_concurrent`, `gap_between` |
| `deadline` | integer | `deadline_passed`, `deadline_imminent` |

Time units are intentionally unspecified — use whatever unit is consistent in your namespace (seconds, milliseconds, turns, ticks).
