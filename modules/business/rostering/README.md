# Module: rostering v1.0.0

The roster layer over `duty` and `assign`: what each shift needs, who is
assigned, whether the roster as a whole holds, who should fill a gap, who can
step in when someone drops, and whether two people may trade. Proposals come
back as terms for you to assert; nothing in this battery writes to the cell.

**Requires** `duty` (per-worker legality) and `assign` (only for the optional
exact fill through `roster_model/2`). `batteries.install_many` does not resolve
requirements for you, so install all three:

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["duty", "assign", "rostering"],
    "namespace": "ops"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `coverage(Shift, Role, Have)` | Assigned workers with Role on Shift, per needed role |
| `coverage_gap(Shift, Role, Missing)` | Seats still open for Role on Shift |
| `understaffed(Shift)` | Shift has at least one gap |
| `overstaffed(Shift, Role, Extra)` | More workers with Role than seats |
| `incompatible_shifts(Worker, S1, S2)` | Overlap, or rest between them below the worker's `min_rest` |
| `roster_violation(Shift, Worker, Reason)` | Assigned worker who should not be; see reasons below |
| `roster_valid(Shifts)` | No violations and no gaps across the list |
| `candidates(Shift, Role, Workers)` | Fit, available, compatible workers with Role, in roster order |
| `candidate_score(Shift, Worker, Score)` | The ranking key (see Ranking) |
| `rank_candidates(Shift, Role, Ranked)` | Candidates best first |
| `fill_shift(Shift, Role, Picks)` | Best candidates for the current gap, as a list |
| `propose_roster(Shifts, Proposal)` | Greedy fill of every gap, in shift start order |
| `propose_roster(Shifts, Proposal, Unfilled)` | Same, plus `Shift-Role-Missing` for seats nobody could take |
| `replacement_for(Shift, Worker, Candidate)` | Best-first stand-ins for a drop-out |
| `swap_valid(W1, S1, W2, S2)` | Two assigned workers may trade shifts |
| `assigned_load(Worker, WStart, WEnd, Total)` | Assigned shift time inside a window, clipped |
| `load_imbalance(Role, WStart, WEnd, Max, Min)` | Heaviest and lightest assigned load for a role |
| `roster_model(Shifts, Facts)` | The `assign` model for the open seats |

`roster_violation/3` reasons: every `unfit_reason/5` term from `duty`
(`insufficient_rest`, `missing_qualification`, `duty_conflict`, and so on),
plus `clash(OtherShift)` when the worker holds an incompatible second
assignment, and `role_not_needed(Role)` when the shift has no seat for the
worker's role.

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `start`, `end` | shift | integers | The shift's window, half-open `[start, end)`; a shift is anything with both plus at least one `needs` |
| `seat` | requirement | a role id | The role a seat requirement is for. Named `seat`, not `role`, because `role` is the worker attribute |
| `count` | requirement | integer | How many workers with that `seat` role the shift needs |
| `role` | worker | a role id | The worker's role; only workers whose role matches a seat are candidates |
| `seniority` | worker | integer | Fourth ranking key; higher ranks earlier. Default 0 |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `needs` | shift → requirement | Attaches a seat requirement to the shift; one per role needed |
| `assigned` | shift → worker | A current assignment. Coverage, violations, load and swaps are all computed from these |
| `prefers` | worker → shift | First ranking key: a preferred shift ranks before neutral, which ranks before avoided |
| `avoids` | worker → shift | See `prefers` |

Everything about the worker's legality — duty periods, unavailability,
qualifications, `min_rest` and the other policy limits — is read through the
`duty` battery's predicates, not directly; see its facts table.

**Produced, not read.** `roster_model/2` returns, as terms for you to assert,
the `assign` model of the open seats: on each slot an attribute `domain` (the
candidate list) and `seat` (the role), a relation `slot_of` from the slot to
its shift, and a relation `distinct` from the shift to each of its slots. Slot
names are `<shift>_<role>_<n>`.

## Data model

Shifts are `duty` tasks with a window and one or more seat requirements. A
requirement names its role as `seat`, not `role`, because `role` is the worker
attribute in `duty` and the two must not be confused. Time is one integer unit
per namespace; intervals are half-open `[Start, End)`.

```
# A shift: 08:00–18:00, two nurses and one orderly, ACLS required
{ type="attribute", entity="sh_am",  attribute="start", value=480  }
{ type="attribute", entity="sh_am",  attribute="end",   value=1080 }
{ type="relation",  subject="sh_am", relation="needs",  object="r_am_n" }
{ type="attribute", entity="r_am_n", attribute="seat",  value="nurse" }
{ type="attribute", entity="r_am_n", attribute="count", value=2 }
{ type="relation",  subject="sh_am", relation="needs",  object="r_am_o" }
{ type="attribute", entity="r_am_o", attribute="seat",  value="orderly" }
{ type="attribute", entity="r_am_o", attribute="count", value=1 }
{ type="relation",  subject="sh_am", relation="requires", object="acls" }

# An assignment
{ type="relation",  subject="sh_am", relation="assigned", object="alvarez" }

# Preferences and seniority (optional)
{ type="relation",  subject="alvarez", relation="prefers", object="sh_am" }
{ type="relation",  subject="chen",    relation="avoids",  object="sh_am" }
{ type="attribute", entity="chen",     attribute="seniority", value=3 }
```

