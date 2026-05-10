:- use_module(library(plunit)).

:- consult('../../modules/games/loot-tables/loot_tables').

%% (clear_facts/0 and dynamic declarations are in test/support/test_helpers.pl)

%% ── Setup predicates — all assertz calls here go to user module ───────────────

setup_chest_drops_gold :-
    assertz(relation(chest, can_drop, gold)).

setup_lake_drops_rare_fish_at_night :-
    assertz(relation(lake, can_drop, rare_fish)),
    assertz(attribute(rare_fish, loot_conditions, "[time(night)]")).

setup_gem_rare :-
    assertz(attribute(gem, rarity, rare)).

setup_all_rarity_tiers :-
    forall(
        member(T, [common, uncommon, rare, epic, legendary]),
        assertz(attribute(T, rarity, T))
    ).

setup_uncommon_item :-
    assertz(attribute(uncommon_item, rarity, uncommon)).

setup_rare_item :-
    assertz(attribute(rare_item, rarity, rare)).

setup_epic_item :-
    assertz(attribute(epic_item, rarity, epic)).

setup_legendary_item :-
    assertz(attribute(leg_item, rarity, legendary)).

setup_special_item_50pct :-
    assertz(attribute(special, rarity, legendary)),
    assertz(attribute(special, drop_chance, 50)).

setup_world_night :-
    assertz(attribute(world, time_of_day, night)).

setup_world_day :-
    assertz(attribute(world, time_of_day, day)).

setup_world_rain :-
    assertz(attribute(world, weather, rain)).

setup_world_full_moon :-
    assertz(attribute(world, moon_phase, full)).

setup_bob_level15 :-
    assertz(attribute(bob, level, 15)).

setup_bob_level5 :-
    assertz(attribute(bob, level, 5)).

setup_bob_has_key :-
    assertz(relation(bob, has_item, magic_key)).

setup_lake_fish_night_world :-
    assertz(relation(lake, can_drop, rare_fish)),
    assertz(attribute(rare_fish, loot_conditions, [time(night)])),
    assertz(attribute(world, time_of_day, night)).

setup_lake_fish_day_world :-
    assertz(relation(lake, can_drop, rare_fish)),
    assertz(attribute(rare_fish, loot_conditions, [time(night)])),
    assertz(attribute(world, time_of_day, day)).

setup_lake_moon_fish_night_only :-
    assertz(relation(lake, can_drop, moon_fish)),
    assertz(attribute(moon_fish, loot_conditions, [time(night), moon(full)])),
    assertz(attribute(world, time_of_day, night)).

setup_lake_moon_fish_all_met :-
    assertz(relation(lake, can_drop, moon_fish)),
    assertz(attribute(moon_fish, loot_conditions, [time(night), moon(full)])),
    assertz(attribute(world, time_of_day, night)),
    assertz(attribute(world, moon_phase, full)).

%% ── drops/2 ──────────────────────────────────────────────────────────────────

:- begin_tests(loot_drops).

test(drops_true, [setup(setup_chest_drops_gold), cleanup(clear_facts)]) :-
    assertion(drops(chest, gold)).

test(drops_false, [setup(true), cleanup(clear_facts)]) :-
    assertion(\+ drops(chest, gold)).

test(drops_at_with_conditions, [setup(setup_lake_drops_rare_fish_at_night),
                                  cleanup(clear_facts)]) :-
    drops_at(lake, rare_fish, Cond),
    assertion(Cond == "[time(night)]").

:- end_tests(loot_drops).

%% ── rarity_tier ───────────────────────────────────────────────────────────────

:- begin_tests(loot_rarity).

test(explicit_rarity, [setup(setup_gem_rare), cleanup(clear_facts)]) :-
    rarity_tier(gem, T),
    assertion(T == rare).

test(default_rarity_common, [setup(true), cleanup(clear_facts)]) :-
    rarity_tier(unknown_item, T),
    assertion(T == common).

