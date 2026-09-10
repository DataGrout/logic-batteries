# Module: assign v1.0.0

Budgeted constraint search over facts already in the cell. Declare variables
with candidate values, group the ones that must differ, and constrain them
through hook predicates whose bodies can call any other battery. Ask for one
consistent assignment, the cheapest one, or a list of everything wrong with an
assignment somebody else made.

This is the layer that turns "enumerate the candidates" into "pick a consistent
set": fill a roster with `duty`, allocate stock across orders with
`inventory-mgmt`, seat a party, build an encounter to a budget with `d20-xp`.
It is a small, honest solver for small instances, not a constraint programming
system.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["assign"],
    "namespace": "ops"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `assign_domain(Var, Values)` | Candidate values of Var that survive the unary hook |
| `assign_solve(Vars, Result)` | `assign_solve/3` with a default budget of 10000 nodes |
| `assign_solve(Vars, Budget, Result)` | One consistent assignment, or why there is none |
| `assign_best(Vars, Budget, Result)` | The assignment minimising the summed `assign_cost/3`, by branch and bound |
| `assign_violations(Assignment, Violations)` | Everything wrong with a given list of `Var-Value` pairs; `[]` means consistent |
| `assign_reject(Var, Value)` | **Hook.** Add clauses to forbid a value for a variable |
| `assign_reject_pair(Var1, Value1, Var2, Value2)` | **Hook.** Add clauses to forbid two assignments together; checked in both orders |
| `assign_cost(Var, Value, Cost)` | **Hook.** Add clauses to price an assignment; cheapest tried first |

### Result terms

`assign_solve/3` returns exactly one of:

| Result | Meaning |
|---|---|
| `solution(Assignment, Explored)` | `Assignment` is `[Var-Value, ...]` in the order the variables were given; `Explored` is the node count |
| `unsat(Explored)` | The whole space was searched within budget and nothing satisfies the constraints |
| `unsat(empty_domain(Var))` | `Var` has no value left after the unary hook, or no domain at all; nothing was searched |
| `budget_exhausted(Explored)` | The budget ran out with no answer either way |

`assign_best/3` returns `best(Assignment, Cost, Explored, complete)` when the
search finished, `best(Assignment, Cost, Explored, budget_exhausted)` when it
found an incumbent but could not prove it optimal, or the same `unsat` and
`budget_exhausted` terms as above.

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `domain` | variable | a list of candidate values | The values the search may assign to the variable. A variable is anything with a `domain` |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `distinct` | group → variable | Every variable in a group must take a different value. A variable may sit in several groups |

Constraints beyond all-different are not facts but clauses you define:
`assign_reject/2`, `assign_reject_pair/4` and `assign_cost/3` — see Model. The
search reads nothing else; `rostering`'s `roster_model/2` emits exactly these
two fact shapes.

## Model

### Variables and domains

```
{ type="attribute", entity="slot_mon_am", attribute="domain", value=["alvarez","chen","okafor"] }
{ type="attribute", entity="slot_mon_pm", attribute="domain", value=["alvarez","chen","okafor"] }
```

Every variable you pass to `assign_solve` needs a `domain`. A variable with
none is reported as `unsat(empty_domain(Var))` rather than silently skipped.

### All-different groups

```
{ type="relation", subject="monday", relation="distinct", object="slot_mon_am" }
{ type="relation", subject="monday", relation="distinct", object="slot_mon_pm" }
```

Variables in the same group cannot share a value. A variable may belong to
several groups.

### Hooks

The three hooks are open predicates. The battery ships a base clause for each
that always fails, so an unhooked model is constrained only by domains and
groups. Add clauses in the same namespace to constrain it. Other batteries'
predicates are the natural vocabulary:

```prolog
% A worker must be fit for the slot on their own record (duty battery).
assign_reject(Slot, W) :-
    attribute(Slot, start, S), attribute(Slot, end, E),
    \+ fit_for_duty(W, Slot, S, E).

% The same worker on two slots needs min_rest between them.
assign_reject_pair(S1, W, S2, W) :-
    S1 \== S2,
    attribute(S1, end, E1), attribute(S2, start, St2),
    St2 >= E1,
    duty_limit(W, min_rest, Min),
    St2 - E1 < Min.

% Prefer the worker with the most headroom left this week.
assign_cost(Slot, W, Cost) :-
    attribute(Slot, end, End),
    duty_headroom(W, End, H),
    Cost is -H.
```

`assign_reject_pair/4` is consulted in both argument orders, so one clause
covers both directions.

## Querying

```
# Fill Monday.
assign_solve([slot_mon_am, slot_mon_pm], Result)
   Result = solution([slot_mon_am-chen, slot_mon_pm-alvarez], 3)

# Fill it as cheaply as the cost hook defines.
assign_best([slot_mon_am, slot_mon_pm], 5000, Result)
   Result = best([slot_mon_am-chen, slot_mon_pm-alvarez], -2340, 7, complete)

# What is wrong with the roster someone typed in?
assign_violations([slot_mon_am-alvarez, slot_mon_pm-alvarez], Violations)
   Violations = [pair(slot_mon_am, alvarez, slot_mon_pm, alvarez)]

# What could still go in this slot?
assign_domain(slot_mon_pm, Values)
```

## How it searches

- **Depth-first over an explicit agenda.** The stack of open frames is a
  Prolog list, so the node budget is one global counter across the whole
  search, not a per-branch limit that backtracking resets.
- **Minimum remaining values.** The variable with the fewest surviving values
  is chosen next.
- **Forward checking.** After each choice, every other variable's domain drops
  the values that would now clash; a child with any empty domain is never
  pushed.
- **Cheapest first.** When `assign_cost/3` is hooked, values are tried in cost
  order, which makes `assign_solve` find good solutions early and gives
  `assign_best` a strong first bound.
- **Branch and bound.** `assign_best` discards any frame whose accumulated
  cost already meets the best complete cost found.

Search always terminates: the space is finite and every expansion consumes
budget. Worst case is exponential in the number of variables, which is why the
budget is an explicit argument you see in the query and why the result says
`budget_exhausted` rather than guessing.

## What this battery does not do

- **No constraint propagation beyond forward checking.** No arc consistency,
  no global cardinality, no interval reasoning. Express those through the
  hooks or through the batteries that own them.
- **No cardinality other than all-different.** "At most two shifts per worker"
  is a pair hook plus the `duty` rolling limits, not a built-in.
- **No proof of optimality past the budget.** `budget_exhausted` in a `best`
  result means "best seen so far", and says so.
- **Not a CLP library.** If an engine-native finite-domain solver is later
  exposed to cells, the same model vocabulary can compile to it. This battery
  is the portable baseline that runs on both engines today.
