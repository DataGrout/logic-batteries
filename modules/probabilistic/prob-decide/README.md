# Module: prob-decide v1.0.0

DTProbLog-lite decision layer over [prob-core-iso](../prob-core-iso): expected utility of actions whose outcomes are weighted rules, and argmax over a declared action set. Pure ISO — runs on SWI and Scryer alike, including ISO-pinned cells.

**Requires:** prob-core-iso.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["prob-core-iso", "prob-decide"],
    "namespace": "my-namespace"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `eu(Action, EU)` | expected utility of Action: `sum(P_i * U_i)` over its weighted outcomes |
| `best_action(Best, BestEU)` | the `action/1` with the highest expected utility |
| `eu_sum(PUs, Acc, Sum)` | accumulator fold (internal helper for `eu/2`) |
| `best_pair(Pairs, AccA, AccEU, Best, BestEU)` | accumulator argmax (internal helper for `best_action/2`) |

## The decision model

Three predicate families, all asserted by the author:

```prolog
% candidate actions
action(sell_now).
action(hold).

% weighted outcomes per action (ProbLog notation; stored reified as
% prob_rule(outcome(A, O), P) — see prob-core-iso)
0.7::outcome(sell_now, small_profit).
0.2::outcome(sell_now, big_profit).
0.4::outcome(hold, big_profit).
0.5::outcome(hold, loss).

% utility of each outcome
utility(small_profit, 10).
utility(big_profit, 50).
utility(loss, -20).
```

Then:

```prolog
?- eu(sell_now, EU).      % EU = 17.0    (0.7*10 + 0.2*50)
?- eu(hold, EU).          % EU = 10.0    (0.4*50 + 0.5*(-20))
?- best_action(A, EU).    % A = sell_now, EU = 17.0
```

## Semantics & scope

- `eu/2` treats each weighted `outcome/2` rule instance independently and sums `P * U` — no mutual exclusion between outcomes of the same action is enforced in v1. If your outcomes are exclusive and exhaustive, keep the weights summing to ≤ 1 per action and the EU reads as a proper expectation.
- `best_action/2` fails (rather than erroring) when no `action/1` facts exist; sentinels keep fresh cells from raising `existence_error`.
- Verified live on a pinned-Scryer namespace (2026-07-04): `EU(sell_now)=17`, `EU(hold)=10`, `best=sell_now`.