Workers, roles, qualifications, committed duty periods, unavailability, and
policy limits are the `duty` battery's model and are read through its
predicates. Rostering adds nothing to the per-worker picture; it reasons about
the roster.

## Ranking

`candidate_score/3` returns a key tuple, `k(PrefRank, NegHeadroom, Load, NegSeniority)`,
compared by Prolog's standard order of terms, so ranking needs no weights and
makes no assumptions about your time unit:

1. **Preference class**: `prefers` this shift (0), no opinion (1), `avoids` it (2).
2. **Headroom**: more remaining duty in the rolling window ranks higher (from `duty_headroom/3`; 0 when no rolling policy is configured).
3. **Load**: fewer assigned shifts inside the rolling window ranks higher, spreading work.
4. **Seniority**: higher `seniority` attribute ranks higher; 0 when absent.

Lower keys sort first, so `rank_candidates/3` is one `sort/2` over
`Key-Worker` pairs. If your operation ranks differently, define your own
ordering over `candidates/3`; the components are all exported or derivable.

## Querying

```
# Where are the gaps?
coverage_gap(Shift, Role, Missing)

# What is wrong with the roster someone entered?
roster_violation(Shift, Worker, Reason)

# Fill everything, in start order, respecting rest between picks
propose_roster([sh_am, sh_pm, sh_next], Proposal, Unfilled)
   Proposal = [sh_am-alvarez, sh_am-diaz, sh_am-okafor, sh_pm-chen, sh_next-alvarez]
   Unfilled = []

# Someone called out
replacement_for(sh_am, alvarez, Candidate)

# Can these two trade?
swap_valid(alvarez, sh_am, chen, sh_pm)

# Who is carrying the week?
load_imbalance(nurse, 0, 10080, Max, Min)
```

Confirm a proposal by asserting its pairs as `assigned` relations; the next
query sees them. Release by retracting.

## Exact fill with `assign`

`propose_roster/3` is greedy: it fills shifts in start order and never
backtracks, so a scarce worker placed early can leave a later seat empty that
a different arrangement would have covered. When that matters, hand the open
seats to `assign`:

```prolog
% 1. Build and assert the model: one slot per open seat, candidates as domain,
%    slots of the same shift in a distinct group.
roster_model([sh_am, sh_pm], Facts).   % assert each fact

% 2. One hook: the same worker cannot fill seats on incompatible shifts.
assign_reject_pair(S1, W, S2, W) :-
    relation(S1, slot_of, Sh1), relation(S2, slot_of, Sh2),
    Sh1 \== Sh2,
    incompatible_shifts(W, Sh1, Sh2).

% 3. Optional: prefer the rostering ranking as the search's value order.
assign_cost(Slot, W, Cost) :-
    relation(Slot, slot_of, Shift),
    candidate_score(Shift, W, k(P, NegH, L, NegS)),
    Cost is P * 1000000 + L * 10000 + NegH + NegS.   % one flattening of the key

% 4. Solve.
assign_solve([sh_am_nurse_1, sh_am_nurse_2, sh_am_orderly_1, sh_pm_nurse_1], Result).
```

Slot names are `<shift>_<role>_<n>`. `roster_model/2` computes candidates
against the current assignments only; compatibility between the seats the
search fills is exactly what the pair hook decides, because it depends on the
values chosen.

## Semantics worth knowing

**Assignments are not duty periods.** `duty` reasons over committed
`duty_period` facts. Rostering assignments are proposals until you say
otherwise, so compatibility between assigned shifts is checked here
(`incompatible_shifts/3`, `clash/1` violations) rather than expected from
`duty`. When a roster is committed, you may also assert the shifts as duty
periods so downstream legality checks see them.

**Greedy means greedy.** `propose_roster/3` is deterministic and explainable
and reports what it could not fill. It does not search. Use `assign` when the
arrangement matters more than the order.

**Roles come from seats.** A shift's roles are its `needs` requirements. The
`duty` battery's `needs_role` attribute still works for single-role tasks, but
rostering ignores it in favour of seats; a shift with both is fine as long as
they agree.

**No unit assumptions.** Nothing here divides by 60 or knows what a day is.
Windows for `assigned_load/4` and `load_imbalance/5` are yours to pass.

## What this battery does not do

- No optimisation beyond the greedy pass; that is `assign`'s job through `roster_model/2`.
- No recurring shift patterns or templates; generate shift facts upstream.
- No calendar, time zone, or holiday awareness; convert to the integer timeline first.
- No labour-agreement semantics beyond what `duty`'s four policy keys express.
