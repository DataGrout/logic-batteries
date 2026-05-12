%% Shared test helpers — loaded before all test files by run_all.pl.
%% Provides clear_facts/0 once so per-file definitions don't clobber each other.

%% Needed for probabilistic battery files that use ProbLog annotated disjunction syntax.
:- op(1100, xfx, ::).

:- dynamic relation/3.
:- dynamic attribute/3.

clear_facts :-
    retractall(relation(_, _, _)),
    retractall(attribute(_, _, _)),
    ( current_module(logic_cell)
      -> ( retractall(logic_cell:relation(_, _, _)),
           retractall(logic_cell:attribute(_, _, _)) )
      ;  true ),
    abolish_all_tables.
