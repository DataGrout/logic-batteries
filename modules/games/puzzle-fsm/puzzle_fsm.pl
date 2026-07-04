%% Battery: puzzle-fsm v1.0.0
%% Exports: can_transition/3, puzzle_solved/1, valid_sequence/2,
%%          hint_for/2, blocked_by/2

battery_module('puzzle-fsm', '1.0.0', auto).

battery_export('puzzle-fsm', 'can_transition/3', 'can_transition(Puzzle, Move, NextState) — Move is valid from current state, leading to NextState').
battery_export('puzzle-fsm', 'puzzle_solved/1',  'puzzle_solved(Puzzle) — Puzzle is in a winning/solved state').
battery_export('puzzle-fsm', 'valid_sequence/2', 'valid_sequence(Puzzle, Moves) — Moves is a list of moves that leads from initial to a solved state').
battery_export('puzzle-fsm', 'hint_for/2',       'hint_for(Puzzle, Move) — Move is a valid next step toward solving Puzzle').
battery_export('puzzle-fsm', 'blocked_by/2',     'blocked_by(Puzzle, Reason) — Reason explains why Puzzle cannot be solved from current state').

%% ── Puzzle Data Model ────────────────────────────────────────────────────────
%%
%% States and transitions:
%%   attribute(my_puzzle, initial_state, locked)
%%   attribute(my_puzzle, current_state, locked)
%%   attribute(my_puzzle, solve_state,   open)
%%
%%   relation(locked, move, use_key)          %% move from 'locked' via 'use_key'
%%   attribute(use_key, leads_to, open)       %% use_key leads to 'open'
%%   attribute(use_key, requires_item, key)   %% optional: player must hold item
%%
%% Multiple solve states:
%%   relation(my_puzzle, solve_state, state_a)
%%   relation(my_puzzle, solve_state, state_b)

puzzle_current_state(Puzzle, State) :-
    attribute(Puzzle, current_state, State), !.
puzzle_current_state(Puzzle, State) :-
    attribute(Puzzle, initial_state, State).

puzzle_is_solved_state(Puzzle, State) :-
    attribute(Puzzle, solve_state, State).
puzzle_is_solved_state(Puzzle, State) :-
    relation(Puzzle, solve_state, State).

%% can_transition(+Puzzle, ?Move, ?NextState)
%% Move is valid from Puzzle's current state; NextState is where it leads.
can_transition(Puzzle, Move, NextState) :-
    puzzle_current_state(Puzzle, CurrentState),
    relation(CurrentState, move, Move),
    attribute(Move, leads_to, NextState),
    ( attribute(Move, requires_item, Item)
      -> relation(Puzzle, player_has, Item)
      ;  true ),
    ( attribute(Move, requires_state, ReqState)
      -> puzzle_current_state(Puzzle, ReqState)
      ;  true ).

%% puzzle_solved(+Puzzle)
puzzle_solved(Puzzle) :-
    puzzle_current_state(Puzzle, State),
    puzzle_is_solved_state(Puzzle, State).

%% valid_sequence(+Puzzle, -Moves)
%% A list of moves from initial state to a solved state (DFS, acyclic).
valid_sequence(Puzzle, Moves) :-
    attribute(Puzzle, initial_state, Init),
    findall(S, puzzle_is_solved_state(Puzzle, S), SolveStates),
    SolveStates \= [],
    solve_path(Puzzle, Init, SolveStates, [Init], [], Moves).

solve_path(_, State, SolveStates, _, RevMoves, Moves) :-
    member(State, SolveStates), !,
    reverse(RevMoves, Moves).
solve_path(Puzzle, State, SolveStates, Visited, RevMoves, Moves) :-
    relation(State, move, Move),
    attribute(Move, leads_to, Next),
    \+ member(Next, Visited),
    ( attribute(Move, requires_item, Item)
      -> relation(Puzzle, player_has, Item)
      ;  true ),
    solve_path(Puzzle, Next, SolveStates, [Next|Visited], [Move|RevMoves], Moves).

%% hint_for(+Puzzle, ?Move)
%% Move is a valid move from the current state that makes progress toward solving.
%% Returns first available valid move (there may be many — use findall for all).
hint_for(Puzzle, Move) :-
    can_transition(Puzzle, Move, _), !.

%% blocked_by(+Puzzle, ?Reason)
%% Reasons: already_solved, no_moves, missing_item(Item).
blocked_by(Puzzle, already_solved) :-
    puzzle_solved(Puzzle), !.
blocked_by(Puzzle, missing_item(Item)) :-
    puzzle_current_state(Puzzle, State),
    relation(State, move, Move),
    attribute(Move, requires_item, Item),
    \+ relation(Puzzle, player_has, Item), !.
blocked_by(Puzzle, no_moves) :-
    puzzle_current_state(Puzzle, State),
    \+ relation(State, move, _).
