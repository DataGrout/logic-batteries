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

%% ── Unbound Player / Recipe: enumerate every match ───────────────────────────

craft_setup_listers :-
    assertz(relation(alice, knows_recipe, sword)),
    assertz(relation(alice, knows_recipe, axe)),
    assertz(relation(bob,   knows_recipe, sword)),
    assertz(attribute(bandage, starter_recipe, true)),
    assertz(attribute(fire_spell, discover_on_level, 10)),
    assertz(attribute(alice, level, 12)),
    assertz(attribute(bob,   level, 15)),
    assertz(attribute(carol, level, 3)),
    assertz(attribute(potion, discover_on_quest, find_alchemist)),
    assertz(relation(bob, completed_quest, find_alchemist)).

:- begin_tests(crafting_unbound).

test(recipe_known_lists_every_recipe, [setup(craft_setup_listers), cleanup(clear_facts)]) :-
    findall(R, recipe_known(alice, R), Rs0),
    msort(Rs0, Rs),
    assertion(Rs == [axe, bandage, fire_spell, sword]).

test(recipe_known_lists_every_player, [setup(craft_setup_listers), cleanup(clear_facts)]) :-
    findall(P, recipe_known(P, sword), Ps0),
    msort(Ps0, Ps),
    assertion(Ps == [alice, bob]),
    findall(P, recipe_known(P, fire_spell), Fs0),
    msort(Fs0, Fs),
    assertion(Fs == [alice, bob]).

test(recipe_known_starter_is_anyone, [setup(craft_setup_listers), cleanup(clear_facts)]) :-
    recipe_known(P, bandage), assertion(var(P)).

test(recipe_discoverable_lists_every_pair, [setup(craft_setup_listers), cleanup(clear_facts)]) :-
    findall(P-R, recipe_discoverable(P, R), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [alice-fire_spell, bob-fire_spell, bob-potion]).

test(recipe_known_bound_is_deterministic, [setup(craft_setup_listers), cleanup(clear_facts)]) :-
    findall(x, recipe_known(bob, sword), Xs),
    assertion(Xs == [x]).

:- end_tests(crafting_unbound).

%% ── Unbound Player / Skill: crafting_skill and can_craft_skilled ─────────────

craft_setup_skills :-
    assertz(relation(alice, knows_recipe, sword)),
    assertz(relation(bob,   knows_recipe, sword)),
    assertz(attribute(sword, requires_smithing, 3)),
    assertz(attribute(bandage, starter_recipe, true)),
    assertz(attribute(splint, starter_recipe, true)),
    assertz(attribute(splint, requires_first_aid, 2)),
    assertz(attribute(alice, level, 12)),
    assertz(attribute(alice_smithing, level, 5)),
    assertz(attribute(alice_first_aid, level, 1)),
    assertz(attribute(bob_smithing, level, 1)),
    assertz(attribute(dark_elf_first_aid, level, 4)).

:- begin_tests(crafting_unbound_skill).

test(crafting_skill_lists_players_for_skill, [setup(craft_setup_skills), cleanup(clear_facts)]) :-
    findall(P-L, crafting_skill(P, smithing, L), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [alice-5, bob-1]).

test(crafting_skill_lists_skills_for_player, [setup(craft_setup_skills), cleanup(clear_facts)]) :-
    findall(S-L, crafting_skill(alice, S, L), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [first_aid-1, smithing-5]).

test(crafting_skill_lists_every_pair, [setup(craft_setup_skills), cleanup(clear_facts)]) :-
    findall(P-S-L, crafting_skill(P, S, L), Triples0),
    msort(Triples0, Triples),
    assertion(Triples == [alice-first_aid-1, alice-smithing-5,
                          bob-smithing-1, dark_elf-first_aid-4]).

test(crafting_skill_bound_level_is_the_held_one, [setup(craft_setup_skills), cleanup(clear_facts)]) :-
    %% 0 is only the default for a skill with no level fact
    assertion(\+ crafting_skill(alice, smithing, 0)),
    assertion(crafting_skill(carol, smithing, 0)).

test(can_craft_skilled_lists_players, [setup(craft_setup_skills), cleanup(clear_facts)]) :-
    findall(P, can_craft_skilled(P, sword), Ps),
    assertion(Ps == [alice]).

test(can_craft_skilled_starter_with_requirement, [setup(craft_setup_skills), cleanup(clear_facts)]) :-
    findall(P, can_craft_skilled(P, splint), Ps),
    assertion(Ps == [dark_elf]).

test(can_craft_skilled_starter_without_requirement_is_anyone, [setup(craft_setup_skills), cleanup(clear_facts)]) :-
    can_craft_skilled(P, bandage), assertion(var(P)).

test(can_craft_skilled_lists_items_for_player, [setup(craft_setup_skills), cleanup(clear_facts)]) :-
    findall(I, can_craft_skilled(alice, I), Is0),
    msort(Is0, Is),
    assertion(Is == [bandage, sword]).

:- end_tests(crafting_unbound_skill).
