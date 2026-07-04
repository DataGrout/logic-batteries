%% Battery: explain v1.0.0
%% Requires: (nothing)
%% Exports: explain/2, why/2, expl_prove/2, expl_leaves/3, expl_base/1, expl_builtin/1
%%
%% Provenance / "why" battery: a meta-interpreter that produces proof
%% trees for any goal provable from the cell's stored rules and facts.
%% Pure ISO — runs on SWI and Scryer alike, including ISO-pinned cells.
%% The load-bearing platform fact: clause/2 works on Scryer cells against
%% stored rules AND facts (verified live on a pinned-Scryer namespace,
%% 2026-07-04).
%%
%% Two APIs:
%%   why/2      — DETERMINISTIC (once/1) flat list of the base/stored
%%                facts supporting the first proof. The everyday API.
%%   explain/2  — nondeterministic full proof tree; alternative proofs
%%                on backtracking. Trees are node(Kind, Subproofs) with
%%                Kind in rule(G)/conj/disj/ifthen/else, and
%%                leaf(G, base_fact|stored_fact|builtin|negation).
%%
%% Prefer why/2 in queries: meta-interpretation is expensive to
%% backtrack through, and asking for a second proof can send the engine
%% on a very long redo hunt (use limit:1 / once semantics by default).

%% Standalone (consult) use: manifest predicates accumulate across battery
%% files (DG cells strip directives at install).
:- dynamic(battery_module/3).
:- dynamic(battery_export/3).

battery_module('explain', '1.0.0', auto).

battery_export('explain', 'why/2',
    'why(Goal, Facts) — deterministic: Facts is the flat list of base/stored facts supporting the first proof of Goal. The everyday provenance API.').
battery_export('explain', 'explain/2',
    'explain(Goal, ProofTree) — nondeterministic full proof tree for Goal; alternative proofs on backtracking. Nodes: node(rule(G)|conj|disj|ifthen|else, Subs); leaves: leaf(G, base_fact|stored_fact|builtin|negation).').
battery_export('explain', 'expl_prove/2',
    'expl_prove(Goal, Proof) — the meta-interpreter behind explain/2; handles conjunction, disjunction, if-then-else, negation-as-failure, base facts, whitelisted builtins, and the stored-rule clause walk.').
battery_export('explain', 'expl_leaves/3',
    'expl_leaves(Proof, Acc, Facts) — difference-style fold collecting base_fact/stored_fact leaves from a proof tree.').
battery_export('explain', 'expl_base/1',
    'expl_base(G) — recognizer for cell base predicates (entity/attribute/relation/metric/tag) treated as provenance leaves.').
battery_export('explain', 'expl_builtin/1',
    'expl_builtin(G) — whitelist of builtins the meta-interpreter calls directly (arithmetic, comparison, unification, findall, member, ...).').

%% ── Everyday API ──────────────────────────────────────────────────────

why(Goal, Facts) :-
    once(( expl_prove(Goal, Proof),
           expl_leaves(Proof, [], Facts) )).

explain(Goal, Proof) :-
    expl_prove(Goal, Proof).

%% ── Meta-interpreter ──────────────────────────────────────────────────

expl_prove(true, leaf(true, builtin)) :- !.
expl_prove((A, B), node(conj, [PA, PB])) :- !,
    expl_prove(A, PA),
    expl_prove(B, PB).
expl_prove((Cond -> Then ; Else), P) :- !,
    (   expl_prove(Cond, PC)
    ->  expl_prove(Then, PT),
        P = node(ifthen, [PC, PT])
    ;   expl_prove(Else, PE),
        P = node(else, [PE])
    ).
expl_prove((A ; B), node(disj, [P0])) :- !,
    ( expl_prove(A, P0) ; expl_prove(B, P0) ).
expl_prove(\+ A, leaf(\+ A, negation)) :- !,
    \+ expl_prove(A, _).
expl_prove(G, leaf(G, base_fact)) :-
    expl_base(G), !,
    call(G).
expl_prove(G, leaf(G, builtin)) :-
    expl_builtin(G), !,
    call(G).
expl_prove(G, node(rule(G), [PB])) :-
    clause(G, B),
    (   B == true
    ->  PB = leaf(G, stored_fact)
    ;   expl_prove(B, PB)
    ).

%% ── Leaf collection ───────────────────────────────────────────────────

expl_leaves(leaf(G, base_fact), Acc, [G|Acc]) :- !.
expl_leaves(leaf(G, stored_fact), Acc, [G|Acc]) :- !.
expl_leaves(leaf(_, _), Acc, Acc) :- !.
expl_leaves(node(_, Ps), Acc, Out) :- !,
    expl_leaves(Ps, Acc, Out).
expl_leaves([], Acc, Acc) :- !.
expl_leaves([P|Ps], Acc, Out) :-
    expl_leaves(P, Acc, A1),
    expl_leaves(Ps, A1, Out).

%% ── Recognizers ───────────────────────────────────────────────────────

%% Cell base predicates: provable directly, recorded as provenance leaves.
expl_base(G) :-
    (   G = entity(_)
    ;   G = attribute(_, _, _)
    ;   G = relation(_, _, _)
    ;   G = metric(_, _, _)
    ;   G = tag(_, _)
    ).

%% Builtins the meta-interpreter calls without descending into.
expl_builtin(_ is _).
expl_builtin(_ < _).
expl_builtin(_ > _).
expl_builtin(_ =< _).
expl_builtin(_ >= _).
expl_builtin(_ =:= _).
expl_builtin(_ =\= _).
expl_builtin(_ = _).
expl_builtin(_ \= _).
expl_builtin(_ == _).
expl_builtin(_ \== _).
expl_builtin(findall(_, _, _)).
expl_builtin(member(_, _)).
expl_builtin(length(_, _)).
expl_builtin(atom_concat(_, _, _)).
expl_builtin(number(_)).
expl_builtin(atom(_)).
expl_builtin(nonvar(_)).