test(all_tiers_recognized, [setup(setup_all_rarity_tiers), cleanup(clear_facts)]) :-
    forall(
        member(Tier, [common, uncommon, rare, epic, legendary]),
        rarity_tier(Tier, Tier)
    ).

:- end_tests(loot_rarity).

%% ── loot_chance ───────────────────────────────────────────────────────────────

:- begin_tests(loot_chance).

test(chance_common, [setup(true), cleanup(clear_facts)]) :-
    loot_chance(_, common_item, C),
    assertion(C == 70).

test(chance_uncommon, [setup(setup_uncommon_item), cleanup(clear_facts)]) :-
    loot_chance(_, uncommon_item, C),
    assertion(C == 30).

test(chance_rare, [setup(setup_rare_item), cleanup(clear_facts)]) :-
    loot_chance(_, rare_item, C),
    assertion(C == 10).

test(chance_epic, [setup(setup_epic_item), cleanup(clear_facts)]) :-
    loot_chance(_, epic_item, C),
    assertion(C == 3).

test(chance_legendary, [setup(setup_legendary_item), cleanup(clear_facts)]) :-
    loot_chance(_, leg_item, C),
    assertion(C == 1).

test(explicit_drop_chance_overrides_rarity, [setup(setup_special_item_50pct),
                                              cleanup(clear_facts)]) :-
    loot_chance(_, special, C),
    assertion(C == 50).

:- end_tests(loot_chance).

%% ── condition_met ─────────────────────────────────────────────────────────────

:- begin_tests(loot_conditions).

test(condition_always, [setup(true), cleanup(clear_facts)]) :-
    assertion(condition_met(always, _)).

test(condition_time_met, [setup(setup_world_night), cleanup(clear_facts)]) :-
    assertion(condition_met(time(night), _)).

test(condition_time_not_met, [setup(setup_world_day), cleanup(clear_facts)]) :-
    assertion(\+ condition_met(time(night), _)).

test(condition_weather_met, [setup(setup_world_rain), cleanup(clear_facts)]) :-
    assertion(condition_met(weather(rain), _)).

test(condition_moon_met, [setup(setup_world_full_moon), cleanup(clear_facts)]) :-
    assertion(condition_met(moon(full), _)).

test(condition_player_level_met, [setup(setup_bob_level15), cleanup(clear_facts)]) :-
    assertion(condition_met(player_level_gte(10), bob)).

test(condition_player_level_not_met, [setup(setup_bob_level5), cleanup(clear_facts)]) :-
    assertion(\+ condition_met(player_level_gte(10), bob)).

test(condition_player_has_item_met, [setup(setup_bob_has_key), cleanup(clear_facts)]) :-
    assertion(condition_met(player_has(magic_key), bob)).

test(condition_player_has_item_not_met, [setup(true), cleanup(clear_facts)]) :-
    assertion(\+ condition_met(player_has(magic_key), bob)).

:- end_tests(loot_conditions).

%% ── eligible_loot ─────────────────────────────────────────────────────────────

:- begin_tests(loot_eligible).

test(eligible_unconditional, [setup(setup_chest_drops_gold), cleanup(clear_facts)]) :-
    assertion(eligible_loot(chest, gold)).

test(eligible_condition_met, [setup(setup_lake_fish_night_world), cleanup(clear_facts)]) :-
    assertion(eligible_loot(lake, rare_fish)).

test(not_eligible_condition_unmet, [setup(setup_lake_fish_day_world), cleanup(clear_facts)]) :-
    assertion(\+ eligible_loot(lake, rare_fish)).

test(multiple_conditions_all_required, [setup(setup_lake_moon_fish_night_only),
                                         cleanup(clear_facts)]) :-
    assertion(\+ eligible_loot(lake, moon_fish)).

test(multiple_conditions_all_met, [setup(setup_lake_moon_fish_all_met),
                                    cleanup(clear_facts)]) :-
    assertion(eligible_loot(lake, moon_fish)).

:- end_tests(loot_eligible).
