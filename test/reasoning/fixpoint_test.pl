:- use_module(library(plunit)).

:- consult('../../modules/reasoning/fixpoint/fixpoint').

%% Test predicates are fp_t_-prefixed to keep the shared user-module namespace
%% clean, and dynamic so clause/2 can walk them (mirrors LC cells, where
%% everything is asserted).
:- dynamic fp_t_edge/2.
:- dynamic fp_t_reach/2.
:- dynamic fp_t_parent/2.
:- dynamic fp_t_anc/2.
:- dynamic fp_t_age/2.
:- dynamic fp_t_adult_anc/2.
:- dynamic fp_t_path/2.
:- dynamic fp_t_ok/1.
:- dynamic fp_t_flag/1.
:- dynamic fp_t_clear/1.

%% Cyclic graph: a -> b -> a, b -> c — with the VERBATIM textbook closure
%% rules that loop forever under plain SLD resolution on cyclic data.
fp_setup_cycle :-
    assertz(fp_t_edge(a, b)),
    assertz(fp_t_edge(b, a)),
    assertz(fp_t_edge(b, c)),
    assertz((fp_t_reach(X, Y) :- fp_t_edge(X, Y))),
    assertz((fp_t_reach(X, Y) :- fp_t_reach(X, Z), fp_t_edge(Z, Y))).

%% LEFT-recursive ancestry — the worst case for SLD, trivial bottom-up.
fp_setup_left_recursive :-
    assertz(fp_t_parent(tom, bob)),
    assertz(fp_t_parent(bob, ann)),
    assertz(fp_t_parent(bob, sue)),
    assertz((fp_t_anc(X, Y) :- fp_t_anc(X, Z), fp_t_parent(Z, Y))),
    assertz((fp_t_anc(X, Y) :- fp_t_parent(X, Y))).

%% Derived pred mixing base-case FACTS with recursive rules.
fp_setup_seeded :-
    assertz(fp_t_path(start, start)),
    assertz(fp_t_edge(start, mid)),
    assertz(fp_t_edge(mid, goal)),
    assertz((fp_t_path(X, Y) :- fp_t_path(X, Z), fp_t_edge(Z, Y))).

%% Builtins and negation-over-base inside rule bodies.
fp_setup_filters :-
    fp_setup_left_recursive,
    assertz(fp_t_age(ann, 25)),
    assertz(fp_t_age(sue, 9)),
    assertz(fp_t_flag(sue)),
    assertz((fp_t_adult_anc(X, Y) :- fp_t_anc(X, Y), fp_t_age(Y, A), A >= 18)),
    assertz((fp_t_clear(Y) :- fp_t_anc(_, Y), \+ fp_t_flag(Y))).

%% NOTE: asserts live in setup predicates (defined in `user`), never in test
%% bodies — plunit compiles bodies into a per-unit module, so an in-body
%% assertz lands in the wrong module and clause/2 cannot see it.
fp_setup_derived_negation :-
    fp_setup_left_recursive,
    assertz((fp_t_ok(X) :- fp_t_parent(X, _), \+ fp_t_anc(X, ann))).

fp_setup_disjunction :-
    assertz(fp_t_edge(x, y)),
    assertz(fp_t_flag(z)),
    assertz((fp_t_ok(N) :- ( fp_t_edge(N, _) ; fp_t_flag(N) ))).

cleanup_fp :-
    retractall(fp_t_edge(_, _)),
    retractall(fp_t_reach(_, _)),
    retractall(fp_t_parent(_, _)),
    retractall(fp_t_anc(_, _)),
    retractall(fp_t_age(_, _)),
    retractall(fp_t_adult_anc(_, _)),
    retractall(fp_t_path(_, _)),
    retractall(fp_t_ok(_)),
    retractall(fp_t_flag(_)),
    retractall(fp_t_clear(_)).

%% ── termination where SLD loops ─────────────────────────────────────────────

:- begin_tests(fixpoint_termination).

test(cyclic_closure_terminates, [setup(fp_setup_cycle), cleanup(cleanup_fp)]) :-
    fixpoint_answers(fp_t_reach(a, _), Answers),
    msort(Answers, Sorted),
    assertion(Sorted == [fp_t_reach(a, a), fp_t_reach(a, b), fp_t_reach(a, c)]),
    % each answer derived exactly once — tabling-equivalent semantics
    assertion(length(Answers, 3)).

test(cycle_membership, [setup(fp_setup_cycle), cleanup(cleanup_fp), nondet]) :-
    assertion(fixpoint_solve(fp_t_reach(a, a))),
    assertion(fixpoint_solve(fp_t_reach(b, b))).

test(sink_reaches_nothing, [setup(fp_setup_cycle), cleanup(cleanup_fp), fail]) :-
    fixpoint_solve(fp_t_reach(c, _)).

test(left_recursion_terminates, [setup(fp_setup_left_recursive), cleanup(cleanup_fp)]) :-
    fixpoint_answers(fp_t_anc(tom, _), Answers),
    msort(Answers, Sorted),
    assertion(
      Sorted == [fp_t_anc(tom, ann), fp_t_anc(tom, bob), fp_t_anc(tom, sue)]
    ).

test(fact_seeded_recursion, [setup(fp_setup_seeded), cleanup(cleanup_fp)]) :-
    fixpoint_answers(fp_t_path(start, _), Answers),
    msort(Answers, Sorted),
    assertion(
      Sorted ==
        [fp_t_path(start, goal), fp_t_path(start, mid), fp_t_path(start, start)]
    ).

:- end_tests(fixpoint_termination).

%% ── body features ───────────────────────────────────────────────────────────

:- begin_tests(fixpoint_bodies).

test(builtins_in_bodies, [setup(fp_setup_filters), cleanup(cleanup_fp)]) :-
    fixpoint_answers(fp_t_adult_anc(tom, _), Answers),
    assertion(Answers == [fp_t_adult_anc(tom, ann)]).

test(negation_over_base_goals, [setup(fp_setup_filters), cleanup(cleanup_fp)]) :-
    fixpoint_answers(fp_t_clear(_), Answers),
    msort(Answers, Sorted),
    % sue is flagged; ann and bob are clear
    assertion(Sorted == [fp_t_clear(ann), fp_t_clear(bob)]).

test(negation_over_derived_refused,
     [setup(fp_setup_derived_negation), cleanup(cleanup_fp),
      throws(error(representation_error(fixpoint_negation_over_derived_unsupported), _))]) :-
    fixpoint_answers(fp_t_ok(_), _).

test(explicit_derived_list, [setup(fp_setup_cycle), cleanup(cleanup_fp)]) :-
    fixpoint_answers(fp_t_reach(a, _), [fp_t_reach/2], Answers),
    assertion(length(Answers, 3)).

test(disjunction_in_bodies, [setup(fp_setup_disjunction), cleanup(cleanup_fp)]) :-
    fixpoint_answers(fp_t_ok(_), Answers),
    msort(Answers, Sorted),
    assertion(Sorted == [fp_t_ok(x), fp_t_ok(z)]).

test(non_callable_goal_rejected,
     [throws(error(type_error(callable, _), _))]) :-
    fixpoint_solve(_).

:- end_tests(fixpoint_bodies).