:- use_module(library(plunit)).

%% Declared dynamic BEFORE the modules load so tests can assert decision
%% models alongside the modules' sentinel clauses.
:- dynamic prob_rule/2.
:- dynamic action/1.
:- dynamic utility/2.

:- consult('../../modules/probabilistic/prob-core-iso/prob_core_iso').
:- consult('../../modules/probabilistic/prob-decide/prob_decide').

%% The forge-verified portfolio model (README example):
%% EU(sell_now) = 0.7*10 + 0.2*50 = 17, EU(hold) = 0.4*50 + 0.5*(-20) = 10.
setup_portfolio :-
    assertz(action(sell_now)),
    assertz(action(hold)),
    assertz(prob_rule(outcome(sell_now, small_profit), 0.7)),
    assertz(prob_rule(outcome(sell_now, big_profit), 0.2)),
    assertz(prob_rule(outcome(hold, big_profit), 0.4)),
    assertz(prob_rule(outcome(hold, loss), 0.5)),
    assertz(utility(small_profit, 10)),
    assertz(utility(big_profit, 50)),
    assertz(utility(loss, -20)).

%% All candidate actions have negative EU — argmax must still work below
%% zero (exercises the -1.0e300 accumulator floor).
setup_all_bad :-
    assertz(action(gamble)),
    assertz(action(overpay)),
    assertz(prob_rule(outcome(gamble, loss), 0.9)),
    assertz(prob_rule(outcome(overpay, loss), 0.4)),
    assertz(utility(loss, -100)).

setup_tie :-
    assertz(action(first_declared)),
    assertz(action(second_declared)),
    assertz(prob_rule(outcome(first_declared, win), 0.5)),
    assertz(prob_rule(outcome(second_declared, win), 0.5)),
    assertz(utility(win, 10)).

cleanup_model :-
    retractall(prob_rule(_, _)),
    retractall(action(_)),
    retractall(utility(_, _)).

%% ── eu/2 ────────────────────────────────────────────────────────────────────

:- begin_tests(prob_decide_eu).

test(eu_sell_now, [setup(setup_portfolio), cleanup(cleanup_model)]) :-
    eu(sell_now, EU),
    assertion(abs(EU - 17.0) < 1.0e-9).

test(eu_hold, [setup(setup_portfolio), cleanup(cleanup_model)]) :-
    eu(hold, EU),
    assertion(abs(EU - 10.0) < 1.0e-9).

test(eu_unknown_action_is_zero, [setup(setup_portfolio), cleanup(cleanup_model)]) :-
    eu(do_nothing, EU),
    assertion(EU =:= 0.0).

test(eu_on_empty_cell_is_zero, [cleanup(cleanup_model)]) :-
    % sentinels keep this from raising existence_error
    eu(anything, EU),
    assertion(EU =:= 0.0).

test(eu_outcome_without_utility_contributes_nothing, [cleanup(cleanup_model)]) :-
    assertz(action(probe)),
    assertz(prob_rule(outcome(probe, mystery), 0.5)),
    eu(probe, EU),
    assertion(EU =:= 0.0).

test(eu_negative, [setup(setup_all_bad), cleanup(cleanup_model)]) :-
    eu(gamble, EU),
    assertion(abs(EU - (-90.0)) < 1.0e-9).

:- end_tests(prob_decide_eu).

%% ── eu_sum/3 ────────────────────────────────────────────────────────────────

:- begin_tests(prob_decide_eu_sum).

test(sums_list) :-
    eu_sum([1.0, 2.0, 3.0], 0.0, S),
    assertion(abs(S - 6.0) < 1.0e-9).

test(empty_is_accumulator) :-
    eu_sum([], 4.5, S),
    assertion(S =:= 4.5).

:- end_tests(prob_decide_eu_sum).

%% ── best_action/2 ───────────────────────────────────────────────────────────

:- begin_tests(prob_decide_best_action).

test(argmax_portfolio, [setup(setup_portfolio), cleanup(cleanup_model)]) :-
    best_action(Best, EU),
    assertion(Best == sell_now),
    assertion(abs(EU - 17.0) < 1.0e-9).

test(argmax_below_zero, [setup(setup_all_bad), cleanup(cleanup_model)]) :-
    % least-bad action wins: overpay EU = -40 > gamble EU = -90
    best_action(Best, EU),
    assertion(Best == overpay),
    assertion(abs(EU - (-40.0)) < 1.0e-9).

test(tie_first_declared_wins, [setup(setup_tie), cleanup(cleanup_model)]) :-
    % strict > in best_pair keeps the earliest max — deterministic ties
    best_action(Best, _),
    assertion(Best == first_declared).

test(no_actions_fails_cleanly, [fail, cleanup(cleanup_model)]) :-
    best_action(_, _).

:- end_tests(prob_decide_best_action).

%% ── best_pair/5 ─────────────────────────────────────────────────────────────

:- begin_tests(prob_decide_best_pair).

test(picks_max_pair) :-
    best_pair([5.0-x, 9.0-y, 7.0-z], none, -1.0e300, Best, BestEU),
    assertion(Best == y),
    assertion(abs(BestEU - 9.0) < 1.0e-9).

test(empty_keeps_accumulator) :-
    best_pair([], none, -1.0e300, Best, _),
    assertion(Best == none).

:- end_tests(prob_decide_best_pair).
