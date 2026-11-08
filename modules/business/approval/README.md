# Module: approval v1.0.0

Decides whether an item was approved, from the statements people made about it: who approved, rejected or withdrew, when, with what limit or condition, and whether they had the authority to. Authority is supplied as records, never read from the statements. A decision the facts cannot support is unknown, not "not approved".

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["approval"],
    "namespace": "my-namespace"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `approved(Item)` | A standing approval: the latest decision from someone with authority approves Item within its own limit, and its approver has not withdrawn it |
| `approved_by(Item, Person, Day)` | Person's approval of Item, made on Day, is standing |
| `conditions(Item, Condition)` | A standing approval of Item is subject to Condition |
| `withdrawn(Item)` | Item was approved, and its approver withdrew the approval, with none standing since |
| `rejected(Item)` | The latest decision from someone with authority rejects Item |
| `authorized(Person, Item)` | Person has the authority to approve Item |
| `unauthorized_approval(Item, Person)` | Person approved Item without the authority to |
| `unauthorized_withdrawal(Item, Person)` | Person withdrew an approval of Item they never gave; it does not count |
| `limited_approval(Item, Person, Limit)` | Person approved Item only up to Limit, below its amount, so it does not stand |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `about` | statement | an item id | The item the statement is about. Each statement is its own subject |
| `act` | statement | `approve`, `reject` or `withdraw` | What the statement does. A question ("approved, pending legal?") is not an approval |
| `by` | statement | a person id | Who made the statement |
| `on` | statement | day count | The day it was made |
| `order` | statement | integer | Position in the thread for statements on the same day; the later one wins |
| `limit` | statement | number | The approval holds only up to this amount ("approved up to 5,000") |
| `condition` | statement | text | A condition the approval is subject to. A question is not a condition |
| `title` | item | text | What is being approved |
| `amount` | item | number | Checked against the authority's `up_to` and the statement's `limit` |
| `category` | item | atom | Matched against an authority's `covers_category` |
| `role` | person | atom | Matched against an authority's `approver_role` |
| `approver_role` | authority | atom | A role whose holders may approve |
| `approver` | authority | a person id | Or one named person who may approve |
| `covers_category` | authority | atom | The kind of item covered; absent covers every kind |
| `up_to` | authority | number | **Tunable.** The largest amount covered; absent means no limit |

## How a decision is reached

Statements about an item are taken in time order (`on`, then `order`):

- **approve** counts when its author has authority over the item and the item's amount is within the statement's own `limit`.
- **reject** from someone with authority clears every approval before it. A later approval supersedes it, so `rejected` and `approved` never both hold.
- **withdraw** counts only from someone whose approval is standing, and removes that approval. A withdrawal from anyone else is reported by `unauthorized_withdrawal` and otherwise ignored.

Authority covers an item when its `approver_role` or `approver` matches the person, its `covers_category` (if any) matches the item's category, and its `up_to` (if any) is at least the item's amount. When the item lacks the category or amount an authority turns on, the battery neither counts the approval nor calls it unauthorized.

## Example

```prolog
attribute(priya, role, manager).
attribute(auth_mgr, approver_role, manager).
attribute(auth_mgr, up_to, 5000).

attribute(laptop_order, title, 'laptop order').
attribute(laptop_order, amount, 3200).

attribute(s1, about, laptop_order).
attribute(s1, act, approve).
attribute(s1, by, priya).
attribute(s1, on, 20754).
```

```prolog
?- approved(laptop_order).
true.
?- approved_by(laptop_order, Who, Day).
Who = priya, Day = 20754.
```

## Notes

- A decision needs two things loaded, declared with `battery_needs/4`: an authority list, and at least one statement about the item. On DataGrout a failed question with either missing comes back **unknown**; the rules alone simply fail.
- An authority with an `up_to` and an item with no `amount` neither approves nor rules out the approval. The rules fail, so the answer reads as "not approved" where unknown would be more honest; a host that can express "required when" should ask for the amount.
- Product-specific shaping (splitting a thread into statements, attaching sender, role and date) belongs to the host that reads the material, not to this battery.
