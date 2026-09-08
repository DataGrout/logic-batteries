:- use_module(library(plunit)).

:- consult('../../modules/core/core/core').

:- begin_tests(core_aggregates).

test(max_min) :-
    core_max_list([3, 9, 2], Mx), assertion(Mx == 9),
    core_min_list([3, 9, 2], Mn), assertion(Mn == 2),
    core_max_list([7], One), assertion(One == 7).

test(max_min_fail_on_empty) :-
    assertion(\+ core_max_list([], _)),
    assertion(\+ core_min_list([], _)).

test(argmax_argmin_first_wins_ties) :-
    core_argmax([3-a, 9-b, 9-c, 2-d], Vx), assertion(Vx == b),
    core_argmin([3-a, 2-b, 2-c], Vn), assertion(Vn == b).

test(mean_median) :-
    core_mean([1, 2, 3, 4], M), assertion(M =:= 2.5),
    core_median([5, 1, 3], Md1), assertion(Md1 == 3),
    core_median([4, 1, 3, 2], Md2), assertion(Md2 =:= 2.5).

test(clamp) :-
    core_clamp(5, 0, 10, A), assertion(A == 5),
    core_clamp(-1, 0, 10, B), assertion(B == 0),
    core_clamp(11, 0, 10, C), assertion(C == 10).

:- end_tests(core_aggregates).

:- begin_tests(core_lists).

test(last_take_drop) :-
    core_last([a, b, c], L), assertion(L == c),
    core_take(2, [a, b, c], T), assertion(T == [a, b]),
    core_take(5, [a, b], T2), assertion(T2 == [a, b]),
    core_drop(2, [a, b, c], D), assertion(D == [c]),
    core_drop(5, [a, b], D2), assertion(D2 == []).

test(msort_keeps_duplicates_and_is_stable) :-
    core_msort([c, a, b, a], S), assertion(S == [a, a, b, c]),
    core_msort([2-x, 1-y, 2-w], S2), assertion(S2 == [1-y, 2-w, 2-x]),
    core_msort([], E), assertion(E == []).

test(keysort_is_stable_by_key_only) :-
    core_keysort([2-b, 1-z, 2-a, 1-y], S),
    assertion(S == [1-z, 1-y, 2-b, 2-a]).

test(group_pairs) :-
    core_group_pairs([1-a, 1-b, 2-c, 3-d, 3-e], G),
    assertion(G == [1-[a, b], 2-[c], 3-[d, e]]).

test(unique_preserves_first_order) :-
    core_unique([b, a, b, c, a], U), assertion(U == [b, a, c]).

test(between_numlist) :-
    findall(X, core_between(1, 3, X), Xs), assertion(Xs == [1, 2, 3]),
    assertion(\+ core_between(3, 1, _)),
    core_numlist(2, 5, N), assertion(N == [2, 3, 4, 5]),
    core_numlist(5, 2, N2), assertion(N2 == []).

test(subtract_flatten_zip) :-
    core_subtract([a, b, c, b], [b], R), assertion(R == [a, c]),
    core_flatten([a, [b, [c, []], d], [], e], F), assertion(F == [a, b, c, d, e]),
    core_zip([a, b], [1, 2], Z), assertion(Z == [a-1, b-2]).

test(keys_values) :-
    core_keys([a-1, b-2], K), assertion(K == [a, b]),
    core_values([a-1, b-2], V), assertion(V == [1, 2]).

:- end_tests(core_lists).

core_even(X) :- X mod 2 =:= 0.
core_add(X, A0, A) :- A is A0 + X.

:- begin_tests(core_higher_order).

test(include_exclude) :-
    core_include(core_even, [1, 2, 3, 4], I), assertion(I == [2, 4]),
    core_exclude(core_even, [1, 2, 3, 4], E), assertion(E == [1, 3]).

test(foldl) :-
    core_foldl(core_add, [1, 2, 3], 0, S), assertion(S == 6).

test(forall) :-
    assertion(core_forall(member(X, [2, 4]), core_even(X))),
    assertion(\+ core_forall(member(Y, [2, 3]), core_even(Y))).

:- end_tests(core_higher_order).
