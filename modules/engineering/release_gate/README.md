# Module: release-gate v1.0.0

Decides whether a change (a pull or merge request) can ship: every required check passed on its head commit, enough reviewers approve it with no outstanding request for changes, its coverage meets the minimum, and no change freeze is on. Each check result and each review is its own record, so a re-run or a second review keeps its history and the latest one counts.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["release-gate"],
    "namespace": "my-namespace"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `release_ready(Change)` | Required checks passed, approvals met, no changes requested, coverage met, outside any freeze |
| `gate_blocker(Change, Reason)` | Reason is `check_failed(Check)`, `check_pending(Check)`, `check_missing(Check)`, `approvals_short(Have, Need)`, `changes_requested(Reviewer)`, `coverage_below(Have, Min)` or `change_freeze(Freeze)` |
| `check_outcome(Change, Check, Outcome)` | The latest result of a required check: `passed`, `failed`, `pending` or `missing` |
| `approval_count(Change, N)` | Reviewers whose latest review approves |
| `approved_by(Change, Reviewer)` | Reviewer's latest review approves |
| `in_freeze(Change, Freeze)` | Today is inside Freeze and the change is not an emergency |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `number` | change | integer | The change's number in its repository |
| `head` | change | atom | Required. The head commit SHA. Results and approvals for another commit are stale |
| `coverage` | change | number | Coverage of the head commit, in percent. Needed when `min_coverage` is set |
| `emergency` | change | `true`/`false` | Default `false`. `true` ships through a change freeze |
| `check_of` | check | change id | The change the result is for |
| `check_name` | check | atom | The check's name as the required list spells it |
| `outcome` | check | `success`, `failure`, `neutral`, `skipped`, `cancelled`, `timed_out`, `action_required`, `stale` or `pending` | `success`, `neutral` and `skipped` pass |
| `on_commit` | check, review | atom | The commit it ran on or reviewed. Required on a check: only a result for the head counts |
| `order` | check, review | integer | Position among results of one check, or one reviewer's reviews; highest is latest |
| `app_id` | check | integer | The app that reported the result |
| `review_of` | review | change id | The change reviewed |
| `reviewer` | review | atom | Who reviewed |
| `verdict` | review | `approved`, `changes_requested`, `commented` or `dismissed` | A comment-only review leaves the earlier verdict standing |
| `requires_check` | required check | atom | A check every change must pass |
| `requires_app` | required check | integer | Only this app's result counts for the check; absent, any app's does |
| `freeze_from` | freeze | day count | First day of a change freeze |
| `freeze_until` | freeze | day count | Last day, inclusive |
| `absolute_days` | `today` | day count | Needed when a freeze is recorded |
| `min_approvals` | `gate` | integer | **Tunable.** Default 1 |
| `min_coverage` | `gate` | number | **Tunable.** No default: coverage is not checked |
| `dismiss_stale_approvals` | `gate` | `true`/`false` | **Tunable.** Default `false`. `true`: an approval of an older commit no longer counts |

## Example

```prolog
attribute(rc_test, requires_check, 'ci/test').

attribute(pr_7, head, c0ffee).
attribute(k1, check_of, pr_7).
attribute(k1, check_name, 'ci/test').
attribute(k1, outcome, failure).
attribute(r1, review_of, pr_7).
attribute(r1, reviewer, ana).
attribute(r1, verdict, approved).
```

```prolog
?- gate_blocker(pr_7, Why).
Why = check_failed('ci/test').
```

## Notes

- Without the change's head commit nothing can be told fresh, so `release_ready` does not hold; on DataGrout the answer is unknown, naming `head`.
- Without a required-check list, or with no check result for the change at all, `release_ready` does not hold; on DataGrout such a question comes back unknown, naming what is missing, rather than no.
- A recorded freeze with no `today` leaves the freeze undecided, so `release_ready` does not hold and no blocker is reported; on DataGrout the answer is unknown, naming today.
- A change with no reviews loaded has no approvals: the gate reads that as zero, not as unknown.
