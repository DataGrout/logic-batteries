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

%% Bound, the score is compared, not skipped for the 0 default.
test(bound_rep_checks_the_score, [setup(setup_alice_friendly_traders), cleanup(clear_facts)]) :-
    assertion(faction_reputation(alice, traders_guild, 5000)),
    assertion(\+ faction_reputation(alice, traders_guild, 0)).

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

%% Bound, only the player's own tier holds: an exalted player used to read as
%% revered, honored, friendly and neutral too, and a hostile one as unfriendly.
test(bound_standing_is_the_one_tier, [setup(setup_alice_exalted_traders), cleanup(clear_facts)]) :-
    assertion(faction_standing(alice, traders_guild, exalted)),
    assertion(\+ faction_standing(alice, traders_guild, friendly)),
    assertion(\+ faction_standing(alice, traders_guild, neutral)).

test(bound_hostile_is_not_unfriendly, [setup(setup_alice_hostile_bandits), cleanup(clear_facts)]) :-
    assertion(faction_standing(alice, bandits, hostile)),
    assertion(\+ faction_standing(alice, bandits, unfriendly)).

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

%% ── negative standings mirror the positive thresholds (v1.0.1) ───────────────

setup_fac_fix_negative_scores :-
    assertz(attribute(alice_g1, score, -3000)),
    assertz(attribute(alice_g2, score, -5000)),
    assertz(attribute(alice_g3, score, -1)),
    assertz(attribute(alice_g4, score, -6000)).

:- begin_tests(faction_negative_standings).

test(at_unfriendly_threshold_is_unfriendly, [setup(setup_fac_fix_negative_scores), cleanup(clear_facts)]) :-
    faction_standing(alice, g1, S), assertion(S == unfriendly).

test(between_thresholds_is_unfriendly_not_neutral, [setup(setup_fac_fix_negative_scores), cleanup(clear_facts)]) :-
    %% −5000 used to match neither negative clause and fall through to neutral
    faction_standing(alice, g2, S), assertion(S == unfriendly).

test(slightly_negative_is_neutral, [setup(setup_fac_fix_negative_scores), cleanup(clear_facts)]) :-
    faction_standing(alice, g3, S), assertion(S == neutral).

test(at_hostile_threshold_is_hostile, [setup(setup_fac_fix_negative_scores), cleanup(clear_facts)]) :-
    faction_standing(alice, g4, S), assertion(S == hostile).

:- end_tests(faction_negative_standings).

%% ── Unbound faction: every ally / enemy, both directions ─────────────────────

fac_setup_listers :-
    assertz(relation(elves, allied_with, dwarves)),
    assertz(relation(men, allied_with, elves)),
    assertz(relation(elves, at_war_with, orcs)),
    assertz(relation(goblins, at_war_with, elves)),
    assertz(relation(elves, at_war_with, trolls)).

:- begin_tests(faction_unbound).

test(faction_allied_lists_every_ally, [setup(fac_setup_listers), cleanup(clear_facts)]) :-
    findall(F, faction_allied(elves, F), Fs0),
    msort(Fs0, Fs),
    assertion(Fs == [dwarves, men]),
    findall(F, faction_allied(F, elves), Gs0),
    msort(Gs0, Gs),
    assertion(Gs == [dwarves, men]).

test(faction_at_war_lists_every_enemy, [setup(fac_setup_listers), cleanup(clear_facts)]) :-
    findall(F, faction_at_war(elves, F), Fs0),
    msort(Fs0, Fs),
    assertion(Fs == [goblins, orcs, trolls]).

test(faction_allied_both_unbound, [setup(fac_setup_listers), cleanup(clear_facts)]) :-
    findall(A-B, faction_allied(A, B), Ps0),
    msort(Ps0, Ps),
    assertion(Ps == [dwarves-elves, elves-dwarves, elves-men, men-elves]).

test(faction_allied_bound_is_deterministic, [setup(fac_setup_listers), cleanup(clear_facts)]) :-
    findall(x, faction_allied(dwarves, elves), Xs),
    assertion(Xs == [x]).

:- end_tests(faction_unbound).
