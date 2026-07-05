%% Battery: fixpoint v1.0.1
%% Requires: (nothing)
%% Exports: fixpoint_solve/1, fixpoint_solve/2, fixpoint_answers/2, fixpoint_answers/3
%%
%% Bottom-up (Datalog-style) evaluation of stored rules: tabling's TERMINATION
%% benefit without tabling. Pure ISO — runs on SWI and Scryer alike, including
%% ISO-pinned cells, where `:- table` is unavailable by design: tabling is a
%% directive-enabled extension on both engines (SWI natively, Scryer via
%% library(tabling)), and directives are stripped at cell install.
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
%% are outside that class and will not terminate here either. Negation (\+),
%% forall/2, and aggregation (setof/bagof/findall) are supported over BASE
%% goals only; over a derived (recursive) predicate they throw a clear error
%% rather than computing wrong answers (mid-saturation the answer set is
%% still growing — aggregate AFTER saturation via fixpoint_answers/2
%% instead). call/N over a derived predicate is fine: it is unwrapped and
%% looked up in the answer set like a plain derived subgoal. Answers are
%% recomputed per call (no cross-query caching).

%% Standalone (consult) use: manifest predicates accumulate across battery
%% files (DG cells strip directives at install).
:- dynamic(battery_module/3).
:- dynamic(battery_export/3).

battery_module('fixpoint', '1.0.1', auto).

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
fp_body(forall(C, A), D, Acc) :- !,
    fp_body(\+ (C, \+ A), D, Acc).
fp_body(G, D, _Acc) :-
    fp_agg_inner(G, Inner), !,
    (   fp_mentions_derived(Inner, D)
    ->  throw(error(representation_error(fixpoint_aggregation_over_derived_unsupported),
                    fixpoint_solve/1))
    ;   fp_call_base(G)
    ).
fp_body(CallG, D, Acc) :-
    nonvar(CallG),
    functor(CallG, call, N), N >= 1, !,
    CallG =.. [call, G0 | Extra],
    (   var(G0)
    ->  fp_call_base(CallG)
    ;   G0 =.. [F | As0],
        append(As0, Extra, As),
        G1 =.. [F | As],
        fp_body(G1, D, Acc)
    ).
fp_body(G, D, Acc) :-
    fp_derived_goal(G, D), !,
    member(G, Acc).
fp_body(G, _, _) :-
    fp_call_base(G).

%% Negation over a derived predicate needs stratified evaluation, which v1
%% does not do — refuse loudly instead of silently computing wrong answers.
%% The check walks the WHOLE negated goal (conjunctions, disjunctions,
%% call/N, aggregation subgoals), not just its top functor: `\+ (reach(X,Y),
%% blocked(Y))` must be refused exactly like `\+ reach(X,Y)`.
fp_negation(G, D, _Acc) :-
    fp_mentions_derived(G, D), !,
    throw(error(representation_error(fixpoint_negation_over_derived_unsupported),
                fixpoint_solve/1)).
fp_negation(G, _, _) :-
    \+ fp_call_base(G).

%% Aggregation (setof/bagof/findall) over a derived predicate is refused in
%% v1: at body-evaluation time the answer set is still GROWING, so an
%% aggregate computed mid-saturation can silently under-count — a
%% wrong-answers failure mode, strictly worse than not terminating.
%% Aggregate AFTER saturation instead:
%%   fixpoint_answers(reach(a, X), As), length(As, N).
%% Aggregation over base goals is fine and calls through natively.
fp_agg_inner(setof(_, Q, _), G) :- !, fp_strip_qual(Q, G).
fp_agg_inner(bagof(_, Q, _), G) :- !, fp_strip_qual(Q, G).
fp_agg_inner(findall(_, Q, _), Q).

%% Strip ^/2 existential qualifiers: `V^Goal` → Goal.
fp_strip_qual(Q, G) :- nonvar(Q), Q = _^Q1, !, fp_strip_qual(Q1, G).
fp_strip_qual(G, G).

