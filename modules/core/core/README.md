# Module: core v1.0.0

The one copy of the list and aggregate helpers every battery ends up needing,
written once in pure ISO Prolog and prefixed `core_` so nothing here shadows an
engine library. Install it like any battery, or consult it first when running
standalone.

Licensed [Apache-2.0](./LICENSE) rather than the repository default, for the
same reason as `prob-core-iso`: this is core runtime, not content. It is the
compatibility layer other batteries are written against, so restricting it
would restrict everything built on top rather than the content it covers.

## Why

A battery that must run on more than one engine needs one spelling that works
everywhere, and `core_*` is that spelling. Two things narrow what a battery may
call, and a third group is not about portability at all. Measured on
SWI-Prolog 9.2 and Scryer 0.10.0, September 2026, by calling each predicate
with valid arguments and watching for `existence_error` — `current_predicate/1`
is false for builtins, so it cannot answer this question.

**The portable base** needs no help. `sort/2`, `keysort/2`, `sum_list/2`,
`nth0/3`, `nth1/3`, `member/2`, `memberchk/2`, `append/3`, `reverse/2`,
`length/2`, `maplist/2..5`, `select/3`, `permutation/2`, `list_to_set/2`,
`foldl/4`, `findall/3`, negation, if-then-else, and arithmetic (`max`, `min`,
`abs`, `//`, `mod`, `sqrt`, `**`) are present on both engines.

**1. Absent from Scryer.** These exist in SWI's `library(lists)` or
`library(apply)` and have no Scryer equivalent, so a battery that calls one
works on SWI and raises `existence_error` on Scryer:

| SWI predicate | use instead |
|---|---|
| `max_list/2` | `core_max_list/2` |
| `min_list/2` | `core_min_list/2` |
| `msort/2` | `core_msort/2` |
| `sort/4` | `core_keysort/2`, or `core_msort/2` over `Key-Value` pairs |
| `last/2` | `core_last/2` |
| `include/3` | `core_include/3` |
| `exclude/3` | `core_exclude/3` |
| `forall/2` | `core_forall/2` |
| `subtract/3` | `core_subtract/3` |
| `flatten/2` | `core_flatten/2` |
| `aggregate_all/3` | `findall/3` plus `length/2` or `core_max_list/2` |
| `sumlist/2` | `sum_list/2` (both engines) |

**2. On Scryer only via a library.** Both engines have these, but on Scryer they
live in a library, and a battery cannot import one for itself — directives do
not survive installation. `core_*` spells them portably:

| Predicate | Where it lives on Scryer | use instead |
|---|---|---|
| `between/3`, `numlist/3` | `library(between)` | `core_between/3`, `core_numlist/3` |
| `pairs_keys/2`, `pairs_values/2`, `pairs_keys_values/3` | `library(pairs)` | `core_keys/2`, `core_values/2`, `core_zip/3` |
| `group_pairs_by_key/2` | `library(pairs)` | `core_group_pairs/2` |

**3. Neither engine provides them.** These are not shims of anything. Batteries
kept hand-rolling them, which is the other half of why this file exists:
`core_argmax/2`, `core_argmin/2`, `core_mean/2`, `core_median/2`,
`core_clamp/4`, `core_take/3`, `core_drop/3`. SWI's `max_member/2` and
`min_member/2` are the closest relatives to the first two, but they compare by
standard order of terms rather than by a numeric key.

Before this battery, `duty`, `d20-xp` and `prob-decide` each carried a private
maximum or sum. `make lint` flags any battery outside `core` that reaches for a
name from group 1 or 2 and names the replacement.

## Install

