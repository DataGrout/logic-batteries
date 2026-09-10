%% Battery: dungeon v1.0.0
%% Exports: room_connected/2, room_accessible/2, dungeon_path/3,
%%          room_cleared/2, dungeon_complete/2

battery_module(dungeon, '1.0.1', auto).

battery_export(dungeon, 'room_connected/2',  'room_connected(Room1, Room2) — a directed passage from Room1 to Room2').
battery_export(dungeon, 'room_cleared/3',    'room_cleared(Player, Dungeon, Room) — cleared via the per-dungeon key <player>_<dungeon>, or either per-player shape').
battery_export(dungeon, 'room_accessible/2', 'room_accessible(Player, Room) — Player can enter Room (unlocked or has key)').
battery_export(dungeon, 'dungeon_path/3',    'dungeon_path(Player, From, Path) — Path is an accessible route from From through the dungeon').
battery_export(dungeon, 'room_cleared/2',    'room_cleared(Player, Room) — Player has visited and cleared Room').
battery_export(dungeon, 'dungeon_complete/2','dungeon_complete(Player, Dungeon) — Player has cleared all rooms in Dungeon').

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
%% Solutions are maximal walks: a path is returned only when no unvisited
%% accessible room remains from its last step. (Earlier every prefix was a
%% solution, so the first answer was always [From] alone.)
dungeon_path(Player, From, Path) :-
    dungeon_path_(Player, From, [From], RevPath),
    reverse(RevPath, Path).

dungeon_path_(Player, Current, Visited, Visited) :-
    \+ dungeon_step(Player, Current, Visited, _).
dungeon_path_(Player, Current, Visited, Path) :-
    dungeon_step(Player, Current, Visited, Next),
    dungeon_path_(Player, Next, [Next|Visited], Path).

dungeon_step(Player, Current, Visited, Next) :-
    room_connected(Current, Next),
    \+ member(Next, Visited),
    room_accessible(Player, Next).

%% room_cleared(+Player, +Room) — either per-player shape.
room_cleared(Player, Room) :-
    atom_concat(Player, '_dungeon', Key),
    relation(Key, cleared, Room).
room_cleared(Player, Room) :-
    relation(Player, cleared_room, Room).

%% room_cleared(+Player, +Dungeon, +Room) — per-dungeon: a `cleared` relation on
%% the composite <player>_<dungeon>, so the same room name in two dungeons is
%% two clearances. Falls back to the per-player shapes.
room_cleared(Player, Dungeon, Room) :-
    dungeon_clear_key(Player, Dungeon, Key),
    relation(Key, cleared, Room).
room_cleared(Player, _Dungeon, Room) :-
    room_cleared(Player, Room).

dungeon_clear_key(Player, Dungeon, Key) :-
    atom_concat(Player, '_', Tmp),
    atom_concat(Tmp, Dungeon, Key).

%% dungeon_complete(+Player, +Dungeon)
dungeon_complete(Player, Dungeon) :-
    \+ ( relation(Dungeon, has_room, Room),
         \+ room_cleared(Player, Dungeon, Room) ).
