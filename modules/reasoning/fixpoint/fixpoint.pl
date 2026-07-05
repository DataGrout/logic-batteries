%% Battery: fixpoint v1.0.0
%% Requires: (nothing)
%% Exports: fixpoint_solve/1, fixpoint_solve/2, fixpoint_answers/2, fixpoint_answers/3
%%
%% Bottom-up (Datalog-style) evaluation of stored rules: tabling's TERMINATION
%% benefit without tabling. Pure ISO — runs on SWI and Scryer alike, including
%% ISO-pinned cells, where `:- table` is unavailable by design (directives are
%% stripped at cell install, and Scryer has no tabling).
%%
%% Instead of proving a recursive goal top-down (where left/cyclic recursion
%% loops forever under plain SLD), fixpoint_solve/1 saturates: it derives every
%% fact provable from the goal's rules — round by round, carrying the answer
%% set as a plain list — until nothing new appears, then answers from that set.
%% Recursive calls inside rule bodies are looked up in the CURRENT answer set,
%% never re-proven, so cycles cannot loop. The classic transitive closure
%%
%%     reach(X, Y) :- edge(X, Y).
%%     reach(X, Y) :- reach(X, Z), edge(Z, Y).
%%
%% works verbatim on cyclic graphs — no visited-set rewrite required.
%%
%% SCOPE (read once): sound and terminating for the DATALOG class — rules
%% whose head values come from a finite domain (the constants in your facts).
%% Rules that BUILD unboundedly new terms or numbers in heads (counters like
%% `level(X, N1) :- edge(X, Y), level(Y, N), N1 is N + 1` on a cyclic graph)
%% are outside that class and will not terminate here either. Negation (\+)
%% is supported over BASE goals only; \+ over a derived (recursive) predicate
%% throws a clear error rather than computing wrong answers. Answers are
%% recomputed per call (no cross-query caching).

%% Standalone (consult) use: manifest predicates accumulate across battery
%% files (DG cells strip directives at install).
:- dynamic(battery_module/3).
:- dynamic(battery_export/3).

battery_module('fixpoint', '1.0.0', auto).

battery_export('fixpoint', 'fixpoint_solve/1',
    'fixpoint_solve(Goal) — prove Goal by bottom-up saturation of its rules; terminates on cyclic/left-recursive Datalog rules where plain resolution loops. Nondeterministic over the saturated answers.').
battery_export('fixpoint', 'fixpoint_solve/2',
    'fixpoint_solve(Goal, Derived) — as fixpoint_solve/1 with an explicit list of derived predicates (e.g. [reach/2]) instead of automatic dependency detection.').
battery_export('fixpoint', 'fixpoint_answers/2',
    'fixpoint_answers(Pattern, Answers) — deterministic: Answers is the list of every saturated fact unifying with Pattern (each derived exactly once).').
battery_export('fixpoint', 'fixpoint_answers/3',
    'fixpoint_answers(Pattern, Derived, Answers) — as fixpoint_answers/2 with an explicit derived-predicate list.').

%% ── Public API ─────────────────────────────────────────────────────────────

fixpoint_solve(Goal) :-
    fixpoint_answers(Goal, Answers),
    member(Goal, Answers).

fixpoint_solve(Goal, Derived) :-
    fixpoint_answers(Goal, Derived, Answers),
    member(Goal, Answers).

fixpoint_answers(Goal, Answers) :-
    fp_cone(Goal, Derived),
    fixpoint_answers(Goal, Derived, Answers).

fixpoint_answers(Goal, Derived, Answers) :-
    fp_saturate(Derived, [], Set),
    findall(Goal, member(Goal, Set), Answers).

%% ── Saturation loop ────────────────────────────────────────────────────────
%%
%% Naive iteration: each round fires every rule of every derived predicate
%% against the current answer set; new (not-yet-seen) heads extend the set;
%% stop when a round adds nothing. Monotone over a finite domain → terminates.

fp_saturate(Derived, Acc, Set) :-
    fp_round(Derived, Acc, Heads0),
    sort(Heads0, Heads),
    fp_fresh(Heads, Acc, Fresh),
    (   Fresh == []
    ->  Set = Acc
    ;   append(Acc, Fresh, Acc1),
        fp_saturate(Derived, Acc1, Set)
    ).

%% Every head derivable in one pass over all rules of the derived predicates.
fp_round(Derived, Acc, Heads) :-
    findall(H,
            ( member(P/A, Derived),
              functor(H, P, A),
              fp_clause(H, B),
              fp_body(B, Derived, Acc)
            ),
            Heads).

%% Elements of (sorted, duplicate-free) Heads not already in Acc.
fp_fresh([], _, []).
fp_fresh([H|Hs], Acc, Fresh) :-
    (   fp_member_eq(H, Acc)
    ->  fp_fresh(Hs, Acc, Fresh)
    ;   Fresh = [H|Rest],
        fp_fresh(Hs, Acc, Rest)
    ).