Install it like any other battery:

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["core"],
    "namespace": "my-namespace"
})
```

Standalone: `consult('modules/core/core/core')` before any battery that uses it.

## Exported Predicates

### Aggregates

| Predicate | Description |
|---|---|
| `core_max_list(Numbers, Max)` | Largest element of a non-empty list |
| `core_min_list(Numbers, Min)` | Smallest element of a non-empty list |
| `core_argmax(Pairs, Value)` | Value with the largest Key in a `Key-Value` list; first wins ties |
| `core_argmin(Pairs, Value)` | Value with the smallest Key; first wins ties |
| `core_mean(Numbers, Mean)` | Arithmetic mean (float) |
| `core_median(Numbers, Median)` | Median; mean of the two middle values for even lengths |
| `core_clamp(X, Lo, Hi, Y)` | X held within `[Lo, Hi]` |

### Lists

| Predicate | Description |
|---|---|
| `core_last(List, Last)` | Last element |
| `core_take(N, List, Prefix)` | First N elements, or the whole list if shorter |
| `core_drop(N, List, Rest)` | Without the first N elements |
| `core_msort(List, Sorted)` | Stable sort by standard order, duplicates kept |
| `core_keysort(Pairs, Sorted)` | Stable sort of `Key-Value` pairs by Key only |
| `core_group_pairs(SortedPairs, Groups)` | Runs of equal keys become `Key-Values` |
| `core_unique(List, Unique)` | Duplicates removed, first occurrence and order kept |
| `core_between(Lo, Hi, X)` | Each integer from Lo to Hi on backtracking |
| `core_numlist(Lo, Hi, List)` | The integers from Lo to Hi as a list |
| `core_subtract(List, Remove, Rest)` | List without any element in Remove |
| `core_flatten(Nested, Flat)` | Fully flattened list |
| `core_zip(Xs, Ys, Pairs)` | Pairwise `X-Y` pairs |
| `core_keys(Pairs, Keys)`, `core_values(Pairs, Values)` | Project a pair list |

### Higher-order

| Predicate | Description |
|---|---|
| `core_include(Goal, List, Kept)` | Elements for which `call(Goal, X)` succeeds |
| `core_exclude(Goal, List, Kept)` | Elements for which it fails |
| `core_foldl(Goal, List, Acc0, Acc)` | Left fold with `call(Goal, X, AccIn, AccOut)` |
| `core_forall(Cond, Action)` | Action succeeds for every solution of Cond |

These four meta-call their goal argument, which makes them the one part of this
battery a host may treat differently: somewhere that vets goals before running
them, a call it cannot inspect ahead of time may not be admitted. Standalone
consult has no such restriction. Prefer a first-order formulation in a battery
meant to run anywhere.

## Semantics worth knowing

- `core_msort/2` and `core_keysort/2` are merge sorts: stable, duplicate-preserving, O(n log n). `sort/2` drops duplicates, which is why both exist.
- `core_max_list/2`, `core_min_list/2`, `core_mean/2`, `core_median/2`, `core_last/2` fail on the empty list rather than erroring; callers decide what empty means.
- `core_argmax/2` and `core_argmin/2` compare keys with `>` and `<`, so keys must be numbers.
- `core_unique/2` and `core_subtract/3` compare with `==`, so unbound variables are treated as distinct.

## Naming

A predicate that is a drop-in replacement carries the name it replaces:
`core_msort/2` for `msort/2`, `core_max_list/2` for `max_list/2`, and so on.
So wherever `X` is unavailable, the thing to type is `core_X`.
(`core_max_list/2` rather than `core_max/2` because `max/2` is an arithmetic
evaluable functor — `X is max(A, B)` — and a list aggregate should not read
like one.)

A different name means the semantics differ, and the difference is worth
knowing:

- `core_keys/2`, `core_values/2`, `core_zip/3` cover the ground of
  `pairs_keys/2`, `pairs_values/2` and `pairs_keys_values/3` but work in one
  direction only, so they are not drop-ins. `core_zip/3` also requires the two
  lists to be the same length rather than failing silently.
- `core_unique/2` does what `list_to_set/2` does, using `==` to compare.
- `core_group_pairs/2` takes an already key-sorted list, where SWI's
  `group_pairs_by_key/2` documents the same requirement but is easy to misuse.
- `core_argmax/2`, `core_argmin/2`, `core_mean/2`, `core_median/2`,
  `core_clamp/4`, `core_take/3`, `core_drop/3` replace nothing.

## For battery authors

Use the portable base directly when it covers the need. Reach for `core_` when
it does not. Do not redefine a helper under your own prefix; if `core` lacks
something two batteries need, add it here.
