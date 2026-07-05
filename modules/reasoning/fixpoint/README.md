# Module: fixpoint v1.0.1

Bottom-up (Datalog-style) evaluation of stored rules: **tabling's termination
benefit without tabling**. Pure ISO — runs on SWI and Scryer alike, including
ISO-pinned cells, where `:- table` is unavailable by design: tabling is a
directive-enabled extension on both engines (SWI natively, Scryer via
[`library(tabling)`](https://www.scryer.pl/tabling)), directives are stripped
at cell install, and tabling isn't part of the ISO standard an ISO pin
guarantees.

**Requires:** nothing.

## Why this exists

The classic transitive closure

```prolog
reach(X, Y) :- edge(X, Y).
reach(X, Y) :- reach(X, Z), edge(Z, Y).
```

loops forever under plain top-down resolution the moment your graph has a
cycle — which is why textbooks reach for `:- table`. Inside logic cells
tabling isn't available (the directive that enables it is stripped at
install), so this battery changes the *evaluation strategy* instead: `fixpoint_solve/1` derives every fact provable from the goal's rules,
round by round, until nothing new appears (a least fixpoint), then answers
from that set. Recursive subgoals are looked up in the growing answer set
rather than re-proven, so cycles and left recursion cannot loop. Rules work
**verbatim** — no visited-set rewrites.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["fixpoint"],
    "namespace": "my-namespace"
})
```

Or standalone: `battery install fixpoint --dir my-app/`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `fixpoint_solve(Goal)` | prove Goal by saturation; nondeterministic over the answers, each derived exactly once |
| `fixpoint_solve(Goal, Derived)` | same, with an explicit derived-predicate list (e.g. `[reach/2]`) instead of auto-detection |
| `fixpoint_answers(Pattern, Answers)` | deterministic: every saturated fact unifying with Pattern |
| `fixpoint_answers(Pattern, Derived, Answers)` | same, with an explicit derived list |

Derived predicates are auto-detected: anything with at least one non-fact
clause, transitively through rule bodies. Facts-only predicates are treated
as base and called directly.

## Example

```prolog
% cyclic graph: a → b → a, b → c
edge(a, b).  edge(b, a).  edge(b, c).

reach(X, Y) :- edge(X, Y).
reach(X, Y) :- reach(X, Z), edge(Z, Y).      % loops under SLD; fine here

?- fixpoint_answers(reach(a, T), As).
%  As = [reach(a,a), reach(a,b), reach(a,c)]   — terminates, each once
?- fixpoint_solve(reach(a, a)).                % a lies on a cycle: true
```

Left recursion — top-down resolution's worst case — is equally fine:

```prolog
anc(X, Y) :- anc(X, Z), parent(Z, Y).
anc(X, Y) :- parent(X, Y).
```

Bodies may freely mix derived subgoals, base facts, builtins
(`A >= 18`, arithmetic, comparisons), disjunction, and if-then-else.

## Scope — read once

- **Datalog class only.** Sound and terminating when head values come from a
  finite domain (the constants in your facts). Rules that build unboundedly
  new terms or numbers in heads (`level(X, N1) :- edge(X, Y), level(Y, N),
  N1 is N + 1` on a cyclic graph) are outside the class and will not
  terminate here either.
- **Negation over base goals only.** `\+` over a derived (recursive)
  predicate requires stratified evaluation, which v1 does not do — it throws
  a clear error instead of computing wrong answers. The check walks the whole
  negated goal, so `\+ (reach(X, Y), blocked(Y))` is refused like
  `\+ reach(X, Y)`.
- **Aggregation over base goals only.** `setof/bagof/findall` (and
  `forall/2`) whose subgoal mentions a derived predicate throw a clear error:
  mid-saturation the answer set is still growing, so an aggregate computed
  inside a rule body can silently under-count — wrong answers, strictly worse
  than not terminating. Aggregate **after** saturation instead:
  `fixpoint_answers(reach(a, X), As), length(As, N)`. `call/N` over a derived
  predicate is fine — it is unwrapped and looked up in the answer set.
- **No cross-query caching.** Each call recomputes the saturation (naive
  iteration). At logic-cell scale this is rarely noticeable; a memoizing
  layer with write-through invalidation is on the platform roadmap, as is
  host-side tabling that will honor `:- table` declarations directly.
  DataGrout already records `:- table` declarations as namespace metadata
  rather than rejecting them, so rules that declare tabling today will be
  honored automatically when that ships — no rework.
- **Standalone users: real tabling may serve you better.** Outside cells,
  directives work, and both engines table — SWI's built-in `:- table` and
  Scryer's [`library(tabling)`](https://www.scryer.pl/tabling). Engine
  tabling caches across queries and handles more than the Datalog class;
  this battery is for the environments where directives can't reach (cells)
  or where you want the same evaluation on every ISO engine.
