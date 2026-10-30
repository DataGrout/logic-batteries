%% Battery: hierarchy v1.0.0
%% Requires: (nothing)
%% Exports: hier_parent/2, hier_children/2, hier_rolls_up/2, hier_descendants/2,
%%          hier_own/2, hier_own/3, hier_subtotal/2, hier_subtotal/3,
%%          hier_subtotals/1, hier_subtotals/2, hier_depth/2, hier_path/3,
%%          hier_roots/1, hier_leaves/1, hier_nodes/1, hier_cycle/1,
%%          hier_multi_parent/1, hier_problems/1

battery_module(hierarchy, '1.0.0', explicit).

battery_export(hierarchy, 'hier_parent/2',      'hier_parent(Child, Parent) — a direct child_of edge').
battery_export(hierarchy, 'hier_children/2',    'hier_children(Parent, Children) — sorted direct children, [] for a leaf').
battery_export(hierarchy, 'hier_rolls_up/2',    'hier_rolls_up(Node, Ancestor) — Ancestor is above Node at any depth (transitive child_of); cycle-safe').
battery_export(hierarchy, 'hier_descendants/2', 'hier_descendants(Node, Descendants) — sorted set of every node below Node at any depth').
battery_export(hierarchy, 'hier_own/2',         'hier_own(Node, Value) — Node''s own amount: the sum of its metric(Node, amount, V) facts, 0 if none').
battery_export(hierarchy, 'hier_own/3',         'hier_own(Node, Metric, Value) — hier_own/2 for any metric name').
battery_export(hierarchy, 'hier_subtotal/2',    'hier_subtotal(Node, Total) — Node''s own amount plus every descendant''s own amount').
battery_export(hierarchy, 'hier_subtotal/3',    'hier_subtotal(Node, Metric, Total) — hier_subtotal/2 for any metric name').
battery_export(hierarchy, 'hier_subtotals/1',   'hier_subtotals(Pairs) — Node-Total for every node in the hierarchy, by node').
battery_export(hierarchy, 'hier_subtotals/2',   'hier_subtotals(Metric, Pairs) — hier_subtotals/1 for any metric name').
battery_export(hierarchy, 'hier_depth/2',       'hier_depth(Node, Depth) — how many ancestors Node has (0 for a root)').
battery_export(hierarchy, 'hier_path/3',        'hier_path(Node, Ancestor, Path) — the chain of child_of edges from Node up to Ancestor, both included').
battery_export(hierarchy, 'hier_roots/1',       'hier_roots(Roots) — sorted nodes that have children but no parent').
battery_export(hierarchy, 'hier_leaves/1',      'hier_leaves(Leaves) — sorted nodes that have a parent but no children').
battery_export(hierarchy, 'hier_nodes/1',       'hier_nodes(Nodes) — every node named in a child_of edge, sorted').
battery_export(hierarchy, 'hier_cycle/1',       'hier_cycle(Node) — Node rolls up into itself: the hierarchy has a loop through it').
battery_export(hierarchy, 'hier_multi_parent/1','hier_multi_parent(Node) — Node has more than one parent, so its amount counts under each').
battery_export(hierarchy, 'hier_problems/1',    'hier_problems(Problems) — cycle(Node), multi_parent(Node) and non_numeric(Node, Value) findings, [] for a clean tree').

%% ============================================================================
%% Hierarchy — roll a tree of accounts, cost centres, parts or org units up
%% to totals.
%%
%% Facts (assert with logic.assert):
%%   relation(Child, child_of, Parent)   one edge per child
%%   metric(Node, amount, Value)         a node's own amount (any metric name
%%                                       works with the /3 forms)
%%
%%   ?- hier_subtotal('Job Expenses', T).          % own + everything below
%%   ?- hier_subtotals(Pairs).                     % every node's total
%%   ?- why(hier_subtotal('Utilities', T), F).     % the facts behind a total
%%   ?- hier_problems(P).                          % loops, double parents
%%
%% Why a battery and not a recursive rule: a subtotal is the sum over the
%% transitive closure of child_of, and the obvious recursive rolls_up/2 is only
%% safe on a loop in the data when it is tabled. The closure here is a
%% bottom-up fixpoint specialised to one edge relation (the general form is
%% the fixpoint battery), so it needs neither tabling nor another battery and
%% also runs in ISO-pinned cells: every query terminates, a loop is reported
%% by hier_cycle/1 instead of hanging, and each descendant is counted once
%% even when two paths reach it, which is what makes the sums right.
%%
%% Pure ISO over the portable subset (findall/3, sort/2, member/2, append/3,
%% length/2, arithmetic); runs on both engines.
%% ============================================================================

hier_parent(Child, Parent) :-
    relation(Child, child_of, Parent).

hier_children(Parent, Children) :-
    findall(C, relation(C, child_of, Parent), Cs0),
    sort(Cs0, Children).

hier_nodes(Nodes) :-
    findall(N, ( relation(C, child_of, P), ( N = C ; N = P ) ), Ns0),
    sort(Ns0, Nodes).

