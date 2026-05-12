:- use_module(library(plunit)).

:- consult('../../modules/games/npc-state/npc_state').
:- consult('../../modules/games/faction/faction').
:- consult('../../modules/probabilistic/prob-npc/prob_npc').

%% (clear_facts/0 is in test/support/test_helpers.pl)
%%
%% NOTE: Annotated npc_trusts/2 rules fire probabilistically in the LC runtime.
%% Standalone tests cover the deterministic accessors: trust_probability/3,
%% npc_price_modifier/3, and disposition_probability/3, which compute numeric
%% probabilities from faction standing and relationship level without ProbLog.

%% Assert faction rep via faction_rep_key (player_faction atom concat).
setup_merchant_exalted :-
    assertz(attribute(merchant, faction, traders_guild)),
    assertz(attribute(alice_traders_guild, score, 25000)).   %% exalted (>= 21000)

setup_merchant_friendly :-
    assertz(attribute(merchant, faction, traders_guild)),
    assertz(attribute(bob_traders_guild, score, 5000)).      %% friendly (>= 3000)

setup_merchant_hostile :-
    assertz(attribute(merchant, faction, traders_guild)),
    assertz(attribute(eve_traders_guild, score, -8000)).     %% hostile (< -6000)

setup_no_faction_npc :-
    assertz(attribute(stranger, disposition, neutral)).

setup_relationship_boost :-
    setup_merchant_friendly,
    assertz(attribute(merchant_bob, score, 250)).           %% relationship score

setup_friendly_merchant_bob :-
    setup_merchant_friendly,
    assertz(attribute(merchant, disposition, friendly)),
    assertz(attribute(bob, relationship, merchant)).

setup_hostile_merchant_eve :-
    setup_merchant_hostile,
    assertz(attribute(merchant, disposition, hostile)).

%% ── trust_probability/3 ──────────────────────────────────────────────────────

:- begin_tests(prob_npc_trust_probability).

test(exalted_standing_high_trust, [setup(setup_merchant_exalted), cleanup(clear_facts)]) :-
    trust_probability(merchant, alice, P),
    assertion(P >= 0.88),
    assertion(P =< 0.99).

test(friendly_standing_mid_trust, [setup(setup_merchant_friendly), cleanup(clear_facts)]) :-
    trust_probability(merchant, bob, P),
    assertion(P >= 0.50),
    assertion(P < 0.70).

test(hostile_standing_low_trust, [setup(setup_merchant_hostile), cleanup(clear_facts)]) :-
    trust_probability(merchant, eve, P),
    assertion(P >= 0.01),
    assertion(P < 0.10).

test(no_faction_defaults_to_neutral_base, [setup(setup_no_faction_npc), cleanup(clear_facts)]) :-
    trust_probability(stranger, anyone, P),
    assertion(P >= 0.01),
    assertion(P =< 0.99).

:- end_tests(prob_npc_trust_probability).

%% ── standing_trust_base/2 ────────────────────────────────────────────────────

:- begin_tests(prob_npc_standing_trust_base).

test(exalted_base, []) :-
    assertion(standing_trust_base(exalted, 0.90)).

test(friendly_base, []) :-
    assertion(standing_trust_base(friendly, 0.55)).

test(hostile_base, []) :-
    assertion(standing_trust_base(hostile, 0.02)).

test(neutral_base, []) :-
    assertion(standing_trust_base(neutral, 0.35)).

:- end_tests(prob_npc_standing_trust_base).

%% ── npc_price_modifier/3 ─────────────────────────────────────────────────────

:- begin_tests(prob_npc_price_modifier).

test(trusted_player_gets_discount, [setup(setup_merchant_exalted), cleanup(clear_facts)]) :-
    npc_price_modifier(merchant, alice, Mod),
    assertion(Mod < 1.0).

test(hostile_player_gets_markup, [setup(setup_merchant_hostile), cleanup(clear_facts)]) :-
    npc_price_modifier(merchant, eve, Mod),
    assertion(Mod > 1.0).

test(friendly_player_near_baseline, [setup(setup_merchant_friendly), cleanup(clear_facts)]) :-
    npc_price_modifier(merchant, bob, Mod),
    assertion(Mod >= 0.70),
    assertion(Mod =< 1.30).

test(modifier_clamped_to_bounds, [setup(setup_merchant_exalted), cleanup(clear_facts)]) :-
    npc_price_modifier(merchant, alice, Mod),
    assertion(Mod >= 0.70),
    assertion(Mod =< 1.30).

:- end_tests(prob_npc_price_modifier).

%% ── disposition_probability/3 ────────────────────────────────────────────────

:- begin_tests(prob_npc_disposition).

test(friendly_npc_boosts_disposition, [setup(setup_friendly_merchant_bob), cleanup(clear_facts)]) :-
    disposition_probability(merchant, bob, P),
    trust_probability(merchant, bob, TrustP),
    assertion(P >= TrustP).

test(hostile_npc_penalises_disposition, [setup(setup_hostile_merchant_eve), cleanup(clear_facts)]) :-
    disposition_probability(merchant, eve, P),
    trust_probability(merchant, eve, TrustP),
    assertion(P =< TrustP).

test(disposition_clamped_to_valid_range, [setup(setup_merchant_friendly), cleanup(clear_facts)]) :-
    disposition_probability(merchant, bob, P),
    assertion(P >= 0.01),
    assertion(P =< 0.99).

:- end_tests(prob_npc_disposition).
