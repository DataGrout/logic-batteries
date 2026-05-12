%% Standalone test stub — provides the three predicates fsm.pl depends on.
%% In the DataGrout runtime this module is loaded from logic_cell.pl.
%% This copy lives alongside fsm.pl so the module can be tested independently.

:- module(logic_cell, [relation/3, attribute/3, lc_flex_match/2]).

:- dynamic relation/3.
:- dynamic attribute/3.

%% atom/string interop — LC stores values as strings, rules use atoms.
lc_flex_match(X, X) :- !.
lc_flex_match(X, Y) :- atom(X),   string(Y), atom_string(X, Y), !.
lc_flex_match(X, Y) :- string(X), atom(Y),   atom_string(Y, X), !.
lc_flex_match(X, Y) :- number(X), atom(Y),   atom_number(Y, X), !.
lc_flex_match(X, Y) :- number(X), string(Y), number_string(X, Y), !.
lc_flex_match(X, Y) :- atom(X),   number(Y), atom_number(X, Y), !.
lc_flex_match(X, Y) :- string(X), number(Y), number_string(Y, X), !.
