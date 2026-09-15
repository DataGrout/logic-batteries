%% Battery: assign v1.0.1
%% Requires: (nothing)
%% Exports: assign_domain/2, assign_solve/2, assign_solve/3, assign_best/3,
%%          assign_violations/2, assign_reject/2, assign_reject_pair/4, assign_cost/3

:- dynamic(relation/3).
:- dynamic(attribute/3).
:- dynamic(assign_reject/2).
:- dynamic(assign_reject_pair/4).
:- dynamic(assign_cost/3).

battery_module(assign, '1.0.1', auto).

battery_export(assign, 'assign_domain/2',
    'assign_domain(Var, Values) — the candidate values of Var that survive the unary assign_reject/2 hook').
battery_export(assign, 'assign_solve/2',
    'assign_solve(Vars, Result) — assign_solve/3 with a default budget of 10000 search nodes').
battery_export(assign, 'assign_solve/3',
    'assign_solve(Vars, Budget, Result) — find one assignment of every Var to a value from its domain that satisfies all distinct groups and hooks. Result is solution(Assignment, Explored) | unsat(Explored) | unsat(empty_domain(Var)) | budget_exhausted(Explored); Assignment is a list of Var-Value').
battery_export(assign, 'assign_best/3',
    'assign_best(Vars, Budget, Result) — like assign_solve/3 but minimises the sum of assign_cost/3 over the assignment by branch and bound. Result is best(Assignment, Cost, Explored, complete | budget_exhausted) | unsat(Explored) | unsat(empty_domain(Var))').
battery_export(assign, 'assign_violations/2',
    'assign_violations(Assignment, Violations) — check a given list of Var-Value pairs: each violation is rejected(Var, Value) | pair(Var1, Value1, Var2, Value2) | distinct(Group, Var1, Var2); [] means the assignment is consistent').
battery_export(assign, 'assign_reject/2',
    'assign_reject(Var, Value) — HOOK: add clauses to forbid Value for Var. The battery keeps a value only if this fails. Undefined = nothing rejected').
battery_export(assign, 'assign_reject_pair/4',
    'assign_reject_pair(Var1, Value1, Var2, Value2) — HOOK: add clauses to forbid two assignments together. Checked in both argument orders').
battery_export(assign, 'assign_cost/3',
    'assign_cost(Var, Value, Cost) — HOOK: add clauses to price an assignment; values are tried cheapest first and assign_best/3 minimises the total. Undefined = cost 0').

%% ── Model ────────────────────────────────────────────────────────────────────
%%
%% Variables and domains:
%%   attribute(slot_mon_am, domain, [alvarez, chen, okafor]).
%%
%% All-different groups. The SUBJECT is the group and the OBJECT is a member —
%% one fact per member, not a pairwise statement. Writing
%% `relation(slot_mon_am, distinct, slot_mon_pm)` reads as "the group
%% slot_mon_am contains slot_mon_pm", which constrains nothing and raises no
%% error. A variable may sit in several groups:
%%   relation(monday, distinct, slot_mon_am).
%%   relation(monday, distinct, slot_mon_pm).
%%
%% Hooks — open predicates. The battery ships a base clause that always fails,
%% so an unhooked model is unconstrained beyond its domains and groups. Add
%% clauses in the same namespace to constrain it; other batteries' predicates
%% are the natural constraint vocabulary:
%%   assign_reject(Slot, W) :-
%%       attribute(Slot, start, S), attribute(Slot, end, E),
%%       \+ fit_for_duty(W, Slot, S, E).            %% from the duty battery
%%   assign_reject_pair(S1, W, S2, W) :-
%%       overlapping_slots(S1, S2).                  %% same person, two overlapping slots
%%   assign_cost(Slot, W, C) :- attribute(W, hourly_rate, C).
%%
%% Search: depth-first over an explicit agenda, so the node budget is a real
%% global bound and not a per-branch one. Minimum-remaining-values picks the
%% next variable; forward checking prunes the others after every choice;
%% values are tried cheapest first when assign_cost/3 is hooked.
%% Instances are expected to be small — dozens of variables, dozens of values.

%% ── Declared fact shapes ─────────────────────────────────────────────────────
%%
%% The host derives `relation(Subject, distinct, Object)` from the rule text,
%% and that generic wording invites "x is distinct from y" — which parses,
%% stores, constrains nothing and raises no error. Say what the arguments mean.

battery_fact_shape(relation, distinct, 'relation(Group, distinct, Var)',
    'Group membership, not a pairwise statement: one fact per member. relation(g1, distinct, x) together with relation(g1, distinct, y) makes x and y take different values. A group holds any number of members, and a variable may sit in several groups.').

