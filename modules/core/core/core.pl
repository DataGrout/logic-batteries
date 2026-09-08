%% Battery: core v1.0.0
%% Requires: (nothing)
%% Exports: core_max_list/2, core_min_list/2, core_argmax/2, core_argmin/2, core_mean/2,
%%          core_median/2, core_clamp/4, core_last/2, core_take/3, core_drop/3,
%%          core_msort/2, core_keysort/2, core_group_pairs/2, core_unique/2,
%%          core_between/3, core_numlist/3, core_subtract/3, core_flatten/2,
%%          core_zip/3, core_keys/2, core_values/2,
%%          core_include/3, core_exclude/3, core_foldl/4, core_forall/2

battery_module(core, '1.0.0', auto).

battery_export(core, 'core_max_list/2',      'core_max_list(Numbers, Max) — largest element of a non-empty list').
battery_export(core, 'core_min_list/2',      'core_min_list(Numbers, Min) — smallest element of a non-empty list').
battery_export(core, 'core_argmax/2',   'core_argmax(KeyValuePairs, Value) — the Value whose Key is largest; first wins on ties').
battery_export(core, 'core_argmin/2',   'core_argmin(KeyValuePairs, Value) — the Value whose Key is smallest; first wins on ties').
battery_export(core, 'core_mean/2',     'core_mean(Numbers, Mean) — arithmetic mean of a non-empty list (float)').
battery_export(core, 'core_median/2',   'core_median(Numbers, Median) — median of a non-empty list; the mean of the two middle values when the length is even').
battery_export(core, 'core_clamp/4',    'core_clamp(X, Lo, Hi, Y) — Y is X held within [Lo, Hi]').
battery_export(core, 'core_last/2',     'core_last(List, Last) — last element of a non-empty list').
battery_export(core, 'core_take/3',     'core_take(N, List, Prefix) — the first N elements, or the whole list if shorter').
battery_export(core, 'core_drop/3',     'core_drop(N, List, Rest) — the list without its first N elements, or [] if shorter').
battery_export(core, 'core_msort/2',    'core_msort(List, Sorted) — stable sort by standard order that keeps duplicates (the portable msort/2)').
battery_export(core, 'core_keysort/2',  'core_keysort(Pairs, Sorted) — stable sort of Key-Value pairs by Key, duplicates kept (the portable keysort/2)').
battery_export(core, 'core_group_pairs/2', 'core_group_pairs(SortedPairs, Groups) — runs of equal keys in a key-sorted pair list become Key-Values').
battery_export(core, 'core_unique/2',   'core_unique(List, Unique) — remove duplicates keeping first occurrences and original order').
battery_export(core, 'core_between/3',  'core_between(Lo, Hi, X) — X is each integer from Lo to Hi inclusive (the portable between/3)').
battery_export(core, 'core_numlist/3',  'core_numlist(Lo, Hi, List) — the integers from Lo to Hi inclusive as a list').
battery_export(core, 'core_subtract/3', 'core_subtract(List, Remove, Rest) — List without any element that appears in Remove').
battery_export(core, 'core_flatten/2',  'core_flatten(Nested, Flat) — nested lists flattened one level at a time until no list elements remain').
battery_export(core, 'core_zip/3',      'core_zip(Xs, Ys, Pairs) — pairwise X-Y pairs of two equal-length lists').
battery_export(core, 'core_keys/2',     'core_keys(Pairs, Keys) — the keys of a Key-Value pair list').
battery_export(core, 'core_values/2',   'core_values(Pairs, Values) — the values of a Key-Value pair list').
battery_export(core, 'core_include/3',  'core_include(Goal, List, Kept) — elements for which call(Goal, X) succeeds. Higher-order: meta-calls its goal argument.').
battery_export(core, 'core_exclude/3',  'core_exclude(Goal, List, Kept) — elements for which call(Goal, X) fails. Higher-order: meta-calls its goal argument.').
battery_export(core, 'core_foldl/4',    'core_foldl(Goal, List, Acc0, Acc) — left fold calling Goal(X, AccIn, AccOut). Higher-order: meta-calls its goal argument.').
battery_export(core, 'core_forall/2',   'core_forall(Cond, Action) — for every solution of Cond, Action succeeds. Higher-order: meta-calls its goal argument.').

