:- use_module(library(plunit)).

:- consult('../../modules/games/faction/faction').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_alice_friendly_traders :-
    assertz(attribute(alice_traders_guild, score, 5000)).

setup_alice_exalted_traders :-
    assertz(attribute(alice_traders_guild, score, 21000)).

setup_alice_hostile_bandits :-
    assertz(attribute(alice_bandits, score, -7000)).

setup_alice_zero_rep :-
    true.  %% no attribute → defaults to 0 → neutral

setup_allied_factions :-
    assertz(relation(traders_guild, allied_with, merchants_guild)).

setup_at_war :-
    assertz(relation(bandits, at_war_with, kingdom)).

setup_guild_hall_access :-
    assertz(attribute(guild_hall, requires_faction,  traders_guild)),
    assertz(attribute(guild_hall, requires_standing, friendly)).

setup_alice_friendly_access :-
    setup_alice_friendly_traders,
    setup_guild_hall_access.

setup_alice_neutral_access :-
    assertz(attribute(guild_hall, requires_faction, traders_guild)),
    assertz(attribute(guild_hall, requires_standing, friendly)).

%% ── faction_reputation/3 ─────────────────────────────────────────────────────

:- begin_tests(faction_reputation).

test(rep_from_attribute, [setup(setup_alice_friendly_traders), cleanup(clear_facts)]) :-
    faction_reputation(alice, traders_guild, R), assertion(R == 5000).

test(rep_defaults_to_zero, [cleanup(clear_facts)]) :-
    faction_reputation(alice, traders_guild, R), assertion(R == 0).

:- end_tests(faction_reputation).

%% ── faction_standing/3 ───────────────────────────────────────────────────────

:- begin_tests(faction_standing).

test(friendly_standing, [setup(setup_alice_friendly_traders), cleanup(clear_facts)]) :-
    faction_standing(alice, traders_guild, S), assertion(S == friendly).

test(exalted_standing, [setup(setup_alice_exalted_traders), cleanup(clear_facts)]) :-
    faction_standing(alice, traders_guild, S), assertion(S == exalted).

test(hostile_standing, [setup(setup_alice_hostile_bandits), cleanup(clear_facts)]) :-
    faction_standing(alice, bandits, S), assertion(S == hostile).

test(zero_rep_is_neutral, [setup(setup_alice_zero_rep), cleanup(clear_facts)]) :-
    faction_standing(alice, traders_guild, S), assertion(S == neutral).

:- end_tests(faction_standing).

%% ── faction_allied/2 + faction_at_war/2 ─────────────────────────────────────

:- begin_tests(faction_relations).

test(allied_direct, [setup(setup_allied_factions), cleanup(clear_facts)]) :-
    assertion(faction_allied(traders_guild, merchants_guild)).

test(allied_symmetric, [setup(setup_allied_factions), cleanup(clear_facts)]) :-
    assertion(faction_allied(merchants_guild, traders_guild)).

test(not_allied_unrelated, [setup(setup_allied_factions), cleanup(clear_facts)]) :-
    assertion(\+ faction_allied(traders_guild, bandits)).

test(at_war_direct, [setup(setup_at_war), cleanup(clear_facts)]) :-
    assertion(faction_at_war(bandits, kingdom)).

test(at_war_symmetric, [setup(setup_at_war), cleanup(clear_facts)]) :-
    assertion(faction_at_war(kingdom, bandits)).

:- end_tests(faction_relations).

%% ── faction_access/2 ─────────────────────────────────────────────────────────

:- begin_tests(faction_access).

test(access_with_standing, [setup(setup_alice_friendly_access), cleanup(clear_facts)]) :-
    assertion(faction_access(alice, guild_hall)).

test(no_access_neutral_when_friendly_required, [setup(setup_alice_neutral_access), cleanup(clear_facts)]) :-
    assertion(\+ faction_access(alice, guild_hall)).

test(no_access_no_faction_rep, [setup(setup_guild_hall_access), cleanup(clear_facts)]) :-
    %% alice has no rep → neutral → below friendly requirement
    assertion(\+ faction_access(alice, guild_hall)).

:- end_tests(faction_access).
