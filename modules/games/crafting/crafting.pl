%% Battery: crafting v1.0.0
%% Exports: recipe_known/2, can_craft_skilled/2, crafting_skill/3,
%%          skill_requirement/3, recipe_discoverable/2

battery_module(crafting, '1.0.0', auto).

battery_export(crafting, 'recipe_known/2',         'recipe_known(Player, Recipe) — Player has learned or discovered Recipe').
battery_export(crafting, 'can_craft_skilled/2',    'can_craft_skilled(Player, Item) — Player knows the recipe and meets all skill requirements').
battery_export(crafting, 'crafting_skill/3',       'crafting_skill(Player, Skill, Level) — Player''s level in a crafting skill').
battery_export(crafting, 'skill_requirement/3',    'skill_requirement(Item, Skill, Level) — Item requires Skill at minimum Level to craft').
battery_export(crafting, 'recipe_discoverable/2',  'recipe_discoverable(Player, Recipe) — Player meets the discovery conditions for Recipe').

%% Input contract (CONTRIBUTING, "Input contract"). A recipe is named by the
%% item it makes. A player's skill level sits on the composite subject
%% <player>_<skill>. An item's minimum skill is a requires_<skill> attribute
%% whose name varies with the skill, so it cannot be listed here: the rules
%% read every requires_* attribute on the item as a skill requirement.
battery_input(crafting, player, relation(knows_recipe), ref(recipe), key,
    'A recipe the player was taught or bought.').
battery_input(crafting, player, attribute(level), integer, optional,
    'The player''s level, for discover_on_level; absent, no level discovery applies.').
battery_input(crafting, player, relation(completed_quest), atom, optional,
    'A quest the player has completed, for discover_on_quest.').
battery_input(crafting, player, relation(has_item), atom, optional,
    'An item the player holds, for discover_on_item.').
battery_input(crafting, recipe, attribute(starter_recipe), bool, key,
    'true when every player knows the recipe.').
battery_input(crafting, recipe, attribute(discover_on_level), integer, key,
    'A player at this level or above discovers the recipe.').
battery_input(crafting, recipe, attribute(discover_on_quest), atom, key,
    'A player who completed this quest (completed_quest) discovers the recipe.').
battery_input(crafting, recipe, attribute(discover_on_item), atom, key,
    'A player holding this item (has_item) discovers the recipe.').
battery_input(crafting, player_skill, attribute(level), integer, key,
    'The player''s level in the skill, on the subject <player>_<skill>; absent reads as 0.').

%% ── Crafting Data Model ───────────────────────────────────────────────────────
%%
%% Recipe knowledge (directly taught or purchased):
%%   relation(alice, knows_recipe, iron_sword)
%%
%% Skill levels:
%%   attribute(alice_smithing, level, 5)     %% keyed as player_skill
%%
%% Skill requirements per item:
%%   attribute(iron_sword, requires_smithing, 3)   %% requires_<skill>
%%
%% Discovery conditions (player learns recipe automatically when met):
%%   attribute(fire_spell, discover_on_level, 10)       %% player reaches level
%%   attribute(rare_potion, discover_on_quest, find_alchemist)  %% quest complete
%%   attribute(masterwork_blade, discover_on_item, ancient_scroll)  %% hold item
%%
%% Starter recipes (all players know these):
%%   attribute(basic_bandage, starter_recipe, true)

crafting_skill_key(Player, Skill, Key) :-
    atom_concat(Player, '_', Tmp),
    atom_concat(Tmp, Skill, Key).

%% crafting_skill(?Player, ?Skill, ?Level)
%% Bound, Level is the `<player>_<skill>` level, or 0 when none is set; it is
%% computed before it is compared. Unbound Player or Skill ranges over the
%% level facts keyed that way, each pair once, with no 0 default: a bound Player
%% reads the key after `<player>_`, a bound Skill the key before `_<skill>`, and
%% with both unbound Skill ranges over the skills some item requires.
crafting_skill(Player, Skill, Level) :-
    (   nonvar(Player), nonvar(Skill)
    ->  crafting_skill_key(Player, Skill, Key),
        crafting_key_level(Key, Level0),
        Level = Level0
    ;   setof(Player-Skill, crafting_skill_held(Player, Skill), Pairs),
        member(Player-Skill, Pairs),
        crafting_skill_key(Player, Skill, Key),
        crafting_key_level(Key, Level)
    ).

