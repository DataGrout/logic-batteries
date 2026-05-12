%% Shared test helpers — loaded before all test files by run_all.pl.
%% Provides clear_facts/0 once so per-file definitions don't clobber each other.

%% Needed for probabilistic battery files that use ProbLog annotated disjunction syntax.
:- op(1100, xfx, ::).

%% All module files define tether_module/3 and tether_export/3 facts, and
%% probabilistic modules define (::)/2 clauses (ProbLog annotation syntax).
%% Declaring them multifile here (loaded first) lets each module add its own
%% clauses without "redefined static procedure" warnings.
:- multifile tether_module/3.
:- multifile tether_export/3.
:- multifile (::)/2.
:- multifile setup_standard_customer/0.

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
