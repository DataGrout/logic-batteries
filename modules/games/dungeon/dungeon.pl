%% Tether Module: dungeon v1.0.0
%% Exports: room_connected/2, room_accessible/2, dungeon_path/3,
%%          room_cleared/2, dungeon_complete/2

tether_module(dungeon, '1.0.0', auto).

tether_export(dungeon, 'room_connected/2',  'room_connected(Room1, Room2) — rooms share a passage (symmetric)').
tether_export(dungeon, 'room_accessible/2', 'room_accessible(Player, Room) — Player can enter Room (unlocked or has key)').
tether_export(dungeon, 'dungeon_path/3',    'dungeon_path(Player, From, Path) — Path is an accessible route from From through the dungeon').
tether_export(dungeon, 'room_cleared/2',    'room_cleared(Player, Room) — Player has visited and cleared Room').
tether_export(dungeon, 'dungeon_complete/2','dungeon_complete(Player, Dungeon) — Player has cleared all rooms in Dungeon').

%% ── Dungeon Data Model ────────────────────────────────────────────────────────
%%
%% Room connections (directed — assert both for bidirectional):
%%   relation(entrance, connects_to, corridor_a)
%%   relation(corridor_a, connects_to, boss_room)
%%
%% Locked rooms:
%%   attribute(boss_room, requires_key, iron_key)
%%
%% Dungeon membership:
%%   relation(catacombs, has_room, entrance)
%%   relation(catacombs, has_room, corridor_a)
%%   relation(catacombs, has_room, boss_room)
%%
%% Cleared state:
%%   relation(alice_catacombs, cleared, entrance)   %% keyed as player_dungeon

%% room_connected(+Room1, ?Room2)  (follows directed connections)
room_connected(Room1, Room2) :-
    relation(Room1, connects_to, Room2).

%% room_accessible(+Player, +Room)
room_accessible(_, Room) :-
    \+ attribute(Room, requires_key, _), !.
room_accessible(Player, Room) :-
    attribute(Room, requires_key, Key),
    relation(Player, has_item, Key).

%% dungeon_path(+Player, +From, -Path)
%% Path is the sequence of accessible rooms reachable from From (DFS).
dungeon_path(Player, From, Path) :-
    dungeon_path_(Player, From, [From], RevPath),
    reverse(RevPath, Path).

dungeon_path_(_, _, Visited, Visited).
dungeon_path_(Player, Current, Visited, Path) :-
    room_connected(Current, Next),
    \+ member(Next, Visited),
    room_accessible(Player, Next),
    dungeon_path_(Player, Next, [Next|Visited], Path).

%% room_cleared(+Player, +Room)
room_cleared(Player, Room) :-
    atom_concat(Player, '_dungeon', Key),
    relation(Key, cleared, Room).
room_cleared(Player, Room) :-
    relation(Player, cleared_room, Room).

%% dungeon_complete(+Player, +Dungeon)
dungeon_complete(Player, Dungeon) :-
    \+ ( relation(Dungeon, has_room, Room),
         \+ room_cleared(Player, Room) ).
