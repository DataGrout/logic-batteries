# Module: explain v1.0.0

Provenance / "why" battery: a meta-interpreter producing **proof trees** for any goal provable from the cell's stored rules and facts. Ask not just *whether* something holds, but *which facts made it true*. Pure ISO — runs on SWI and Scryer alike, including ISO-pinned cells.

**Requires:** nothing.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["explain"],
    "namespace": "my-namespace"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `why(Goal, Facts)` | **deterministic** — flat list of base/stored facts supporting the first proof. The everyday API. |
| `explain(Goal, ProofTree)` | nondeterministic full proof tree; alternative proofs on backtracking |
| `expl_prove(Goal, Proof)` | the meta-interpreter (conj/disj/if-then-else/negation/builtins/clause walk) |
| `expl_leaves(Proof, Acc, Facts)` | collect `base_fact`/`stored_fact` leaves from a tree |
| `expl_base(G)` | recognizer for cell base predicates (`entity`/`attribute`/`relation`/`metric`/`tag`) |
| `expl_builtin(G)` | whitelist of builtins called directly |

## Example

```prolog
discount(Cust, senior_discount)  :- person_age(Cust, Age), Age >= 65.
discount(Cust, loyalty_discount) :- member_years(Cust, Y), Y >= 5,
                                    \+ flagged(Cust).

person_age(mona, 71).
person_age(zed, 30).
member_years(zed, 7).
member_years(mona, 2).
```

```prolog
?- why(discount(mona, D), Facts).
%  D = senior_discount, Facts = [person_age(mona,71)]

?- why(discount(zed, D), Facts).
%  D = loyalty_discount, Facts = [member_years(zed,7)]
%  (the \+ flagged(zed) negation holds but contributes no leaf)

?- explain(discount(mona, D), Proof).
%  Proof = node(rule(discount(mona,senior_discount)),
%            [node(conj, [node(rule(person_age(mona,71)),
%                            [leaf(person_age(mona,71), stored_fact)]),
%                          leaf(71 >= 65, builtin)])])
```

## Proof tree shape

- Inner nodes: `node(Kind, Subproofs)` with `Kind` one of `rule(Goal)`, `conj`, `disj`, `ifthen`, `else`.
- Leaves: `leaf(Goal, Class)` with `Class` one of `base_fact` (cell base predicates), `stored_fact` (asserted facts reached via `clause/2`), `builtin`, `negation` (`\+` that held).
- `why/2` keeps only `base_fact`/`stored_fact` leaves — the ground provenance.

## Performance note

Meta-interpretation is expensive to *backtrack through*. `why/2` is wrapped in `once/1` for exactly this reason — asking a nondeterministic `explain/2` for a second solution can send the engine on a very long redo hunt through the proof space (observed as inactivity timeouts on live cells). Prefer `why/2`, and use `limit: 1` when querying `explain/2` unless you specifically want alternative proofs.

## Platform notes

- The load-bearing feasibility fact: **`clause/2` works on Scryer cells against stored rules and facts** (verified live on a pinned-Scryer namespace, 2026-07-04).
- Verified live with the example above: `why(discount(mona,D),F)` → `senior_discount` via `person_age(mona,71)`; `zed` → `loyalty_discount` via `member_years(zed,7)` with the `\+ flagged` negation correctly contributing no leaf.
