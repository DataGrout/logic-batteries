# Module: request-policy v1.0.0

Checks expense and purchase requests against a spending policy supplied as data: a maximum amount, when a receipt is needed, when pre-approval is needed, and how soon after the cost a request must be submitted. Limits can be set per category, with policy-wide values and defaults beneath them.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["request-policy"],
    "namespace": "my-namespace"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `request_compliant(Request)` | Request breaks none of the policy's rules |
| `request_violation(Request, Reason)` | Reason is `over_limit`, `missing_receipt`, `needs_preapproval` or `late_submission` |
| `needs_receipt(Request)` | The amount is above the receipt threshold for its category |
| `needs_preapproval(Request)` | The amount is above the pre-approval threshold for its category |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `amount` | request | number | The amount requested |
| `category` | request | atom | Matched against a limit row's `applies_to` |
| `receipt` | request | `true`/`false` | Default `false` |
| `pre_approved` | request | `true`/`false` | Default `false`. A host can set it from an approval decision about the same request |
| `incurred_on` | request | day count | The day the cost was incurred |
| `submitted_on` | request | day count | The day the request was submitted |
| `applies_to` | limit row | atom | The category the row's limits apply to |
| `max_amount` | limit row, `policy` | number | **Tunable.** The most a request may be; no default |
| `receipt_over` | limit row, `policy` | number | **Tunable.** A receipt is needed above this; default 25 |
| `preapproval_over` | limit row, `policy` | number | **Tunable.** Pre-approval is needed above this; default 1000 |
| `submit_within_days` | `policy` | integer | **Tunable.** Default 30 |

A threshold comes from the request's category row, then from the `policy` subject, then from the default above.

## Example

```prolog
attribute(lim_meals, applies_to, meals).
attribute(lim_meals, max_amount, 75).

attribute(r1, amount, 120).
attribute(r1, category, meals).
attribute(r1, receipt, true).
```

```prolog
?- request_violation(r1, Why).
Why = over_limit.
```

## Notes

- A request with no amount is not a request to the rules; on DataGrout a question about it comes back unknown, naming the amount.
- `receipt` and `pre_approved` default to false, so a violation the material never mentions either way rests on that default, and DataGrout reports it as an assumption.
- The `approval` battery decides pre-approval from statements; a host passes its answer in as `pre_approved`.
