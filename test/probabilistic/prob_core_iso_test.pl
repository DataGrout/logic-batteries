:- use_module(library(plunit)).

%% prob_rule/2 is declared dynamic BEFORE the module loads so tests can
%% assert weighted rules alongside the module's sentinel clause.
:- dynamic prob_rule/2.
:- dynamic pci_market_open/0.

:- consult('../../modules/probabilistic/prob-core-iso/prob_core_iso').
:- consult('../../modules/probabilistic/prob-core-iso/transform').

%% transform.pl declares op(600, xfx, '::') as its reader reference.
%% Restore the suite-wide priority from test_helpers so files loaded
%% after this one parse annotated clauses unchanged.
:- op(1100, xfx, ::).

setup_market :-
    assertz(prob_rule(market_crash, 0.3)),
    assertz(prob_rule(market_crash, 0.5)).

setup_single :-
    assertz(prob_rule(rain_tomorrow, 0.4)).

setup_conditional :-
    assertz((prob_rule(deal_closes, 0.8) :- pci_market_open)).

%% NOTE: asserts happen in setup predicates (defined in `user`), never in
%% test bodies — plunit compiles bodies into a per-unit module, so an
%% in-body assertz lands in the wrong module and the rule body can't see it.
setup_conditional_open :-
    setup_conditional,
    assertz(pci_market_open).

cleanup_prob :-
    retractall(prob_rule(_, _)),
    retractall(pci_market_open).

%% ── psuccess/2 (noisy-or) ────────────────────────────────────────────────────

:- begin_tests(prob_core_iso_psuccess).

test(noisy_or_two_rules, [setup(setup_market), cleanup(cleanup_prob)]) :-
    % 1 - (1-0.3)*(1-0.5) = 0.65 — the forge-verified oracle number
    psuccess(market_crash, P),
    assertion(abs(P - 0.65) < 1.0e-9).

test(single_rule_is_its_weight, [setup(setup_single), cleanup(cleanup_prob)]) :-
    psuccess(rain_tomorrow, P),
    assertion(abs(P - 0.4) < 1.0e-9).

test(unknown_goal_is_zero, [cleanup(cleanup_prob)]) :-
    psuccess(no_such_goal, P),
    assertion(P =:= 0.0).

test(conditional_rule_closed_world, [setup(setup_conditional), cleanup(cleanup_prob)]) :-
    % body unprovable → the weighted rule contributes nothing
    psuccess(deal_closes, P),
    assertion(P =:= 0.0).

test(conditional_rule_fires_when_body_holds,
     [setup(setup_conditional_open), cleanup(cleanup_prob)]) :-
    psuccess(deal_closes, P),
    assertion(abs(P - 0.8) < 1.0e-9).

:- end_tests(prob_core_iso_psuccess).

%% ── prob_or/2 ────────────────────────────────────────────────────────────────

:- begin_tests(prob_core_iso_prob_or).

test(empty_list_is_zero) :-
    prob_or([], P),
    assertion(P =:= 0.0).

test(two_halves) :-
    prob_or([0.5, 0.5], P),
    assertion(abs(P - 0.75) < 1.0e-9).

test(certainty_dominates) :-
    prob_or([1.0, 0.2], P),
    assertion(abs(P - 1.0) < 1.0e-9).

:- end_tests(prob_core_iso_prob_or).

%% ── pmax/2, pnot/2, pand/2, expected/3 ──────────────────────────────────────

:- begin_tests(prob_core_iso_combinators).

test(pmax_strongest_rule, [setup(setup_market), cleanup(cleanup_prob)]) :-
    pmax(market_crash, P),
    assertion(abs(P - 0.5) < 1.0e-9).

test(pmax_unknown_goal_is_zero, [cleanup(cleanup_prob)]) :-
    pmax(no_such_goal, P),
    assertion(P =:= 0.0).

test(pnot_complements_psuccess, [setup(setup_market), cleanup(cleanup_prob)]) :-
    pnot(market_crash, P),
    assertion(abs(P - 0.35) < 1.0e-9).

test(pand_product, [setup(setup_market), cleanup(cleanup_prob)]) :-
    pand([market_crash, market_crash], P),
    assertion(abs(P - 0.4225) < 1.0e-9).

test(pand_empty_is_one) :-
    pand([], P),
    assertion(P =:= 1.0).

test(expected_value, [setup(setup_market), cleanup(cleanup_prob)]) :-
    expected(market_crash, 100, E),
    assertion(abs(E - 65.0) < 1.0e-9).

:- end_tests(prob_core_iso_combinators).

%% ── problog_transform/2 (the `::` rewrite) ──────────────────────────────────

:- begin_tests(prob_core_iso_transform).

test(weighted_rule_reified) :-
    problog_transform((0.4::alarm :- earthquake), T),
    assertion(T == (prob_rule(alarm, 0.4) :- earthquake)).

test(weighted_fact_reified) :-
    problog_transform(0.7::sunny, T),
    assertion(T == prob_rule(sunny, 0.7)).

test(weighted_compound_head) :-
    problog_transform((0.9::npc_trusts(guard, alice) :- bribed(guard)), T),
    assertion(T == (prob_rule(npc_trusts(guard, alice), 0.9) :- bribed(guard))).

test(plain_rule_passthrough) :-
    problog_transform((plain :- body), T),
    assertion(T == (plain :- body)).

test(plain_fact_passthrough) :-
    problog_transform(fact(x), T),
    assertion(T == fact(x)).

test(var_head_rule_passthrough) :-
    problog_transform((L :- body), T),
    assertion(T == (L :- body)).

test(boundary_weights_accepted) :-
    problog_transform(0.0::never, T0),
    assertion(T0 == prob_rule(never, 0.0)),
    problog_transform(1.0::always, T1),
    assertion(T1 == prob_rule(always, 1.0)).

test(weight_above_one_rejected,
     [throws(error(domain_error(probability, 1.5), _))]) :-
    problog_transform(1.5::too_likely, _).

test(negative_weight_rejected,
     [throws(error(domain_error(probability, -0.1), _))]) :-
    problog_transform(-0.1::impossible, _).

test(non_numeric_weight_rejected,
     [throws(error(domain_error(probability, high), _))]) :-
    problog_transform(high::vague, _).

test(annotated_disjunction_rejected_v1,
     [throws(error(representation_error(annotated_disjunction_unsupported_v1), _))]) :-
    problog_transform(0.3::(heads ; tails), _).

:- end_tests(prob_core_iso_transform).
