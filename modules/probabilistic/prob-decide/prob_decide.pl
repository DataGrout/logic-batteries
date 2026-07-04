%% Battery: prob-decide v1.0.0
%% Requires: prob-core-iso
%% Exports: eu/2, eu_sum/3, best_action/2, best_pair/5
%%
%% DTProbLog-lite decision layer over prob-core-iso: expected utility of
%% actions whose outcomes are weighted rules, and argmax over a declared
%% action set. Pure ISO — runs on SWI and Scryer alike, including ISO-pinned cells.
%%
%% A decision model is three predicate families the author asserts:
%%
%%     action(A).                            % candidate actions
%%     P::outcome(A, O).                     % weighted outcomes per action
%%                                           % (reified: prob_rule(outcome(A,O), P))
%%     utility(O, U).                        % utility of each outcome
%%
%% eu/2 then scores an action as sum(P_i * U_i) over its outcomes, and
%% best_action/2 picks the argmax across action/1.
%%
%% Forged and verified live on a pinned-Scryer namespace
%% on 2026-07-04: EU(sell_now)=17, EU(hold)=10, best=sell_now.

%% Standalone (consult) use: decision-model inputs must be dynamic so an app
%% can assertz them after loading (DG cells strip directives at install).
:- dynamic(prob_rule/2).
:- dynamic(action/1).
:- dynamic(utility/2).
:- dynamic(battery_module/3).
:- dynamic(battery_export/3).

battery_module('prob-decide', '1.0.0', auto).

battery_export('prob-decide', 'eu/2',
    'eu(Action, EU) — EU is the expected utility of Action: the sum of P * utility over every weighted outcome(Action, O) rule').
battery_export('prob-decide', 'eu_sum/3',
    'eu_sum(PUs, Acc, Sum) — accumulator fold summing a list of P*U terms; internal helper for eu/2').
battery_export('prob-decide', 'best_action/2',
    'best_action(Best, BestEU) — Best is the action/1 with the highest expected utility; fails when no actions are declared').
battery_export('prob-decide', 'best_pair/5',
    'best_pair(Pairs, AccA, AccEU, Best, BestEU) — accumulator argmax over EU-Action pairs; internal helper for best_action/2').

%% Sentinels so eu/best_action never raise existence_error on a cell
%% without a decision model yet. Never yield a solution.
action('$prob_decide_none') :- fail.
utility('$prob_decide_none', 0) :- fail.

%% ── Expected utility ──────────────────────────────────────────────────

eu(Action, EU) :-
    findall(PU,
            ( prob_rule(outcome(Action, O), P),
              utility(O, U),
              PU is P * U ),
            PUs),
    eu_sum(PUs, 0.0, EU).

eu_sum([], Acc, Acc).
eu_sum([X|Xs], Acc, S) :-
    Acc1 is Acc + X,
    eu_sum(Xs, Acc1, S).

%% ── Argmax over the declared action set ───────────────────────────────

best_action(Best, BestEU) :-
    findall(EU-A, ( action(A), eu(A, EU) ), Pairs),
    best_pair(Pairs, none, -1.0e300, Best, BestEU),
    Best \= none.

best_pair([], AccA, AccEU, AccA, AccEU).
best_pair([EU-A|Ps], AccA, AccEU, Best, BestEU) :-
    (   EU > AccEU
    ->  best_pair(Ps, A, EU, Best, BestEU)
    ;   best_pair(Ps, AccA, AccEU, Best, BestEU)
    ).
