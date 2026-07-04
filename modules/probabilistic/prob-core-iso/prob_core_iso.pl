%% Battery: prob-core-iso v1.0.0
%% License: Apache-2.0 (see LICENSE in this directory — unlike the rest of
%% this repository, this core runtime module is permissively licensed so it
%% can be embedded anywhere without restriction).
%% Requires: (nothing)
%% Exports: psuccess/2, pmax/2, pnot/2, pand/2, expected/3, prob_or/2
%%
%% ISO-safe ProbLog-lite runtime. Pure ISO, so it runs identically on SWI and
%% Scryer — its reason to exist is the ISO-pinned (Scryer) path, where it
%% delivers ProbLog-style reasoning without SWI escalation.
%%
%% Weighted clauses live in the reified form
%%
%%     prob_rule(Head, P) :- Body.
%%
%% which is what `P::Head :- Body.` rewrites to at install/assert time
%% (see transform.pl and README). The `::` operator itself never reaches
%% the cell, so nothing here requires non-ISO syntax or an op/3 pin.
%%
%% Semantics: psuccess/2 combines all weighted rule instances proving a
%% goal with noisy-or under the INDEPENDENT-RULES assumption — each
%% weighted rule instance is treated as an independent trigger. This is
%% exact when rules do not share probabilistic antecedents across
%% derivations, and an approximation when they do. pmax/2 reproduces the
%% legacy max_list behavior of the earlier prob-* batteries. Exact
%% distribution semantics (shared facts, explanation dedup) is planned
%% for a v2 backed by host-side tabling.

%% Standalone (consult) use: input predicates must be dynamic so an app can
%% assertz its weighted rules after loading. Inside DG logic cells these
%% directives are stripped at install time (everything is asserted, hence
%% already dynamic) — they exist for bare swipl/scryer-prolog consumers.
:- dynamic(prob_rule/2).
:- dynamic(battery_module/3).
:- dynamic(battery_export/3).

battery_module('prob-core-iso', '1.0.0', auto).

battery_export('prob-core-iso', 'psuccess/2',
    'psuccess(Goal, P) — P is the noisy-or combination of every weighted rule instance proving Goal (independent-rules assumption)').
battery_export('prob-core-iso', 'pmax/2',
    'pmax(Goal, P) — P is the strongest single weighted rule proving Goal (legacy prob-* battery semantics)').
battery_export('prob-core-iso', 'pnot/2',
    'pnot(Goal, P) — P is 1 - psuccess(Goal)').
battery_export('prob-core-iso', 'pand/2',
    'pand(Goals, P) — P is the product of psuccess over a list of goals (independence assumption)').
battery_export('prob-core-iso', 'expected/3',
    'expected(Goal, Value, E) — E is psuccess(Goal) * Value; expected-value helper').
battery_export('prob-core-iso', 'prob_or/2',
    'prob_or(Ps, P) — noisy-or fold of a probability list: P = 1 - prod(1 - Pi)').

%% Sentinel so findall/3 never raises existence_error on a cell that has
%% no weighted rules yet. Never yields a solution.
prob_rule('$prob_core_iso_none', 0.0) :- fail.

%% ── Core combinators ──────────────────────────────────────────────────

psuccess(Goal, P) :-
    findall(Pi, prob_rule(Goal, Pi), Ps),
    prob_or(Ps, P).

prob_or([], 0.0).
prob_or([Q|Qs], P) :-
    prob_or(Qs, PR),
    P is 1.0 - (1.0 - Q) * (1.0 - PR).

pmax(Goal, P) :-
    findall(Pi, prob_rule(Goal, Pi), Ps),
    pmax_list(Ps, 0.0, P).

pmax_list([], Acc, Acc).
pmax_list([Q|Qs], Acc, P) :-
    ( Q > Acc -> pmax_list(Qs, Q, P) ; pmax_list(Qs, Acc, P) ).

pnot(Goal, P) :-
    psuccess(Goal, PS),
    P is 1.0 - PS.

pand([], 1.0).
pand([G|Gs], P) :-
    psuccess(G, PG),
    pand(Gs, PR),
    P is PG * PR.

expected(Goal, Value, E) :-
    psuccess(Goal, P),
    E is P * Value.
