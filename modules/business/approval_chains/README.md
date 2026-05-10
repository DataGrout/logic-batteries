# Module: approval-chains v1.0.0

Multi-step approval workflows with ordered steps, delegation, rejection tracking, and automatic amount-based escalation. Models the approval state as facts; rules derive whether requests are blocked, pending, or fully approved.

## Install

Add to your DataGrout logic cell via the Hub, or load the raw Prolog directly.

## Exported Predicates

| Predicate | Description |
|---|---|
| `approval_required(Request, Approver)` | Approver must approve Request |
| `approval_granted(Request, Approver)` | Approver has approved (including via delegation) |
| `fully_approved(Request)` | All required approvals received and no rejections |
| `next_approver(Request, Approver)` | Next pending approver in the ordered chain |
| `approval_blocked(Request, Reason)` | Approval cannot proceed; Reason is `rejected(By, Why)` or `awaiting(Approver)` |

## Setup

### Step-based approval chain

Each step is a separate entity keyed however you like. Steps are ordered by their `step` attribute:

```
{ type="attribute", entity="req_001_step1", attribute="request",  value="req_001" }
{ type="attribute", entity="req_001_step1", attribute="approver", value="manager" }
{ type="attribute", entity="req_001_step1", attribute="step",     value=1         }

{ type="attribute", entity="req_001_step2", attribute="request",  value="req_001" }
{ type="attribute", entity="req_001_step2", attribute="approver", value="finance" }
{ type="attribute", entity="req_001_step2", attribute="step",     value=2         }
```

### Recording approvals and rejections

```
# Approval granted
{ type="relation", subject="req_001", relation="approved_by",   object="manager" }

# Rejection (blocks further approval)
{ type="relation", subject="req_001", relation="rejected_by",   object="finance" }
{ type="attribute", entity="req_001", attribute="rejection_reason", value="Budget exceeded" }
```

### Delegation

```
# manager's approvals can be given by deputy
{ type="relation", subject="manager", relation="delegated_to", object="deputy" }
```

`approval_granted` treats an approval by `deputy` as if `manager` approved.

### Amount-based automatic escalation

```
# Any request over 10000 automatically requires CFO approval
{ type="attribute", entity="high_value_rule", attribute="threshold", value=10000 }
{ type="attribute", entity="high_value_rule", attribute="approver",  value="cfo" }

# On the request
{ type="attribute", entity="req_002", attribute="amount", value=15000 }
```

## Querying

```
# Who needs to approve next?
next_approver(req_001, Approver)

# Is this fully approved?
fully_approved(req_001)

# Why is it blocked?
approval_blocked(req_001, Reason)
# → awaiting(finance) or rejected(finance, "Budget exceeded")
```

## Agent Use Cases

**Routing agent**: On new request creation, call `next_approver` and notify that person via their preferred channel.

**Status agent**: When asked "what's the status of req_001?", call `approval_blocked` for a structured answer — rejected with reason, or awaiting a specific person — rather than querying a status field that may be stale.

**Escalation agent**: Nightly job finds all requests where `approval_blocked(Request, awaiting(Approver))` and the approver hasn't acted in N days, then escalates to their manager.

## Why Prolog for Approvals

Approval logic tends to accumulate special cases: delegation, amount thresholds, emergency bypass, department-specific chains. In imperative code these pile up as conditionals. As Prolog rules they compose cleanly — add a new clause, the existing predicates pick it up. `fully_approved` always means "all required approvals, no rejection" regardless of how many approval sources exist.