battery_fact_shape(attribute, domain, 'attribute(Var, domain, [Value, ...])',
    'The list of values this variable may take. A variable with no domain fact is unsolvable: assign_solve reports unsat(empty_domain(Var)).').

%% ── Hook base clauses ────────────────────────────────────────────────────────

assign_reject(_, _) :- fail.
assign_reject_pair(_, _, _, _) :- fail.
assign_cost(_, _, _) :- fail.

%% ── Domains ──────────────────────────────────────────────────────────────────

%% A variable has one domain; commit to the first declared.
assign_domain(Var, Values) :-
    attribute(Var, domain, Raw), !,
    assign_unary_filter(Raw, Var, Values).

assign_unary_filter([], _, []).
assign_unary_filter([X|Xs], Var, Out) :-
    (   assign_reject(Var, X)
    ->  Out = Rest
    ;   Out = [X|Rest]
    ),
    assign_unary_filter(Xs, Var, Rest).

%% Var-Dom pairs for every variable, cheapest values first.
assign_init([], []).
assign_init([V|Vs], [V-Dom|Ds]) :-
    (   attribute(V, domain, _)
    ->  assign_domain(V, D0),
        assign_order_values(V, D0, Dom)
    ;   Dom = []                          %% no domain declared: treat as empty
    ),
    assign_init(Vs, Ds).

assign_order_values(Var, Values, Ordered) :-
    findall(C-X, ( member(X, Values), assign_value_cost(Var, X, C) ), Pairs),
    sort(Pairs, Sorted),                  %% sort/2 is ISO (Scryer has no msort/2); duplicates collapse harmlessly
    assign_strip_keys(Sorted, Ordered).

assign_value_cost(Var, X, C) :-
    (   assign_cost(Var, X, C0)
    ->  C = C0
    ;   C = 0
    ).

assign_strip_keys([], []).
assign_strip_keys([_-X|Ps], [X|Xs]) :- assign_strip_keys(Ps, Xs).

assign_empty_domain([V-[]|_], V) :- !.
assign_empty_domain([_|Ds], V) :- assign_empty_domain(Ds, V).

%% ── Consistency ──────────────────────────────────────────────────────────────

%% Var=Value is consistent with the already assigned pairs.
assign_consistent(Var, Value, Assigned) :-
    \+ assign_distinct_clash(Var, Value, Assigned),
    \+ assign_pair_clash(Var, Value, Assigned).

assign_distinct_clash(Var, Value, Assigned) :-
    relation(G, distinct, Var),
    member(V2-Value, Assigned),
    V2 \== Var,
    relation(G, distinct, V2).

assign_pair_clash(Var, Value, Assigned) :-
    member(V2-X2, Assigned),
    (   assign_reject_pair(Var, Value, V2, X2)
    ;   assign_reject_pair(V2, X2, Var, Value)
    ).

%% Forward checking: drop values of the remaining variables that clash with
%% the new assignment; fail if any domain empties.
assign_prune([], _, _, []).
assign_prune([V-D|Ds], Var, Value, [V-D1|Ds1]) :-
    assign_prune_values(D, V, Var, Value, D1),
    D1 \== [],
    assign_prune(Ds, Var, Value, Ds1).

assign_prune_values([], _, _, _, []).
assign_prune_values([X|Xs], V, Var, Value, Out) :-
    (   assign_consistent(V, X, [Var-Value])
    ->  Out = [X|Rest]
    ;   Out = Rest
    ),
    assign_prune_values(Xs, V, Var, Value, Rest).

%% ── Variable ordering (minimum remaining values) ─────────────────────────────

assign_pick(Doms, Var-Dom, Rest) :-
    findall(L-(V-D), ( member(V-D, Doms), length(D, L) ), Keyed),
    sort(Keyed, [_-(Var-Dom)|_]),
    assign_remove(Var, Doms, Rest).

assign_remove(_, [], []).
assign_remove(Var, [V-D|Ds], Rest) :-
    (   V == Var
    ->  Rest = Ds
    ;   Rest = [V-D|Rest1],
        assign_remove(Var, Ds, Rest1)
    ).

%% ── Children of a search frame ───────────────────────────────────────────────

%% One child frame per value of Var that is consistent and leaves every other
%% domain non-empty. Domain order is preserved (cheapest first).
assign_children([], _, _, _, _, []).
assign_children([X|Xs], Var, Rest, Assigned, Cost, Children) :-
    (   assign_consistent(Var, X, Assigned),
        assign_prune(Rest, Var, X, Pruned)
    ->  assign_value_cost(Var, X, C),
        Cost1 is Cost + C,
        Children = [frame(Pruned, [Var-X|Assigned], Cost1)|More]
    ;   Children = More
    ),
    assign_children(Xs, Var, Rest, Assigned, Cost, More).