%% ── Why this battery exists ─────────────────────────────────────────────────
%%
%% Batteries run on two engines, and a battery may only call what is available
%% without a use_module line of its own, because directives do not survive
%% installation. SWI-Prolog's library(lists) and library(apply) supply msort/2,
%% max_list/2, min_list/2, last/2, include/3, exclude/3, forall/2, subtract/3,
%% predsort/3 and sort/4, none of which Scryer has. Scryer does have between/3,
%% numlist/3 and the pairs predicates, but in library(between) and
%% library(pairs), which a battery cannot import for itself. Every battery that
%% needed one of these has been carrying a private copy under its own prefix.
%%
%% This file is the one copy. Everything is pure ISO Prolog over the portable
%% subset (sort/2, keysort/2, length/2, member/2, append/3, reverse/2,
%% arithmetic), and every predicate is prefixed core_ so nothing here shadows
%% an engine library or an engine-specific compatibility shim. The four
%% higher-order predicates at the bottom use call/N; a host that vets goals
%% before running them may decline a call it cannot inspect ahead of time, so
%% prefer a first-order formulation where a battery must run anywhere.

%% ── Aggregates ──────────────────────────────────────────────────────────────

core_max_list([X|Xs], Max) :- core_maxl_acc(Xs, X, Max).
core_maxl_acc([], M, M).
core_maxl_acc([X|Xs], Acc, M) :- ( X > Acc -> Acc1 = X ; Acc1 = Acc ), core_maxl_acc(Xs, Acc1, M).

core_min_list([X|Xs], Min) :- core_minl_acc(Xs, X, Min).
core_minl_acc([], M, M).
core_minl_acc([X|Xs], Acc, M) :- ( X < Acc -> Acc1 = X ; Acc1 = Acc ), core_minl_acc(Xs, Acc1, M).

core_argmax([K-V|Ps], Best) :- core_argmax_acc(Ps, K, V, Best).
core_argmax_acc([], _, V, V).
core_argmax_acc([K-V|Ps], BK, BV, Best) :-
    ( K > BK -> core_argmax_acc(Ps, K, V, Best) ; core_argmax_acc(Ps, BK, BV, Best) ).

core_argmin([K-V|Ps], Best) :- core_argmin_acc(Ps, K, V, Best).
core_argmin_acc([], _, V, V).
core_argmin_acc([K-V|Ps], BK, BV, Best) :-
    ( K < BK -> core_argmin_acc(Ps, K, V, Best) ; core_argmin_acc(Ps, BK, BV, Best) ).

core_mean(Xs, Mean) :-
    Xs = [_|_],
    core_sum(Xs, S),
    length(Xs, N),
    Mean is S / N.

core_sum([], 0).
core_sum([X|Xs], S) :- core_sum(Xs, S0), S is S0 + X.

core_median(Xs, Median) :-
    Xs = [_|_],
    core_msort(Xs, Sorted),
    length(Sorted, N),
    Mid is N // 2,
    (   N mod 2 =:= 1
    ->  core_nth0(Mid, Sorted, Median)
    ;   Lo is Mid - 1,
        core_nth0(Lo, Sorted, A),
        core_nth0(Mid, Sorted, B),
        Median is (A + B) / 2
    ).

core_nth0(0, [X|_], X) :- !.
core_nth0(N, [_|Xs], X) :- N > 0, N1 is N - 1, core_nth0(N1, Xs, X).

core_clamp(X, Lo, Hi, Y) :-
    (   X < Lo -> Y = Lo
    ;   X > Hi -> Y = Hi
    ;   Y = X
    ).

%% ── Lists ───────────────────────────────────────────────────────────────────

core_last([X], X) :- !.
core_last([_|Xs], X) :- core_last(Xs, X).

core_take(0, _, []) :- !.
core_take(_, [], []) :- !.
core_take(N, [X|Xs], [X|Ys]) :- N1 is N - 1, core_take(N1, Xs, Ys).

core_drop(0, Xs, Xs) :- !.
core_drop(_, [], []) :- !.
core_drop(N, [_|Xs], Ys) :- N1 is N - 1, core_drop(N1, Xs, Ys).

%% Stable merge sort on standard order; equal elements keep their order and
%% none are removed. sort/2 would drop duplicates, which is wrong for data.
core_msort([], []) :- !.
core_msort([X], [X]) :- !.
core_msort(Xs, Sorted) :-
    core_halve(Xs, L, R),
    core_msort(L, SL),
    core_msort(R, SR),
    core_merge(SL, SR, Sorted).

core_halve(Xs, L, R) :-
    length(Xs, N),
    H is N // 2,
    core_take(H, Xs, L),
    core_drop(H, Xs, R).

core_merge([], Ys, Ys) :- !.
core_merge(Xs, [], Xs) :- !.
core_merge([X|Xs], [Y|Ys], [Z|Zs]) :-
    (   Y @< X
    ->  Z = Y, core_merge([X|Xs], Ys, Zs)
    ;   Z = X, core_merge(Xs, [Y|Ys], Zs)
    ).

