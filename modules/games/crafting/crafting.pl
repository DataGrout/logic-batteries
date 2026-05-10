%% Tether Module: crafting v1.0.0
%% Exports: recipe_known/2, can_craft_skilled/2, crafting_skill/3,
%%          skill_requirement/3, recipe_discoverable/2

tether_module(crafting, '1.0.0', auto).

tether_export(crafting, 'recipe_known/2',         'recipe_known(Player, Recipe) — Player has learned or discovered Recipe').
tether_export(crafting, 'can_craft_skilled/2',    'can_craft_skilled(Player, Item) — Player knows the recipe and meets all skill requirements').
tether_export(crafting, 'crafting_skill/3',       'crafting_skill(Player, Skill, Level) — Player''s level in a crafting skill').
tether_export(crafting, 'skill_requirement/3',    'skill_requirement(Item, Skill, Level) — Item requires Skill at minimum Level to craft').
tether_export(crafting, 'recipe_discoverable/2',  'recipe_discoverable(Player, Recipe) — Player meets the discovery conditions for Recipe').

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

%% crafting_skill(+Player, +Skill, -Level)
crafting_skill(Player, Skill, Level) :-
    crafting_skill_key(Player, Skill, Key),
    attribute(Key, level, Level), !.
crafting_skill(_, _, 0).

%% skill_requirement(+Item, ?Skill, ?MinLevel)
skill_requirement(Item, Skill, MinLevel) :-
    attribute(Item, Attr, MinLevel),
    atom_concat(requires_, Skill, Attr).

%% recipe_known(+Player, +Recipe)
recipe_known(Player, Recipe) :-
    relation(Player, knows_recipe, Recipe), !.
recipe_known(_, Recipe) :-
    attribute(Recipe, starter_recipe, true), !.
recipe_known(Player, Recipe) :-
    recipe_discoverable(Player, Recipe).

%% recipe_discoverable(+Player, +Recipe)
recipe_discoverable(Player, Recipe) :-
    attribute(Recipe, discover_on_level, ReqLevel),
    attribute(Player, level, PlayerLevel),
    PlayerLevel >= ReqLevel, !.
recipe_discoverable(Player, Recipe) :-
    attribute(Recipe, discover_on_quest, Quest),
    relation(Player, completed_quest, Quest), !.
recipe_discoverable(Player, Recipe) :-
    attribute(Recipe, discover_on_item, Item),
    relation(Player, has_item, Item).

%% can_craft_skilled(+Player, +Item)
can_craft_skilled(Player, Item) :-
    recipe_known(Player, Item),
    \+ ( skill_requirement(Item, Skill, Required),
         crafting_skill(Player, Skill, Have),
         Have < Required ).
