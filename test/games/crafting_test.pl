:- use_module(library(plunit)).

:- consult('../../modules/games/crafting/crafting').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_alice_knows_sword :-
    assertz(relation(alice, knows_recipe, iron_sword)).

setup_starter_bandage :-
    assertz(attribute(basic_bandage, starter_recipe, true)).

setup_sword_skill_req :-
    assertz(attribute(iron_sword, requires_smithing, 3)).

setup_alice_skilled :-
    assertz(attribute(alice_smithing, level, 5)).

setup_alice_unskilled :-
    assertz(attribute(alice_smithing, level, 1)).

setup_alice_knows_skilled_sword :-
    setup_alice_knows_sword,
    setup_sword_skill_req,
    setup_alice_skilled.

setup_alice_knows_unskilled_sword :-
    setup_alice_knows_sword,
    setup_sword_skill_req,
    setup_alice_unskilled.

setup_discover_on_level :-
    assertz(attribute(fire_spell, discover_on_level, 10)).

setup_alice_level_10 :-
    assertz(attribute(alice, level, 10)).

setup_alice_level_5 :-
    assertz(attribute(alice, level, 5)).

setup_discover_on_quest :-
    assertz(attribute(rare_potion, discover_on_quest, find_alchemist)).

setup_alice_completed_quest :-
    assertz(relation(alice, completed_quest, find_alchemist)).

setup_discover_on_item :-
    assertz(attribute(masterwork_blade, discover_on_item, ancient_scroll)).

setup_alice_has_scroll :-
    assertz(relation(alice, has_item, ancient_scroll)).

%% ── crafting_skill/3 ─────────────────────────────────────────────────────────

:- begin_tests(crafting_skill).

test(skill_from_attribute, [setup(setup_alice_skilled), cleanup(clear_facts)]) :-
    crafting_skill(alice, smithing, L), assertion(L == 5).

test(skill_defaults_zero, [cleanup(clear_facts)]) :-
    crafting_skill(alice, smithing, L), assertion(L == 0).

:- end_tests(crafting_skill).

%% ── skill_requirement/3 ──────────────────────────────────────────────────────

:- begin_tests(crafting_requirements).

test(skill_requirement_found, [setup(setup_sword_skill_req), cleanup(clear_facts)]) :-
    skill_requirement(iron_sword, smithing, L), assertion(L == 3).

test(no_requirement_when_none_set, [cleanup(clear_facts)]) :-
    assertion(\+ skill_requirement(iron_sword, smithing, _)).

:- end_tests(crafting_requirements).

%% ── recipe_known/2 ───────────────────────────────────────────────────────────

:- begin_tests(crafting_recipe_known).

test(known_via_relation, [setup(setup_alice_knows_sword), cleanup(clear_facts)]) :-
    assertion(recipe_known(alice, iron_sword)).

test(known_via_starter, [setup(setup_starter_bandage), cleanup(clear_facts)]) :-
    assertion(recipe_known(alice, basic_bandage)).

test(known_via_level, [setup((setup_discover_on_level, setup_alice_level_10)), cleanup(clear_facts)]) :-
    assertion(recipe_known(alice, fire_spell)).

test(not_known_below_level, [setup((setup_discover_on_level, setup_alice_level_5)), cleanup(clear_facts)]) :-
    assertion(\+ recipe_known(alice, fire_spell)).

test(known_via_quest, [setup((setup_discover_on_quest, setup_alice_completed_quest)), cleanup(clear_facts)]) :-
    assertion(recipe_known(alice, rare_potion)).

test(not_known_quest_incomplete, [setup(setup_discover_on_quest), cleanup(clear_facts)]) :-
    assertion(\+ recipe_known(alice, rare_potion)).

test(known_via_item, [setup((setup_discover_on_item, setup_alice_has_scroll)), cleanup(clear_facts)]) :-
    assertion(recipe_known(alice, masterwork_blade)).

test(not_known_item_missing, [setup(setup_discover_on_item), cleanup(clear_facts)]) :-
    assertion(\+ recipe_known(alice, masterwork_blade)).

test(unknown_recipe, [cleanup(clear_facts)]) :-
    assertion(\+ recipe_known(alice, dragon_armor)).

:- end_tests(crafting_recipe_known).

%% ── can_craft_skilled/2 ──────────────────────────────────────────────────────

:- begin_tests(crafting_can_craft).

test(can_craft_with_skill, [setup(setup_alice_knows_skilled_sword), cleanup(clear_facts)]) :-
    assertion(can_craft_skilled(alice, iron_sword)).

test(cannot_craft_insufficient_skill, [setup(setup_alice_knows_unskilled_sword), cleanup(clear_facts)]) :-
    assertion(\+ can_craft_skilled(alice, iron_sword)).

test(cannot_craft_unknown_recipe, [setup(setup_alice_skilled), cleanup(clear_facts)]) :-
    assertion(\+ can_craft_skilled(alice, dragon_armor)).

:- end_tests(crafting_can_craft).