%% Upward closure: every ancestor, once.
hier_rolls_up(Node, Ancestor) :-
    hier_up_closure(Node, Ancestors),
    member(Ancestor, Ancestors).

hier_up_closure(Node, Ancestors) :-
    findall(P, relation(Node, child_of, P), Ps0),
    sort(Ps0, Frontier),
    hier_up_fix(Frontier, Frontier, Ancestors).

hier_up_fix(Frontier, Acc, Set) :-
    findall(P,
            ( member(N, Frontier), relation(N, child_of, P), \+ member(P, Acc) ),
            New0),
    sort(New0, New),
    (   New == []
    ->  sort(Acc, Set)
    ;   append(Acc, New, Acc1),
        hier_up_fix(New, Acc1, Set)
    ).

%% Downward closure: every descendant, once, without Node itself even when
%% Node sits on a loop.
hier_descendants(Node, Descendants) :-
    hier_children(Node, Frontier),
    hier_down_fix(Frontier, Frontier, All),
    hier_remove(Node, All, Descendants).

hier_down_fix(Frontier, Acc, Set) :-
    findall(C,
            ( member(N, Frontier), relation(C, child_of, N), \+ member(C, Acc) ),
            New0),
    sort(New0, New),
    (   New == []
    ->  sort(Acc, Set)
    ;   append(Acc, New, Acc1),
        hier_down_fix(New, Acc1, Set)
    ).

hier_remove(_, [], []).
hier_remove(X, [X|T], R) :- !, hier_remove(X, T, R).
hier_remove(X, [H|T], [H|R]) :- hier_remove(X, T, R).

hier_own(Node, Value) :- hier_own(Node, amount, Value).

hier_own(Node, Metric, Value) :-
    findall(V, ( metric(Node, Metric, V), number(V) ), Vs),
    hier_sum(Vs, Value).

hier_subtotal(Node, Total) :- hier_subtotal(Node, amount, Total).

hier_subtotal(Node, Metric, Total) :-
    hier_known(Node, Metric),
    hier_descendants(Node, Ds),
    hier_own(Node, Metric, Own),
    findall(V, ( member(D, Ds), hier_own(D, Metric, V) ), Vs),
    hier_sum([Own|Vs], Total).

%% A node is known if it is in the tree or has an amount of its own.
hier_known(Node, _) :- relation(Node, child_of, _), !.
hier_known(Node, _) :- relation(_, child_of, Node), !.
hier_known(Node, Metric) :- metric(Node, Metric, _), !.

hier_subtotals(Pairs) :- hier_subtotals(amount, Pairs).

hier_subtotals(Metric, Pairs) :-
    hier_nodes(Nodes),
    findall(N-T, ( member(N, Nodes), hier_subtotal(N, Metric, T) ), Pairs).

hier_depth(Node, Depth) :-
    hier_known(Node, amount),
    hier_up_closure(Node, Ancestors),
    hier_remove(Node, Ancestors, As),
    length(As, Depth).

%% hier_path(+Node, ?Ancestor, -Path): walks parent edges upward without
%% revisiting a node, so a loop cannot make it run forever.
hier_path(Node, Ancestor, Path) :-
    hier_path_walk(Node, Ancestor, [Node], Rev),
    hier_reverse(Rev, Path).

hier_path_walk(Node, Node, Seen, Seen) :- Seen = [_, _|_].
hier_path_walk(Node, Ancestor, Seen, Path) :-
    relation(Node, child_of, P),
    \+ member(P, Seen),
    hier_path_walk(P, Ancestor, [P|Seen], Path).

hier_reverse(L, R) :- hier_rev(L, [], R).
hier_rev([], A, A).
hier_rev([H|T], A, R) :- hier_rev(T, [H|A], R).

hier_roots(Roots) :-
    findall(P, ( relation(_, child_of, P), \+ relation(P, child_of, _) ), Rs0),
    sort(Rs0, Roots).

hier_leaves(Leaves) :-
    findall(C, ( relation(C, child_of, _), \+ relation(_, child_of, C) ), Ls0),
    sort(Ls0, Leaves).

hier_cycle(Node) :-
    hier_nodes(Nodes),
    member(Node, Nodes),
    hier_up_closure(Node, Ancestors),
    member(Node, Ancestors).

hier_multi_parent(Node) :-
    hier_nodes(Nodes),
    member(Node, Nodes),
    findall(P, relation(Node, child_of, P), Ps0),
    sort(Ps0, [_, _|_]).

hier_problems(Problems) :-
    findall(cycle(N), hier_cycle(N), Cs),
    findall(multi_parent(N), hier_multi_parent(N), Ms),
    findall(non_numeric(N, V),
            ( metric(N, amount, V), \+ number(V) ),
            Bs),
    append(Cs, Ms, CM),
    append(CM, Bs, Problems).

hier_sum(Vs, S) :- hier_sum(Vs, 0, S).
hier_sum([], S, S).
hier_sum([V|Vs], A, S) :- A1 is A + V, hier_sum(Vs, A1, S).