fp_member_eq(X, [Y|_]) :- X == Y, !.
fp_member_eq(X, [_|T]) :- fp_member_eq(X, T).

%% ── Body evaluation against the answer set ─────────────────────────────────
%%
%% Derived subgoals are LOOKED UP in Acc (the termination trick — never
%% re-proven top-down); everything else is called directly.

fp_body(true, _, _) :- !.
fp_body((A, B), D, Acc) :- !,
    fp_body(A, D, Acc),
    fp_body(B, D, Acc).
fp_body((C -> T ; E), D, Acc) :- !,
    (   fp_body(C, D, Acc)
    ->  fp_body(T, D, Acc)
    ;   fp_body(E, D, Acc)
    ).
fp_body((A ; B), D, Acc) :- !,
    ( fp_body(A, D, Acc) ; fp_body(B, D, Acc) ).
fp_body(\+ G, D, Acc) :- !,
    fp_negation(G, D, Acc).
fp_body(G, D, Acc) :-
    fp_derived_goal(G, D), !,
    member(G, Acc).
fp_body(G, _, _) :-
    fp_call_base(G).

%% Negation over a derived predicate needs stratified evaluation, which v1
%% does not do — refuse loudly instead of silently computing wrong answers.
fp_negation(G, D, _Acc) :-
    fp_derived_goal(G, D), !,
    throw(error(representation_error(fixpoint_negation_over_derived_unsupported),
                fixpoint_solve/1)).
fp_negation(G, _, _) :-
    \+ fp_call_base(G).

fp_derived_goal(G, Derived) :-
    nonvar(G),
    functor(G, P, A),
    fp_pa_member(P/A, Derived).

fp_pa_member(PA, [PA|_]) :- !.
fp_pa_member(PA, [_|T]) :- fp_pa_member(PA, T).

%% Base call: an undefined predicate simply contributes nothing (fail);
%% every other error (type errors, arithmetic) propagates to the caller.
fp_call_base(G) :-
    catch(call(G), E, fp_base_error(E)).

fp_base_error(error(existence_error(procedure, _), _)) :- !, fail.
fp_base_error(E) :- throw(E).

%% clause/2 that never throws: static/builtin/undefined predicates → no rules.
fp_clause(H, B) :-
    catch(clause(H, B), _, fail).

%% ── Automatic dependency cone ──────────────────────────────────────────────
%%
%% A predicate is DERIVED when it has at least one clause with a non-true
%% body (a rule). Facts-only predicates are base — called directly, which is
%% both cheaper and equivalent. The cone is the goal's predicate plus,
%% transitively, every derived predicate its rule bodies call.

fp_cone(Goal, Derived) :-
    (   callable(Goal)
    ->  true
    ;   throw(error(type_error(callable, Goal), fixpoint_solve/1))
    ),
    functor(Goal, P, A),
    fp_cone_walk([P/A], [], Derived).

fp_cone_walk([], Acc, Acc).
fp_cone_walk([P/A | Rest], Acc, Derived) :-
    (   fp_pa_member(P/A, Acc)
    ->  fp_cone_walk(Rest, Acc, Derived)
    ;   fp_pred_bodies(P/A, Bodies),
        (   Bodies == []
        ->  fp_cone_walk(Rest, Acc, Derived)
        ;   fp_called_preds(Bodies, Called),
            append(Rest, Called, Rest1),
            fp_cone_walk(Rest1, [P/A | Acc], Derived)
        )
    ).

%% The non-true rule bodies of P/A ([] for facts-only, base, or builtin preds).
fp_pred_bodies(P/A, Bodies) :-
    functor(H, P, A),
    findall(B, ( fp_clause(H, B), B \== true ), Bodies).

%% Predicate indicators of every positive literal in a list of bodies.
fp_called_preds(Bodies, Called) :-
    fp_called_preds_(Bodies, [], Called).

fp_called_preds_([], Acc, Acc).
fp_called_preds_([B|Bs], Acc, Out) :-
    fp_body_preds(B, Acc, A1),
    fp_called_preds_(Bs, A1, Out).

fp_body_preds(V, Acc, Acc) :- var(V), !.
fp_body_preds(true, Acc, Acc) :- !.
fp_body_preds((A, B), Acc, Out) :- !,
    fp_body_preds(A, Acc, A1),
    fp_body_preds(B, A1, Out).
fp_body_preds((A ; B), Acc, Out) :- !,
    fp_body_preds(A, Acc, A1),
    fp_body_preds(B, A1, Out).
fp_body_preds((A -> B), Acc, Out) :- !,
    fp_body_preds(A, Acc, A1),
    fp_body_preds(B, A1, Out).
fp_body_preds(\+ G, Acc, Out) :- !,
    fp_body_preds(G, Acc, Out).
fp_body_preds(G, Acc, [P/A | Acc]) :-
    callable(G),
    functor(G, P, A),
    A >= 0, !.
fp_body_preds(_, Acc, Acc).