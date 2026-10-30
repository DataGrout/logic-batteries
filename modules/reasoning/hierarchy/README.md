# Module: hierarchy v1.0.0

Roll a tree up to totals: a chart of accounts, cost centres, a bill of
materials, org units. Each node has an amount of its own; a node's subtotal is
its own amount plus every descendant's, at any depth.

**Requires:** nothing.

## Facts this battery reads

**Relations**

| Name | From | To | Description |
|---|---|---|---|
| `child_of` | child node | parent node | One edge per child: `relation(Child, child_of, Parent)` |

**Metrics**

| Name | On | Value | Description |
|---|---|---|---|
| `amount` | node | number | The node's own amount: `metric(Node, amount, Value)`. Any other metric name works with the `/3` forms (`hier_subtotal(Node, budget, T)`) |

These are the logic cell's ordinary structured facts, so `logic.assert` with
`relation` and `metric` facts is all the setup there is.

## Queries

```prolog
?- hier_subtotal('Job Expenses', T).        % own + everything below
?- hier_subtotals(Pairs).                    % every node's subtotal
?- why(hier_subtotal('Utilities', T), F).    % the facts behind a total
?- hier_path('Sprinklers', 'Expenses', P).   % the chain of parents
?- hier_problems(Ps).                        % loops, double parents, bad amounts
```

| Predicate | |
|---|---|
| `hier_parent/2`, `hier_children/2` | direct edges |
| `hier_rolls_up/2`, `hier_descendants/2` | the transitive closure, up and down |
| `hier_own/2,3` | a node's own amount (the sum of its metric facts, 0 if none) |
| `hier_subtotal/2,3`, `hier_subtotals/1,2` | own plus descendants, for one node or all |
| `hier_depth/2`, `hier_path/3` | how deep a node sits, and the chain to an ancestor |
| `hier_roots/1`, `hier_leaves/1`, `hier_nodes/1` | the tree's shape |
| `hier_cycle/1`, `hier_multi_parent/1`, `hier_problems/1` | what is wrong with the data |

A subtotal for a node the hierarchy does not know fails rather than answering
0, so a misspelled account is never reported as empty.

## Loops and double parents

The closure is a bottom-up fixpoint over the edges (the general form is the
[fixpoint](../fixpoint/) battery), so every query terminates even when the
data has a loop, and each descendant is counted once even when two paths
reach it. A loop is not an error the query hides: `hier_cycle/1` names every
node on one and `hier_problems/1` lists them. A node with two parents counts
under both, which is usually a mistake in the source data; `hier_problems/1`
reports it as `multi_parent(Node)`.

The battery needs no tabling and no other battery, so it also runs in
ISO-pinned cells and in plain `swipl` or `scryer-prolog` projects.
