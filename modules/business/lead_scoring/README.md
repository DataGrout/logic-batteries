# Module: lead-scoring v1.0.0

Weighted lead scoring across company size, budget, decision-maker status, engagement level, and timeline. Automatic disqualification for competitors and students. Hot/warm/cold tier derivation with configurable thresholds and weights.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["lead-scoring"],
    "namespace": "my-namespace"
})
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `lead_score(Lead, Score)` | Computed numeric score for Lead |
| `lead_qualified(Lead)` | Lead meets the qualification threshold and is not disqualified |
| `lead_tier(Lead, Tier)` | Tier is `hot`/`warm`/`cold` based on score |
| `disqualified(Lead, Reason)` | Lead is disqualified; Reason is `competitor`/`student`/`no_budget` |
| `scoring_factor(Lead, Factor, Points)` | Individual scoring contribution for inspection |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `company_size` | lead | `enterprise` \| `mid_market` | Scores `enterprise_points` or `mid_market_points`. Any other value (`smb`, absent) scores nothing |
| `budget_confirmed` | lead | `true` \| `false` | `true` scores `budget_points`. `false` **disqualifies** (`no_budget`); absent does neither |
| `decision_maker` | lead | `true` | Scores `decision_maker_points` |
| `engagement` | lead | `high` \| `medium` | Scores `high_engagement_points` or `med_engagement_points`; `low` or absent scores nothing |
| `timeline` | lead | `q1` \| `q2` | Scores `q1_timeline_points` or `q2_timeline_points`; later quarters score nothing |
| `competitor` | lead | `true` | Disqualifies, reason `competitor` |
| `student` | lead | `true` | Disqualifies, reason `student` |
| `enterprise_points` | `scoring` | number | Weight override; default 30 |
| `mid_market_points` | `scoring` | number | Default 15 |
| `budget_points` | `scoring` | number | Default 25 |
| `decision_maker_points` | `scoring` | number | Default 20 |
| `high_engagement_points` | `scoring` | number | Default 15 |
| `med_engagement_points` | `scoring` | number | Default 8 |
| `q1_timeline_points` | `scoring` | number | Default 10 |
| `q2_timeline_points` | `scoring` | number | Default 5 |
| `qualified_threshold` | `scoring` | number | Score at or above which `lead_qualified` holds (unless disqualified); default 50 |
| `hot_threshold` | `scoring` | number | Score at or above which `lead_tier` is `hot`; default 70 |
| `warm_threshold` | `scoring` | number | Score at or above which it is `warm`; default 40. Below is `cold` |

`scoring` is a fixed entity name: every weight and threshold lives on it, and
each is optional — assert only the ones you want to change. `industry` appears
in the source comments but no clause reads it.

## Default Scoring Weights

| Factor | Points |
|---|---|
| Enterprise company | 30 |
| Mid-market company | 15 |
| Budget confirmed | 25 |
| Decision maker | 20 |
| High engagement | 15 |
| Medium engagement | 8 |
| Q1 timeline | 10 |
| Q2 timeline | 5 |

All weights are configurable. Override any weight:
```
{ type="attribute", entity="scoring", attribute="enterprise_points", value=40 }
```

**Default thresholds**: qualified ≥ 50, hot ≥ 70, warm ≥ 40.

## Setup

```
# Lead attributes
{ type="attribute", entity="lead_001", attribute="company_size",     value="enterprise" }
{ type="attribute", entity="lead_001", attribute="budget_confirmed", value=true }
{ type="attribute", entity="lead_001", attribute="decision_maker",   value=true }
{ type="attribute", entity="lead_001", attribute="engagement",       value="high" }
{ type="attribute", entity="lead_001", attribute="timeline",         value="q1" }

# Disqualification flags
{ type="attribute", entity="lead_001", attribute="competitor", value=true }
```

## Querying

```
# Get total score
lead_score(lead_001, Score)

# Check if qualified (not disqualified AND score >= threshold)
lead_qualified(lead_001)

# Get tier for prioritisation
lead_tier(lead_001, Tier)

# Inspect why a lead scored the way it did
scoring_factor(lead_001, Factor, Points)
```

## Agent Use Cases

**Routing agent**: Query `lead_tier` to assign hot leads to senior reps, warm to SDRs, cold to nurture sequences — without encoding the scoring logic in the routing prompt.

**Review agent**: Run `scoring_factor` to explain *why* a lead scored as it did, producing auditable reasoning rather than a black-box score.

**Threshold tuning**: Assert new weight overrides to adjust scoring strategy per-campaign. The change takes effect on the next query — no code deployment needed.

## Disqualification

A disqualified lead never passes `lead_qualified`, regardless of score. Use `disqualified(Lead, Reason)` to surface the reason in downstream workflows rather than silently dropping the lead.
