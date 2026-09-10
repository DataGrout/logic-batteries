# Module: duty v1.0.0

Duty-time and readiness rules for people and the equipment they use: duty
conflicts, unavailability windows (leave, training, maintenance), maximum duty
length, minimum rest, rolling cumulative limits, qualification currency, and
role gating. Assert the roster, committed duty periods, windows, policy limits,
and qualifications; ask whether a proposed duty is clean, who is available for
it, and, when someone is not, exactly why.

Built for any operation where an assignment should be *proved* clean before it
is committed: hospital and care rostering, restaurant and retail shifts,
delivery and taxi fleets, security patrols, on-call rotations, and game
simulations where units tire and recover. The predicates are domain-neutral;
the policy numbers are yours.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["duty"],
    "namespace": "ops"
})
```

Pairs naturally with `temporal` (same `start`/`end` attribute convention, so
duty periods answer `event_concurrent/2` and `gap_between/3` too), with
`scheduling` (slot booking on the same roster), and with `explain` (`why/2`
over any verdict below).

## Exported Predicates

| Predicate | Description |
|---|---|
| `duty_conflict(Worker, Start, End)` | An existing duty period of Worker overlaps `[Start, End)` |
| `unavailable(Entity, Start, End)` | An unavailability window of Entity overlaps `[Start, End)`; works for people and equipment alike |
| `duty_limit(Worker, Key, Value)` | Resolved policy value: worker override → role → global `duty_policy` |
| `policy_gap(Worker, Key)` | A policy key that is not configured for Worker at any level |
| `duty_length_ok(Worker, Start, End)` | Proposed duty does not exceed `max_duty` |
| `rest_before(Worker, Start, Rest)` | Time since the latest duty ending at or before Start; fails with no prior duty |
| `rest_satisfied(Worker, Start)` | Rest before Start meets `min_rest` |
| `cumulative_duty(Worker, WStart, WEnd, Total)` | Duty time inside a window, clipping periods that straddle its edges |
| `rolling_limit_ok(Worker, Start, End)` | Accrued duty in the `rolling_window` ending at End, plus the proposal, is within `rolling_limit` |
| `duty_headroom(Worker, At, Headroom)` | How much more duty Worker may take on ending at At |
| `qualified_for(Worker, Task, At)` | Worker holds a current qualification for every kind the task requires |
| `missing_qualification(Worker, Task, At, Kind)` | A required kind Worker lacks or holds only in expired form |
| `role_matches(Worker, Task)` | Task has no `needs_role`, or Worker has that role |
| `fit_for_duty(Worker, Task, Start, End)` | Every check passes |
| `unfit_reason(Worker, Task, Start, End, Reason)` | Each reason a worker is not fit (see below) |
| `available_staff(Task, Start, End, Worker)` | Enumerates rostered workers who are fit for duty |

`unfit_reason/5` yields one term per failing check:
`role_mismatch(Role)`, `duty_conflict(Period)`, `unavailable(Window)`,
`duty_too_long(Len, Max)`, `insufficient_rest(Rest, Min)`,
`rolling_limit_exceeded(Total, Limit)`, `missing_qualification(Kind)`.

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `role` | worker | a role id | The worker's role. Having one is what makes a worker rostered: `available_staff` enumerates only workers with a `role` |
| `start`, `end` | duty period, unavailability window | integers | The interval, half-open `[start, end)`, in the namespace's one time unit |
| `kind` | qualification | a qualification kind | What the qualification certifies; matched against a task's `requires` |
| `expires` | qualification | integer | When it lapses. Absent means it never does; a qualification is current at `At` when `expires > At` |
| `needs_role` | task | a role id | Optional role filter; a task without one accepts any role |
| `max_duty` | worker, role, `duty_policy` | integer | Longest single duty period. Policy keys resolve worker → role → `duty_policy`; an unconfigured key is **not enforced** (see `policy_gap`) |
| `min_rest` | worker, role, `duty_policy` | integer | Least rest between a prior duty's end and a new start |
| `rolling_window` | worker, role, `duty_policy` | integer | Length of the window over which `rolling_limit` is measured, ending at the proposed end |
| `rolling_limit` | worker, role, `duty_policy` | integer | Most duty time allowed within a `rolling_window`. Only enforced when both are configured |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `duty_period` | worker → period | A committed duty period (past, current, or already scheduled). Conflicts, rest and rolling totals are all computed from these |
| `unavailable_during` | worker or equipment → window | Leave, training, maintenance. `unavailable` works for any entity, not only people |
| `holds` | worker → qualification | The worker holds this qualification entity |
| `requires` | task → qualification kind | The task needs a current qualification of this kind; zero or more per task |

`duty_policy` is a fixed entity name for the global defaults. A `reason` on an
unavailability window is fine to assert for your own explanations, but no
clause reads it.

## Time

Time is an integer in one consistent unit per namespace. Minutes work well for
duty rules; unix seconds work if your source data is already in them; game
ticks work for simulations. Every policy limit is expressed in the same unit as
the timestamps.

Intervals are half-open, written `[Start, End)`: the square bracket means the
start instant is included, the parenthesis means the end instant is excluded.
So a duty that starts exactly when the previous one ends does not overlap it. This is the same convention the
`temporal` battery uses.

## Setup

### Roster

```
{ type="attribute", entity="alvarez", attribute="role", value="nurse" }
{ type="attribute", entity="chen",    attribute="role", value="nurse" }
{ type="attribute", entity="okafor",  attribute="role", value="orderly" }
```

Anyone with a `role` attribute is rostered and is a candidate for
`available_staff/4`.

### Duty periods (past, current, and already committed)

```
{ type="relation",  subject="alvarez", relation="duty_period", object="d_101" }
{ type="attribute", entity="d_101",    attribute="start", value=480  }
{ type="attribute", entity="d_101",    attribute="end",   value=1080 }
```

### Unavailability windows

The same shape covers a person's leave and a vehicle's maintenance:

```
{ type="relation",  subject="chen",   relation="unavailable_during", object="w_leave" }
{ type="attribute", entity="w_leave", attribute="start",  value=2880 }
{ type="attribute", entity="w_leave", attribute="end",    value=4320 }
{ type="attribute", entity="w_leave", attribute="reason", value="leave" }

