%% Battery: inventory v1.0.0
%% Exports: can_carry/2, inventory_full/1, carrying_weight/2, item_count/2,
%%          has_item/2, item_in_slot/3, slot_available/2

%% ── Module manifest (queried by game_rules) ──────────────────────────────────

battery_module(inventory, '1.0.0', auto).

battery_export(inventory, 'can_carry/2',       'can_carry(Player, Item) — true if Player can pick up Item').
battery_export(inventory, 'inventory_full/1',  'inventory_full(Player) — true if Player has no carry capacity left').
battery_export(inventory, 'carrying_weight/2', 'carrying_weight(Player, W) — W is total weight carried').
battery_export(inventory, 'item_count/2',      'item_count(Player, N) — N is number of items carried').
battery_export(inventory, 'has_item/2',        'has_item(Player, Item) — true if Player currently carries Item').
battery_export(inventory, 'item_in_slot/3',    'item_in_slot(Player, Slot, Item) — Item is equipped in Slot').
battery_export(inventory, 'slot_available/2',  'slot_available(Player, Slot) — Slot is empty for Player').

%% ── Defaults (override by asserting attribute facts) ─────────────────────────

%% Max carry weight defaults to 50 unless overridden:
%%   assert { type:"attribute", entity:"alice", attribute:"max_carry_weight", value:80 }
max_carry_weight(Player, Max) :-
    attribute(Player, max_carry_weight, Max), !.
max_carry_weight(_, 50).

%% Max item slots defaults to 20 unless overridden:
%%   assert { type:"attribute", entity:"alice", attribute:"max_slots", value:30 }
max_slots(Player, Max) :-
    attribute(Player, max_slots, Max), !.
max_slots(_, 20).

%% Item weight defaults to 1 unless overridden:
%%   assert { type:"attribute", entity:"iron_sword", attribute:"weight", value:8 }
item_weight(Item, W) :-
    attribute(Item, weight, W), !.
item_weight(_, 1).

%% ── Core predicates ───────────────────────────────────────────────────────────

%% has_item/2 — derived from relation facts
has_item(Player, Item) :-
    relation(Player, has_item, Item).

%% carrying_weight/2 — sum of weights of all carried items
carrying_weight(Player, TotalWeight) :-
    findall(W,
        (has_item(Player, Item), item_weight(Item, W)),
        Weights),
    sumlist(Weights, TotalWeight).

%% item_count/2
item_count(Player, N) :-
    findall(Item, has_item(Player, Item), Items),
    length(Items, N).

%% inventory_full/1 — true if either weight or slot limit reached
inventory_full(Player) :-
    carrying_weight(Player, W),
    max_carry_weight(Player, Max),
    W >= Max, !.
inventory_full(Player) :-
    item_count(Player, N),
    max_slots(Player, Max),
    N >= Max.

%% can_carry/2 — true if picking up Item would not exceed limits
can_carry(Player, Item) :-
    \+ has_item(Player, Item),
    carrying_weight(Player, Current),
    item_weight(Item, ItemW),
    max_carry_weight(Player, MaxW),
    Current + ItemW =< MaxW,
    item_count(Player, CurrentN),
    max_slots(Player, MaxSlots),
    CurrentN < MaxSlots.

%% item_in_slot/3 — derived from equipped_in relation
item_in_slot(Player, Slot, Item) :-
    relation(Player, equipped_in, Slot),
    relation(Slot, contains, Item).

%% slot_available/2
slot_available(Player, Slot) :-
    attribute(Slot, slot_type, _),
    relation(Player, owns_slot, Slot),
    \+ item_in_slot(Player, Slot, _).
