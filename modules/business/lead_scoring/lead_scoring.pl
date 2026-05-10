%% Tether Module: lead_scoring v1.0.0
%% Exports: lead_score/2, lead_qualified/1, lead_tier/2,
%%          disqualified/2, scoring_factor/3

tether_module(lead_scoring, '1.0.0', auto).

tether_export(lead_scoring, 'lead_score/2',     'lead_score(Lead, Score) — computed numeric score for Lead').
tether_export(lead_scoring, 'lead_qualified/1', 'lead_qualified(Lead) — Lead meets the qualification threshold').
tether_export(lead_scoring, 'lead_tier/2',      'lead_tier(Lead, Tier) — Tier is hot/warm/cold based on score').
tether_export(lead_scoring, 'disqualified/2',   'disqualified(Lead, Reason) — Lead is disqualified and Reason explains why').
tether_export(lead_scoring, 'scoring_factor/3', 'scoring_factor(Lead, Factor, Points) — individual scoring contribution').

%% ── Lead Scoring Data Model ───────────────────────────────────────────────────
%%
%% Lead attributes:
%%   attribute(lead_001, company_size,    enterprise)   %% smb/mid_market/enterprise
%%   attribute(lead_001, budget_confirmed, true)
%%   attribute(lead_001, decision_maker,  true)
%%   attribute(lead_001, industry,        saas)
%%   attribute(lead_001, engagement,      high)         %% low/medium/high
%%   attribute(lead_001, timeline,        q1)           %% q1/q2/q3/q4/unknown
%%
%% Disqualification flags:
%%   attribute(lead_001, competitor,      true)
%%   attribute(lead_001, student,         true)
%%
%% Score weights (override defaults):
%%   attribute(scoring, enterprise_points,     30)
%%   attribute(scoring, budget_points,         25)
%%   attribute(scoring, decision_maker_points, 20)
%%   attribute(scoring, high_engagement_points,15)
%%   attribute(scoring, q1_timeline_points,    10)
%%
%% Thresholds:
%%   attribute(scoring, qualified_threshold, 50)
%%   attribute(scoring, hot_threshold,       70)
%%   attribute(scoring, warm_threshold,      40)

%% ── Disqualification ─────────────────────────────────────────────────────────

disqualified(Lead, competitor) :-
    attribute(Lead, competitor, true).
disqualified(Lead, student) :-
    attribute(Lead, student, true).
disqualified(Lead, no_budget) :-
    attribute(Lead, budget_confirmed, false).

%% ── Scoring factors ──────────────────────────────────────────────────────────

score_weight(enterprise_points,     P) :- attribute(scoring, enterprise_points,     P), !.
score_weight(enterprise_points,     30).
score_weight(mid_market_points,     P) :- attribute(scoring, mid_market_points,     P), !.
score_weight(mid_market_points,     15).
score_weight(budget_points,         P) :- attribute(scoring, budget_points,         P), !.
score_weight(budget_points,         25).
score_weight(decision_maker_points, P) :- attribute(scoring, decision_maker_points, P), !.
score_weight(decision_maker_points, 20).
score_weight(high_engagement_points,P) :- attribute(scoring, high_engagement_points,P), !.
score_weight(high_engagement_points,15).
score_weight(med_engagement_points, P) :- attribute(scoring, med_engagement_points, P), !.
score_weight(med_engagement_points,  8).
score_weight(q1_timeline_points,    P) :- attribute(scoring, q1_timeline_points,    P), !.
score_weight(q1_timeline_points,    10).
score_weight(q2_timeline_points,    P) :- attribute(scoring, q2_timeline_points,    P), !.
score_weight(q2_timeline_points,     5).

scoring_factor(Lead, company_size_enterprise, Points) :-
    attribute(Lead, company_size, enterprise),
    score_weight(enterprise_points, Points).
scoring_factor(Lead, company_size_mid_market, Points) :-
    attribute(Lead, company_size, mid_market),
    score_weight(mid_market_points, Points).
scoring_factor(Lead, budget_confirmed, Points) :-
    attribute(Lead, budget_confirmed, true),
    score_weight(budget_points, Points).
scoring_factor(Lead, decision_maker, Points) :-
    attribute(Lead, decision_maker, true),
    score_weight(decision_maker_points, Points).
scoring_factor(Lead, high_engagement, Points) :-
    attribute(Lead, engagement, high),
    score_weight(high_engagement_points, Points).
scoring_factor(Lead, medium_engagement, Points) :-
    attribute(Lead, engagement, medium),
    score_weight(med_engagement_points, Points).
scoring_factor(Lead, q1_timeline, Points) :-
    attribute(Lead, timeline, q1),
    score_weight(q1_timeline_points, Points).
scoring_factor(Lead, q2_timeline, Points) :-
    attribute(Lead, timeline, q2),
    score_weight(q2_timeline_points, Points).

%% lead_score(+Lead, -Score)
lead_score(Lead, Score) :-
    findall(P, scoring_factor(Lead, _, P), Ps),
    sum_list(Ps, Score).

%% lead_qualified(+Lead)
lead_qualified(Lead) :-
    \+ disqualified(Lead, _),
    lead_score(Lead, Score),
    ( attribute(scoring, qualified_threshold, T) -> true ; T = 50 ),
    Score >= T.

%% lead_tier(+Lead, -Tier)
lead_tier(Lead, hot) :-
    lead_score(Lead, Score),
    ( attribute(scoring, hot_threshold, T) -> true ; T = 70 ),
    Score >= T, !.
lead_tier(Lead, warm) :-
    lead_score(Lead, Score),
    ( attribute(scoring, warm_threshold, T) -> true ; T = 40 ),
    Score >= T, !.
lead_tier(_, cold).