{ type="relation",  subject="van_3",  relation="unavailable_during", object="w_mx" }
{ type="attribute", entity="w_mx",    attribute="start",  value=1800 }
{ type="attribute", entity="w_mx",    attribute="end",    value=2280 }
{ type="attribute", entity="w_mx",    attribute="reason", value="maintenance" }
```

### Policy limits

Four keys: `max_duty`, `min_rest`, `rolling_window`, `rolling_limit`. Each
resolves in order: an attribute on the worker, then on their role, then on the
global entity `duty_policy`.

```
{ type="attribute", entity="duty_policy", attribute="max_duty",       value=720   }   -- 12 h
{ type="attribute", entity="duty_policy", attribute="min_rest",       value=660   }   -- 11 h
{ type="attribute", entity="nurse",       attribute="rolling_window", value=10080 }   -- 7 days
{ type="attribute", entity="nurse",       attribute="rolling_limit",  value=2880  }   -- 48 h in any 7 days
{ type="attribute", entity="alvarez",     attribute="max_duty",       value=600   }   -- per-worker override
```

### Qualifications and currency

```
{ type="relation",  subject="alvarez", relation="holds", object="q_a_icu" }
{ type="attribute", entity="q_a_icu",  attribute="kind",    value="icu_cert" }
{ type="attribute", entity="q_a_icu",  attribute="expires", value=20000 }         -- optional
```

A qualification without `expires` never lapses.

### Tasks

A task is whatever gets assigned: a shift, a job, a route, a quest.

```
{ type="relation",  subject="t_42", relation="requires",   object="icu_cert" }
{ type="relation",  subject="t_42", relation="requires",   object="acls" }
{ type="attribute", entity="t_42", attribute="needs_role", value="nurse" }         -- optional
```

## Querying

```
# Is this assignment clean?
fit_for_duty(alvarez, t_42, 2400, 2760)

# Who could take it?
available_staff(t_42, 2400, 2760, Worker)

# Why not chen?
unfit_reason(chen, t_42, 2370, 2760, Reason)
   Reason = insufficient_rest(90, 660) ;
   Reason = missing_qualification(icu_cert)

# Is the van out?
unavailable(van_3, 2400, 2760)

# How many more duty minutes can alvarez accrue this week?
duty_headroom(alvarez, 10080, Headroom)

# Is the policy complete for this worker?
policy_gap(okafor, Key)
```

## Semantics worth knowing

**Unconfigured limits are not enforced.** If no `max_duty` resolves for a
worker, `duty_length_ok/3` succeeds. This keeps the battery usable with a
partial policy, but where a complete policy matters it is the wrong default to
rely on silently: check `policy_gap/2` first and refuse to answer when it
succeeds. The two predicates exist together for exactly this reason.

**Rest is measured from committed duty only.** `rest_before/3` looks at duty
periods ending at or before the proposed start. A period still running at the
proposed start is a `duty_conflict`, not a short rest, and is reported as such.

**Rolling limits clip at the window edge.** A duty period straddling the start
of the rolling window contributes only the part inside it. The proposed duty
is clipped the same way.

**The proposed duty is checked, not asserted.** `fit_for_duty/4` and friends
never modify the cell. When an assignment is confirmed, assert its
`duty_period` facts yourself; the next query sees them. To release it, retract
them.

**Facts are the ground truth.** A logic engine answers from what it holds. If
the maintenance record was never loaded, the van looks available. Load from
the system of record, stamp facts with provenance and expiry, and treat a stale
cell as "unknown" rather than "clear."

## What this battery does not do

- It does not pick the *best* worker. `available_staff/4` enumerates everyone
  who is fit; ranking and assignment are yours.
- It does not know time zones, daylight saving, or calendars. Convert to a
  single integer timeline before asserting.
- It does not encode any specific regulation or labour agreement. The four
  policy keys express the common structure of duty-and-rest rules; the numbers,
  and any rule shapes beyond these (split shifts, extensions, standby that
  counts partially), come from your own policy.
