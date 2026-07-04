# Module: prob-core-iso v1.0.0

> **License: [Apache-2.0](./LICENSE).** Unlike the content batteries in this
> repository (Elastic License 2.0), this core runtime module is permissively
> licensed — embed it in anything, no restrictions.

ProbLog-lite runtime in pure ISO Prolog — runs identically on SWI and Scryer. Its reason to exist is **ISO-pinned (Scryer) cells**: it makes `P::Head :- Body` weighted rules work on the ISO path with no SWI escalation and no namespace fork.

Weighted clauses are stored in the reified form `prob_rule(Head, P) :- Body`, produced from `::` notation at install/assert time by the transform in [transform.pl](transform.pl). The runtime is pure ISO Prolog; nothing in this module needs `op/3` inside the cell.

**Requires:** nothing.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["prob-core-iso"],
    "namespace": "my-namespace"
})
```

Or don't: with the platform-side transform enabled, any `::` rule sent to an ISO cell **auto-installs this battery** and rewrites in one step (see Auto-install flow below).

## Exported Predicates

| Predicate | Description |
|---|---|
| `psuccess(Goal, P)` | P is the noisy-or combination of every weighted rule instance proving Goal |
| `pmax(Goal, P)` | P from the strongest single weighted rule (legacy prob-* battery semantics) |
| `pnot(Goal, P)` | P is `1 - psuccess(Goal)` |
| `pand(Goals, P)` | product of `psuccess` over a list of goals (independence assumption) |
| `expected(Goal, Value, E)` | expected-value helper: `E = psuccess(Goal) * Value` |
| `prob_or(Ps, P)` | noisy-or fold: `P = 1 - prod(1 - Pi)` |

## Example

```prolog
% author writes (ProbLog notation):
0.65::supply_disruption(Item) :- attribute(Item, import_dependent, true),
                                 attribute(world, weather, storm).
0.25::supply_disruption(Item) :- attribute(Item, import_dependent, true),
                                 attribute(world, season, winter).

% stored on the ISO cell as:
prob_rule(supply_disruption(Item), 0.65) :- attribute(Item, import_dependent, true),
                                            attribute(world, weather, storm).
prob_rule(supply_disruption(Item), 0.25) :- attribute(Item, import_dependent, true),
                                            attribute(world, season, winter).

% query (stormy winter, import-dependent item):
?- psuccess(supply_disruption(iron_ingot), P).
% P = 0.7375        (noisy-or: 1 - 0.35*0.75)
?- pmax(supply_disruption(iron_ingot), P).
% P = 0.65          (legacy strongest-trigger semantics)
```

Verified live on a pinned-Scryer namespace (2026-07-04): three-rule noisy-or returned exactly `1 - (1-0.4)(1-0.65) = 0.79`.

## Auto-install flow (platform-side)

1. Rule text arrives at `logic.constrain` / `logic.assert` / a battery install for an ISO-pinned cell.
2. Reader parses with `op(600, xfx, '::')` (cplint-compatible priority).
3. If any clause mentions `::`: ensure `prob-core-iso` is installed in the namespace (idempotent), rewrite each clause via `problog_transform/2`, assert the rewritten form.
4. Preserve the author's original `::` text in the record's `source_text` metadata so exports and the IDE show what was written.
5. The namespace **stays ISO-pinned**. No SWI escalation.

This also lets the existing `::`-notation batteries (prob-economy, prob-loot, prob-npc, prob-detection) install unchanged on ISO cells.

## Semantics — read this once

Three different things can be meant by "the probability of a goal", and this module is explicit about which you get:

- **`psuccess/2` (default): noisy-or under the independent-rules assumption.** Every weighted rule instance whose body succeeds is an independent trigger: `P = 1 - prod(1 - Pi)`. Exact when weighted rules don't share probabilistic antecedents; an approximation when they do.
- **`pmax/2`: legacy semantics.** The earlier prob-* batteries aggregated with `max_list` — "strongest trigger wins". Kept for backward compatibility; useful for game-feel tuning where noisy-or stacks too fast.
- **Exact ProbLog distribution semantics** (shared probabilistic facts deduplicated across proofs, computed over explanations/BDDs) is **not** in v1. It is planned as a v2 backed by host-side tabling with answer subsumption (PITA-style), where answers carry explanation structures merged on insert.

## v1 limitations

- Annotated disjunctions (`0.3::a ; 0.7::b :- body`) are rejected with a clear error — needs choice-group bookkeeping (v2).
- No sampling predicates yet (needs a random source in the cell).
- Weights must be numeric literals in `[0.0, 1.0]`; computed weights (`P is ...` in the annotation) are out of scope.
