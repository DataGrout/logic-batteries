:- use_module(library(plunit)).

:- consult('../../modules/business/lead_scoring/lead_scoring').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_enterprise_lead :-
    assertz(attribute(lead_001, company_size, enterprise)).

setup_mid_market_lead :-
    assertz(attribute(lead_001, company_size, mid_market)).

setup_budget_confirmed :-
    assertz(attribute(lead_001, budget_confirmed, true)).

setup_budget_false :-
    assertz(attribute(lead_001, budget_confirmed, false)).

setup_decision_maker :-
    assertz(attribute(lead_001, decision_maker, true)).

setup_high_engagement :-
    assertz(attribute(lead_001, engagement, high)).

setup_med_engagement :-
    assertz(attribute(lead_001, engagement, medium)).

setup_q1_timeline :-
    assertz(attribute(lead_001, timeline, q1)).

setup_q2_timeline :-
    assertz(attribute(lead_001, timeline, q2)).

setup_competitor :-
    assertz(attribute(lead_001, competitor, true)).

setup_student :-
    assertz(attribute(lead_001, student, true)).

setup_hot_lead :-
    setup_enterprise_lead,
    setup_budget_confirmed,
    setup_decision_maker,
    setup_high_engagement,
    setup_q1_timeline.
    %% 30+25+20+15+10 = 100

setup_qualified_lead :-
    setup_enterprise_lead,
    setup_budget_confirmed.
    %% 30+25 = 55, above 50 threshold

setup_cold_lead :-
    setup_mid_market_lead.
    %% 15 points only

%% ── disqualified/2 ───────────────────────────────────────────────────────────

:- begin_tests(lead_disqualified).

test(competitor_disqualified, [setup(setup_competitor), cleanup(clear_facts)]) :-
    assertion(disqualified(lead_001, competitor)).

test(student_disqualified, [setup(setup_student), cleanup(clear_facts)]) :-
    assertion(disqualified(lead_001, student)).

test(no_budget_disqualified, [setup(setup_budget_false), cleanup(clear_facts)]) :-
    assertion(disqualified(lead_001, no_budget)).

test(clean_lead_not_disqualified, [setup(setup_enterprise_lead), cleanup(clear_facts)]) :-
    assertion(\+ disqualified(lead_001, _)).

:- end_tests(lead_disqualified).

%% ── scoring_factor/3 ─────────────────────────────────────────────────────────

:- begin_tests(lead_scoring_factors).

test(enterprise_factor, [setup(setup_enterprise_lead), cleanup(clear_facts)]) :-
    scoring_factor(lead_001, company_size_enterprise, P), assertion(P == 30).

test(mid_market_factor, [setup(setup_mid_market_lead), cleanup(clear_facts)]) :-
    scoring_factor(lead_001, company_size_mid_market, P), assertion(P == 15).

test(budget_factor, [setup(setup_budget_confirmed), cleanup(clear_facts)]) :-
    scoring_factor(lead_001, budget_confirmed, P), assertion(P == 25).

test(decision_maker_factor, [setup(setup_decision_maker), cleanup(clear_facts)]) :-
    scoring_factor(lead_001, decision_maker, P), assertion(P == 20).

test(high_engagement_factor, [setup(setup_high_engagement), cleanup(clear_facts)]) :-
    scoring_factor(lead_001, high_engagement, P), assertion(P == 15).

test(med_engagement_factor, [setup(setup_med_engagement), cleanup(clear_facts)]) :-
    scoring_factor(lead_001, medium_engagement, P), assertion(P == 8).

test(q1_timeline_factor, [setup(setup_q1_timeline), cleanup(clear_facts)]) :-
    scoring_factor(lead_001, q1_timeline, P), assertion(P == 10).

test(q2_timeline_factor, [setup(setup_q2_timeline), cleanup(clear_facts)]) :-
    scoring_factor(lead_001, q2_timeline, P), assertion(P == 5).

:- end_tests(lead_scoring_factors).

%% ── lead_score/2 ─────────────────────────────────────────────────────────────

:- begin_tests(lead_score).

test(hot_lead_score, [setup(setup_hot_lead), cleanup(clear_facts)]) :-
    lead_score(lead_001, S), assertion(S == 100).

test(empty_lead_zero, [cleanup(clear_facts)]) :-
    lead_score(lead_001, S), assertion(S == 0).

test(qualified_lead_score, [setup(setup_qualified_lead), cleanup(clear_facts)]) :-
    lead_score(lead_001, S), assertion(S == 55).

:- end_tests(lead_score).

%% ── lead_qualified/1 ─────────────────────────────────────────────────────────

:- begin_tests(lead_qualified).

test(qualified_above_threshold, [setup(setup_qualified_lead), cleanup(clear_facts)]) :-
    assertion(lead_qualified(lead_001)).

test(not_qualified_low_score, [setup(setup_cold_lead), cleanup(clear_facts)]) :-
    assertion(\+ lead_qualified(lead_001)).

test(competitor_not_qualified, [setup((setup_hot_lead, setup_competitor)), cleanup(clear_facts)]) :-
    assertion(\+ lead_qualified(lead_001)).

:- end_tests(lead_qualified).

%% ── lead_tier/2 ──────────────────────────────────────────────────────────────

:- begin_tests(lead_tier).

test(hot_tier, [setup(setup_hot_lead), cleanup(clear_facts)]) :-
    lead_tier(lead_001, T), assertion(T == hot).

test(warm_tier, [setup(setup_qualified_lead), cleanup(clear_facts)]) :-
    %% 55 points → warm (>=40) but not hot (>=70)
    lead_tier(lead_001, T), assertion(T == warm).

test(cold_tier, [setup(setup_cold_lead), cleanup(clear_facts)]) :-
    %% 15 points → cold
    lead_tier(lead_001, T), assertion(T == cold).

:- end_tests(lead_tier).