%% Stable merge sort of Key-Value pairs by Key only.
core_keysort([], []) :- !.
core_keysort([P], [P]) :- !.
core_keysort(Ps, Sorted) :-
    core_halve(Ps, L, R),
    core_keysort(L, SL),
    core_keysort(R, SR),
    core_kmerge(SL, SR, Sorted).

core_kmerge([], Ys, Ys) :- !.
core_kmerge(Xs, [], Xs) :- !.
core_kmerge([KX-VX|Xs], [KY-VY|Ys], [Z|Zs]) :-
    (   KY @< KX
    ->  Z = KY-VY, core_kmerge([KX-VX|Xs], Ys, Zs)
    ;   Z = KX-VX, core_kmerge(Xs, [KY-VY|Ys], Zs)
    ).

core_group_pairs([], []).
core_group_pairs([K-V|Ps], [K-[V|Vs]|Gs]) :-
    core_same_key(K, Ps, Vs, Rest),
    core_group_pairs(Rest, Gs).

core_same_key(K, [K1-V|Ps], [V|Vs], Rest) :- K1 == K, !, core_same_key(K, Ps, Vs, Rest).
core_same_key(_, Ps, [], Ps).

core_unique(Xs, Us) :- core_unique_acc(Xs, [], Us).
core_unique_acc([], _, []).
core_unique_acc([X|Xs], Seen, Us) :-
    (   core_memberchk_eq(X, Seen)
    ->  Us = Rest
    ;   Us = [X|Rest]
    ),
    core_unique_acc(Xs, [X|Seen], Rest).

core_memberchk_eq(X, [Y|Ys]) :- ( X == Y -> true ; core_memberchk_eq(X, Ys) ).

core_between(Lo, Hi, X) :- Lo =< Hi, X = Lo.
core_between(Lo, Hi, X) :- Lo < Hi, Lo1 is Lo + 1, core_between(Lo1, Hi, X).

core_numlist(Lo, Hi, []) :- Lo > Hi, !.
core_numlist(Lo, Hi, [Lo|Xs]) :- Lo1 is Lo + 1, core_numlist(Lo1, Hi, Xs).

core_subtract([], _, []).
core_subtract([X|Xs], Rm, Ys) :-
    (   core_memberchk_eq(X, Rm)
    ->  Ys = Rest
    ;   Ys = [X|Rest]
    ),
    core_subtract(Xs, Rm, Rest).

core_flatten(Xs, Flat) :- core_flatten_acc(Xs, [], Flat0), reverse(Flat0, Flat).
core_flatten_acc([], Acc, Acc).
core_flatten_acc([X|Xs], Acc, Flat) :-
    (   X = [_|_]
    ->  core_flatten_acc(X, Acc, Acc1)
    ;   X == []
    ->  Acc1 = Acc
    ;   Acc1 = [X|Acc]
    ),
    core_flatten_acc(Xs, Acc1, Flat).

core_zip([], [], []).
core_zip([X|Xs], [Y|Ys], [X-Y|Ps]) :- core_zip(Xs, Ys, Ps).

core_keys([], []).
core_keys([K-_|Ps], [K|Ks]) :- core_keys(Ps, Ks).

core_values([], []).
core_values([_-V|Ps], [V|Vs]) :- core_values(Ps, Vs).

%% ── Higher-order ────────────────────────────────────────────────────────────
%% These meta-call their Goal argument, so a host that vets goals before
%% running them has to know about them to vet the goal argument too. Prefer a
%% first-order formulation where a battery must run anywhere.

%% The list is the first argument of each worker so first-argument indexing
%% makes the recursion deterministic on both engines.
core_include(G, List, Out) :- core_include_(List, G, Out).
core_include_([], _, []).
core_include_([X|Xs], G, Out) :-
    (   call(G, X) -> Out = [X|Rest] ; Out = Rest ),
    core_include_(Xs, G, Rest).

core_exclude(G, List, Out) :- core_exclude_(List, G, Out).
core_exclude_([], _, []).
core_exclude_([X|Xs], G, Out) :-
    (   call(G, X) -> Out = Rest ; Out = [X|Rest] ),
    core_exclude_(Xs, G, Rest).

core_foldl(G, List, Acc0, Acc) :- core_foldl_(List, G, Acc0, Acc).
core_foldl_([], _, Acc, Acc).
core_foldl_([X|Xs], G, Acc0, Acc) :-
    call(G, X, Acc0, Acc1),
    core_foldl_(Xs, G, Acc1, Acc).

core_forall(Cond, Action) :- \+ ( call(Cond), \+ call(Action) ).