%% Does Goal mention any derived predicate anywhere in its structure —
%% through conjunction/disjunction/if-then-else, negation, existential
%% qualification, call/N, and aggregation subgoals? (A var mentions nothing;
%% it cannot be checked, and the actual call will error at runtime if it
%% resolves to something unsafe.)
fp_mentions_derived(V, _) :- var(V), !, fail.
fp_mentions_derived((A, B), D) :- !,
    ( fp_mentions_derived(A, D) -> true ; fp_mentions_derived(B, D) ).
fp_mentions_derived((A ; B), D) :- !,
    ( fp_mentions_derived(A, D) -> true ; fp_mentions_derived(B, D) ).
fp_mentions_derived((A -> B), D) :- !,
    ( fp_mentions_derived(A, D) -> true ; fp_mentions_derived(B, D) ).
fp_mentions_derived(\+ G, D) :- !, fp_mentions_derived(G, D).
fp_mentions_derived(_^G, D) :- !, fp_mentions_derived(G, D).
fp_mentions_derived(G, D) :-
    fp_agg_inner(G, Inner), !,
    fp_mentions_derived(Inner, D).
fp_mentions_derived(CallG, D) :-
    functor(CallG, call, N), N >= 1, !,
    CallG =.. [call, G0 | Extra],
    nonvar(G0),
    G0 =.. [F | As0],
    append(As0, Extra, As),
    G1 =.. [F | As],
    fp_mentions_derived(G1, D).
fp_mentions_derived(G, D) :-
    fp_derived_goal(G, D).

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
%%
%% Built-in predicates are NEVER saturation targets, even when the engine
%% exposes their clauses: SWI defines library builtins like length/2 in
%% Prolog and its clause/2 is permissive, so without this gate a rule body
%% calling length/2 would pull SWI's *implementation* of length into the
%% derived cone and try to saturate it (instantiation errors, or worse).
%% Strict ISO engines (Scryer) throw permission_error from clause/2 on
%% built-ins — fp_clause already catches that — so this situation cannot
%% arise there; the predicate_property/2 probe is a best-effort portability
%% shim, catch-wrapped so engines without it degrade to the strict-ISO
%% behavior rather than erroring.
fp_pred_bodies(P/A, Bodies) :-
    functor(H, P, A),
    (   fp_builtin_pred(H)
    ->  Bodies = []
    ;   findall(B, ( fp_clause(H, B), B \== true ), Bodies)
    ).

fp_builtin_pred(H) :-
    catch(predicate_property(H, built_in), _, fail).

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
%% Aggregation, qualification, forall, and call/N are transparent to the
%% cone walk — a derived predicate referenced ONLY inside a setof/3 must
%% still be detected as derived, or the aggregation guard in fp_body/3
%% never fires and the goal would be re-proven natively (loops on cycles).
fp_body_preds(_^G, Acc, Out) :- !,
    fp_body_preds(G, Acc, Out).
fp_body_preds(setof(_, Q, _), Acc, Out) :- !,
    fp_body_preds(Q, Acc, Out).
fp_body_preds(bagof(_, Q, _), Acc, Out) :- !,
    fp_body_preds(Q, Acc, Out).
fp_body_preds(findall(_, Q, _), Acc, Out) :- !,
    fp_body_preds(Q, Acc, Out).
fp_body_preds(forall(C, A), Acc, Out) :- !,
    fp_body_preds((C, A), Acc, Out).
fp_body_preds(CallG, Acc, Out) :-
    nonvar(CallG),
    functor(CallG, call, N), N >= 1, !,
    CallG =.. [call, G0 | Extra],
    (   var(G0)
    ->  Out = Acc
    ;   G0 =.. [F | As0],
        append(As0, Extra, As),
        G1 =.. [F | As],
        fp_body_preds(G1, Acc, Out)
    ).
fp_body_preds(G, Acc, [P/A | Acc]) :-
    callable(G),
    functor(G, P, A),
    A >= 0, !.
fp_body_preds(_, Acc, Acc).