%% Battery: puzzle-fsm v1.0.0
%% Exports: can_transition/3, puzzle_solved/1, valid_sequence/2,
%%          hint_for/2, blocked_by/2

battery_module('puzzle-fsm', '1.0.1', auto).

battery_export('puzzle-fsm', 'can_transition/3', 'can_transition(Puzzle, Move, NextState) — Move is valid from current state, leading to NextState').
battery_export('puzzle-fsm', 'puzzle_solved/1',  'puzzle_solved(Puzzle) — Puzzle is in a winning/solved state').
battery_export('puzzle-fsm', 'valid_sequence/2', 'valid_sequence(Puzzle, Moves) — Moves is a list of moves that leads from initial to a solved state').
battery_export('puzzle-fsm', 'hint_for/2',       'hint_for(Puzzle, Move) — Move is a valid next step toward solving Puzzle').
battery_export('puzzle-fsm', 'blocked_by/2',     'blocked_by(Puzzle, Reason) — Reason explains why Puzzle cannot be solved from current state').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). A puzzle names its
%% states; moves hang off states and lead to states. A winning state may be an
%% attribute (one) or a relation (any number), and both are read; with neither,
%% nothing is ever solved.

battery_input('puzzle-fsm', puzzle, attribute(initial_state), ref(state), key,
    'Where the puzzle starts and valid_sequence searches from; also the current state when current_state is absent.').
battery_input('puzzle-fsm', puzzle, attribute(current_state), ref(state), optional,
    'Where the puzzle is now; absent, it is at initial_state.').
battery_input('puzzle-fsm', puzzle, attribute(solve_state), ref(state), optional,
    'A winning state.').
battery_input('puzzle-fsm', puzzle, relation(solve_state), ref(state), optional,
    'A winning state; one fact per state.').
battery_input('puzzle-fsm', puzzle, relation(player_has), atom, optional,
    'An item available to this puzzle directly, satisfying a move''s requires_item.').
battery_input('puzzle-fsm', puzzle, attribute(player), ref(player), optional,
    'The player whose has_item facts satisfy a move''s requires_item.').
battery_input('puzzle-fsm', state, relation(move), ref(move), key,
    'A move available from this state; one fact per move.').
battery_input('puzzle-fsm', move, attribute(leads_to), ref(state), key,
    'The state the move goes to; a move without it is never taken.').
battery_input('puzzle-fsm', move, attribute(requires_item), atom, optional,
    'An item the move needs, through player_has or the named player''s has_item.').
battery_input('puzzle-fsm', player, relation(has_item), atom, key,
    'An item the player holds.').

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
      -> puzzle_item_available(Puzzle, Item)
      ;  true ).
%% An item gate is satisfied by either shape: the item asserted on the puzzle
%% (`player_has`), or — when the puzzle names its `player` — the player's
%% inventory (`has_item`, the relation the inventory battery maintains).
puzzle_item_available(Puzzle, Item) :-
    relation(Puzzle, player_has, Item), !.
puzzle_item_available(Puzzle, Item) :-
    attribute(Puzzle, player, Player),
    relation(Player, has_item, Item).

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
      -> puzzle_item_available(Puzzle, Item)
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
    \+ puzzle_item_available(Puzzle, Item), !.
blocked_by(Puzzle, no_moves) :-
    puzzle_current_state(Puzzle, State),
    \+ relation(State, move, _).
