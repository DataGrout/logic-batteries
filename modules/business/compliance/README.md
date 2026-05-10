# Module: compliance v1.0.0

Policy compliance checks, violation surfacing by missing requirement, data retention window validation, consent type mapping to actions, and consent registry queries. Models compliance as queryable rules rather than imperative checks — add a new policy requirement by asserting a relation, not by editing code.

## Install

Add to your DataGrout logic cell via the Hub, or load the raw Prolog directly.

## Exported Predicates

| Predicate | Description |
|---|---|
| `compliant(Entity, Policy)` | Entity satisfies all requirements of Policy |
| `violation(Entity, Policy, Reason)` | Entity violates Policy; Reason is `missing_requirement(Req)` |
| `data_retention_ok(Record, Policy)` | Record is within the retention window of Policy |
| `consent_required(Action, ConsentType)` | ConsentType must be obtained before performing Action |
| `consent_given(Customer, ConsentType)` | Customer has granted ConsentType consent |

## Setup

### Policies and requirements

```
# GDPR requires marketing consent and data minimization
{ type="relation", subject="gdpr",  relation="requires", object="marketing_consent" }
{ type="relation", subject="gdpr",  relation="requires", object="data_minimization" }

# HIPAA requires encryption and audit logging
{ type="relation", subject="hipaa", relation="requires", object="phi_encryption" }
{ type="relation", subject="hipaa", relation="requires", object="audit_log"      }
```

### Entity compliance attributes

Assert each requirement as an attribute on the entity being checked:

```
{ type="attribute", entity="customer_123", attribute="marketing_consent", value=true }
{ type="attribute", entity="customer_123", attribute="data_minimization", value=true }
```

A requirement is considered met when the attribute value is not `false`, `none`, or `missing`.

### Data retention

```
# Policy retention window (days)
{ type="attribute", entity="gdpr",  attribute="retention_days", value=2555 }  -- 7 years
{ type="attribute", entity="hipaa", attribute="retention_days", value=2190 }  -- 6 years

# Record creation date (YYYYMMDD integer — same format as scheduling module)
{ type="attribute", entity="record_456", attribute="created_day", value=20240101 }

# Today (required at runtime)
{ type="attribute", entity="today", attribute="date", value=20260510 }
```

### Consent mapping

```
# Action → consent type
{ type="attribute", entity="send_newsletter",  attribute="requires_consent", value="marketing" }
{ type="attribute", entity="track_behavior",   attribute="requires_consent", value="analytics" }

# Customer consent grants
{ type="relation", subject="customer_123", relation="granted_consent", object="marketing" }
{ type="relation", subject="customer_123", relation="granted_consent", object="analytics" }
```

## Querying

```
# Is the entity fully compliant?
compliant(customer_123, gdpr)

# What is it violating?
violation(customer_123, gdpr, Reason)
# → missing_requirement(marketing_consent)

# Is a record still within its retention window?
data_retention_ok(record_456, gdpr)

# Does this action require consent?
consent_required(send_newsletter, ConsentType)

# Has the customer given it?
consent_given(customer_123, marketing)
```

## Agent Use Cases

**Pre-action compliance gate**: Before an agent sends a marketing email, check `consent_required(send_newsletter, C)` and `consent_given(customer, C)`. If consent is absent, the agent routes to a consent-collection workflow instead.

**Compliance audit agent**: Run `violation(Entity, Policy, Reason)` across all entities in a namespace to produce a compliance gap report with specific missing requirements — not just "compliant: no".

**Retention sweep agent**: Query `data_retention_ok(Record, Policy)` for all records. Records where this fails need deletion or archival. The logic is in the LC; the agent handles the execution.

**Policy updates**: When a regulation changes and requires a new condition, assert a new `relation(policy, requires, new_requirement)`. Every entity is immediately subject to the new check on the next query — no code change needed.

## Design Note

Compliance policies are intentionally data-driven rather than hard-coded. The module doesn't know what GDPR or HIPAA mean — it only knows how to check whether a set of requirements are met. This means you can model any policy by asserting its requirements as relations, without modifying the battery.
