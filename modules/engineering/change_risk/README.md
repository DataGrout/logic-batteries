# Module: change-risk v1.0.1

How far a change reaches and who owns it. The blast radius is every code unit outside the change that calls into the files it touches, directly or through other callers, read from a code graph; ownership is a CODEOWNERS file read as records. A change is low risk when its blast radius is within the policy's limit and every changed file has an owner.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["change-risk"],
    "namespace": "my-namespace"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `low_risk(Change)` | Blast radius within the limit and every changed file owned |
| `risk_reason(Change, Reason)` | Reason is `wide_blast_radius(N, Max)` or `unowned_files(Count)` |
| `change_blast_radius(Change, N)` | Units outside the change that reach it through calls |
| `affected_unit(Change, Unit)` | One such unit |
| `unowned_file(Change, Path)` | A changed file no owner rule gives an owner |
| `owner_coverage(Change, Owned, Total)` | Owned of Total changed files have an owner |
| `owners_of(Change, Owner)` | Owner owns at least one changed file |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `file_of` | changed file | change id | The change the file is part of |
| `path` | changed file | atom | Path from the repository root |
| `defined_in` | code unit | atom | The path of the file the unit is defined in |
| `calls` | code unit | code unit id | A unit it calls; one fact per callee |
| `owns_pattern` | owner rule | atom | A CODEOWNERS pattern |
| `owner` | owner rule | atom | An owner; one fact per owner. None leaves the files unowned |
| `line` | owner rule | integer | The rule's line; the last matching rule decides |
| `max_blast_radius` | `risk_policy` | integer | **Tunable.** Default 25 |
| `require_owners` | `risk_policy` | `true`/`false` | **Tunable.** Default `true` |

## Example

```prolog
attribute(charge_1, defined_in, 'lib/billing/charge.ex').
attribute(checkout_2, defined_in, 'lib/checkout.ex').
attribute(checkout_2, calls, charge_1).

attribute(o1, owns_pattern, '/lib/').
attribute(o1, owner, '@acme/core').

attribute(f1, file_of, pr_7).
attribute(f1, path, 'lib/billing/charge.ex').
```

```prolog
?- change_blast_radius(pr_7, N).
N = 1.
```

## Notes

- Patterns follow CODEOWNERS: `*` matches within one path segment, `**` across segments and `?` one character. A pattern starting with `/` or containing one is anchored at the root; otherwise it matches a segment at any depth. `dir/` owns everything under the directory, `dir/*` only the files directly in it, and any other pattern the path it matches and everything under it.
- Without the code graph, without owner rules (when owners are required) or without a changed file, `low_risk` does not hold; on DataGrout the answer is unknown, naming what is missing.
- Callers inside the change are not counted: they change with it.
