%% Battery: lead_scoring v1.0.0
%% Exports: lead_score/2, lead_qualified/1, lead_tier/2,
%%          disqualified/2, scoring_factor/3

battery_module(lead_scoring, '1.0.0', auto).

battery_export(lead_scoring, 'lead_score/2',     'lead_score(Lead, Score) — computed numeric score for Lead').
battery_export(lead_scoring, 'lead_qualified/1', 'lead_qualified(Lead) — Lead meets the qualification threshold').
battery_export(lead_scoring, 'lead_tier/2',      'lead_tier(Lead, Tier) — Tier is hot/warm/cold based on score').
battery_export(lead_scoring, 'disqualified/2',   'disqualified(Lead, Reason) — Lead is disqualified and Reason explains why').
battery_export(lead_scoring, 'scoring_factor/3', 'scoring_factor(Lead, Factor, Points) — individual scoring contribution').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). The rules never
%% enumerate leads; a lead is whatever the caller asks about, and every lead
%% record carries a size or an engagement level. Weights and thresholds all
%% live on the fixed subject `scoring` and all have defaults.

battery_input(lead_scoring, lead, attribute(company_size), enum([enterprise, mid_market]), key,
    'Company size: enterprise or mid_market score points; any other size (smb) scores nothing.').
battery_input(lead_scoring, lead, attribute(engagement), enum([high, medium]), key,
    'Engagement level: high or medium score points; low or absent scores nothing.').
battery_input(lead_scoring, lead, attribute(budget_confirmed), bool, optional,
    'true scores budget_points; false disqualifies the lead (no_budget); absent does neither.').
battery_input(lead_scoring, lead, attribute(decision_maker), bool, default(false),
    'true when the contact can sign; scores decision_maker_points.').
battery_input(lead_scoring, lead, attribute(timeline), enum([q1, q2]), optional,
    'Quarter the lead expects to buy in: q1 or q2 score points; later or unknown scores nothing.').
battery_input(lead_scoring, lead, attribute(competitor), bool, default(false),
    'true when the lead works for a competitor; disqualifies it.').
battery_input(lead_scoring, lead, attribute(student), bool, default(false),
    'true when the lead is a student; disqualifies it.').
battery_input(lead_scoring, fixed(scoring), attribute(enterprise_points), number, default(30),
    'Points for an enterprise company.').
battery_input(lead_scoring, fixed(scoring), attribute(mid_market_points), number, default(15),
    'Points for a mid-market company.').
battery_input(lead_scoring, fixed(scoring), attribute(budget_points), number, default(25),
    'Points for a confirmed budget.').
battery_input(lead_scoring, fixed(scoring), attribute(decision_maker_points), number, default(20),
    'Points for a decision maker.').
battery_input(lead_scoring, fixed(scoring), attribute(high_engagement_points), number, default(15),
    'Points for high engagement.').
battery_input(lead_scoring, fixed(scoring), attribute(med_engagement_points), number, default(8),
    'Points for medium engagement.').
battery_input(lead_scoring, fixed(scoring), attribute(q1_timeline_points), number, default(10),
    'Points for a q1 timeline.').
battery_input(lead_scoring, fixed(scoring), attribute(q2_timeline_points), number, default(5),
    'Points for a q2 timeline.').
battery_input(lead_scoring, fixed(scoring), attribute(qualified_threshold), number, default(50),
    'Score at or above which a lead that is not disqualified is qualified.').
battery_input(lead_scoring, fixed(scoring), attribute(hot_threshold), number, default(70),
    'Score at or above which a lead is hot.').
battery_input(lead_scoring, fixed(scoring), attribute(warm_threshold), number, default(40),
    'Score at or above which a lead is warm; below it the lead is cold.').

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