%% ── Satisfy: first solution ──────────────────────────────────────────────────

assign_solve(Vars, Result) :-
    assign_solve(Vars, 10000, Result).

assign_solve(Vars, Budget, Result) :-
    assign_init(Vars, Doms),
    (   assign_empty_domain(Doms, V)
    ->  Result = unsat(empty_domain(V))
    ;   assign_dfs([frame(Doms, [], 0)], Budget, 0, Raw),
        assign_finish(Raw, Vars, Result)
    ).

%% Report assignments in the order the caller listed the variables, not the
%% order the search happened to bind them.
assign_finish(solution(Raw, N), Vars, solution(Assignment, N)) :-
    assign_in_order(Vars, Raw, Assignment).
assign_finish(unsat(N), _, unsat(N)).
assign_finish(budget_exhausted(N), _, budget_exhausted(N)).

assign_in_order([], _, []).
assign_in_order([V|Vs], Raw, [V-X|Rest]) :-
    member(V-X, Raw), !,
    assign_in_order(Vs, Raw, Rest).

assign_dfs([], _, N, unsat(N)).
assign_dfs([frame(Doms, Assigned, Cost)|Stack], Budget, N, Result) :-
    (   Doms == []
    ->  Result = solution(Assigned, N)
    ;   N >= Budget
    ->  Result = budget_exhausted(N)
    ;   N1 is N + 1,
        assign_pick(Doms, Var-Dom, Rest),
        assign_children(Dom, Var, Rest, Assigned, Cost, Children),
        append(Children, Stack, Stack1),
        assign_dfs(Stack1, Budget, N1, Result)
    ).

%% ── Optimise: branch and bound ───────────────────────────────────────────────

assign_best(Vars, Budget, Result) :-
    assign_init(Vars, Doms),
    (   assign_empty_domain(Doms, V)
    ->  Result = unsat(empty_domain(V))
    ;   assign_bnb([frame(Doms, [], 0)], Budget, 0, none, Raw),
        assign_finish_best(Raw, Vars, Result)
    ).

assign_finish_best(best(Raw, C, N, Flag), Vars, best(Assignment, C, N, Flag)) :-
    assign_in_order(Vars, Raw, Assignment).
assign_finish_best(unsat(N), _, unsat(N)).
assign_finish_best(budget_exhausted(N), _, budget_exhausted(N)).

%% Agenda empty: search complete.
assign_bnb([], _, N, Best, Result) :-
    (   Best = best(A, C)
    ->  Result = best(A, C, N, complete)
    ;   Result = unsat(N)
    ).
assign_bnb([frame(Doms, Assigned, Cost)|Stack], Budget, N, Best, Result) :-
    (   N >= Budget
    ->  (   Best = best(A, C)
        ->  Result = best(A, C, N, budget_exhausted)
        ;   Result = budget_exhausted(N)
        )
    ;   N1 is N + 1,
        (   Best = best(_, BestCost), Cost >= BestCost
        ->  assign_bnb(Stack, Budget, N1, Best, Result)          %% bound
        ;   Doms == []
        ->  assign_bnb(Stack, Budget, N1, best(Assigned, Cost), Result)
        ;   assign_pick(Doms, Var-Dom, Rest),
            assign_children(Dom, Var, Rest, Assigned, Cost, Children),
            append(Children, Stack, Stack1),
            assign_bnb(Stack1, Budget, N1, Best, Result)
        )
    ).

%% ── Validate a given assignment ──────────────────────────────────────────────

assign_violations(Assignment, Violations) :-
    findall(rejected(V, X),
        ( member(V-X, Assignment), assign_reject(V, X) ),
        Rejected),
    findall(pair(V1, X1, V2, X2),
        ( assign_before(V1-X1, V2-X2, Assignment),
          ( assign_reject_pair(V1, X1, V2, X2) ; assign_reject_pair(V2, X2, V1, X1) ) ),
        Pairs),
    findall(distinct(G, V1, V2),
        ( assign_before(V1-X, V2-X, Assignment),
          relation(G, distinct, V1), relation(G, distinct, V2) ),
        Distinct),
    append(Rejected, Pairs, V0),
    append(V0, Distinct, Violations).

%% P1 occurs strictly before P2 in the list (each unordered pair once).
assign_before(P1, P2, [P1|Rest]) :- member(P2, Rest).
assign_before(P1, P2, [_|Rest]) :- assign_before(P1, P2, Rest).