crafting_key_level(Key, Level) :-
    attribute(Key, level, Level), !.
crafting_key_level(_, 0).

crafting_skill_held(Player, Skill) :-
    nonvar(Player), !,
    atom_concat(Player, '_', Prefix),
    attribute(Key, level, _),
    atom(Key),
    atom_concat(Prefix, Skill, Key),
    Skill \== ''.
crafting_skill_held(Player, Skill) :-
    ( var(Skill) -> crafting_required_skill(Skill) ; true ),
    atom_concat('_', Skill, Suffix),
    attribute(Key, level, _),
    atom(Key),
    atom_concat(Player, Suffix, Key),
    Player \== ''.

crafting_required_skill(Skill) :-
    skill_requirement(_, Skill, _).

%% skill_requirement(+Item, ?Skill, ?MinLevel)
skill_requirement(Item, Skill, MinLevel) :-
    attribute(Item, Attr, MinLevel),
    atom_concat(requires_, Skill, Attr).

%% recipe_known(?Player, ?Recipe)
%% Unbound Recipe ranges over every recipe the facts name. A starter recipe is
%% known to anyone, so it leaves an unbound Player unbound; otherwise an
%% unbound Player ranges over the players who were taught it or can discover
%% it, each once. Bound, it succeeds at most once.
recipe_known(Player, Recipe) :-
    ( var(Recipe) -> crafting_recipe(Recipe) ; true ),
    (   attribute(Recipe, starter_recipe, true) -> true
    ;   var(Player)
    ->  setof(P, crafting_recipe_holder(P, Recipe), Players),
        member(Player, Players)
    ;   crafting_recipe_holder(Player, Recipe) -> true
    ).

crafting_recipe_holder(Player, Recipe) :-
    relation(Player, knows_recipe, Recipe).
crafting_recipe_holder(Player, Recipe) :-
    crafting_discovers(Player, Recipe).

crafting_recipe(Recipe) :-
    setof(R, crafting_recipe_named(R), Recipes),
    member(Recipe, Recipes).

crafting_recipe_named(R) :- relation(_, knows_recipe, R).
crafting_recipe_named(R) :- attribute(R, starter_recipe, true).
crafting_recipe_named(R) :- attribute(R, discover_on_level, _).
crafting_recipe_named(R) :- attribute(R, discover_on_quest, _).
crafting_recipe_named(R) :- attribute(R, discover_on_item, _).

%% recipe_discoverable(?Player, ?Recipe)
%% Unbound, each argument ranges over every match, each pair once.
recipe_discoverable(Player, Recipe) :-
    ( var(Recipe) -> crafting_recipe(Recipe) ; true ),
    (   var(Player)
    ->  setof(P, crafting_discovers(P, Recipe), Players),
        member(Player, Players)
    ;   crafting_discovers(Player, Recipe) -> true
    ).

crafting_discovers(Player, Recipe) :-
    attribute(Recipe, discover_on_level, ReqLevel),
    attribute(Player, level, PlayerLevel),
    PlayerLevel >= ReqLevel.
crafting_discovers(Player, Recipe) :-
    attribute(Recipe, discover_on_quest, Quest),
    relation(Player, completed_quest, Quest).
crafting_discovers(Player, Recipe) :-
    attribute(Recipe, discover_on_item, Item),
    relation(Player, has_item, Item).

%% can_craft_skilled(?Player, ?Item)
%% Unbound, Item ranges over the recipes Player knows. A starter recipe leaves
%% Player unbound from recipe_known; then, if the item requires some skill above
%% 0, Player ranges over the players holding one of its skills, else it stays
%% unbound (anyone can craft it).
can_craft_skilled(Player, Item) :-
    recipe_known(Player, Item),
    (   var(Player)
    ->  (   crafting_demands_skill(Item)
        ->  setof(P, crafting_skill_holder(Item, P), Players),
            member(Player, Players),
            crafting_meets_requirements(Player, Item)
        ;   true
        )
    ;   crafting_meets_requirements(Player, Item)
    ).

crafting_meets_requirements(Player, Item) :-
    \+ ( skill_requirement(Item, Skill, Required),
         crafting_skill(Player, Skill, Have),
         Have < Required ).

crafting_demands_skill(Item) :-
    skill_requirement(Item, _, Required),
    Required > 0, !.

crafting_skill_holder(Item, Player) :-
    skill_requirement(Item, Skill, _),
    crafting_skill(Player, Skill, _).
