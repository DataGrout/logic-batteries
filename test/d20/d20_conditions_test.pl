:- use_module(library(plunit)).

:- consult('../../modules/d20/d20-conditions/d20_conditions').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_stunned_goblin :-
    assertz(attribute(goblin, condition, stunned)).

setup_poisoned_orc :-
    assertz(attribute(orc, condition, poisoned)).

setup_exhausted_ranger :-
    assertz(attribute(ranger, exhaustion, 3)).

setup_restrained_bandit :-
    assertz(attribute(bandit, condition, restrained)).

:- begin_tests(d20_conditions).

test(condition_active, [setup((clear_facts, setup_stunned_goblin))]) :-
    d20_condition_active(goblin, stunned).

test(condition_not_active, [setup(clear_facts), fail]) :-
    d20_condition_active(goblin, stunned).

%% ── condition effects table ──────────────────────────────────────────────────

test(blinded_disadvantage) :-
    condition_effect(blinded, attack_rolls, disadvantage).

test(paralyzed_auto_crit_in_melee) :-
    condition_effect(paralyzed, auto_crit_incoming, within_5ft).

test(grappled_zeroes_speed) :-
    condition_effect(grappled, speed, 0).

%% ── action / reaction gating ─────────────────────────────────────────────────

test(stunned_blocks_action, [setup((clear_facts, setup_stunned_goblin))]) :-
    condition_blocks_action(goblin).

test(stunned_blocks_reaction, [setup((clear_facts, setup_stunned_goblin))]) :-
    condition_blocks_reaction(goblin).

test(poisoned_does_not_block_action,
     [setup((clear_facts, setup_poisoned_orc)), fail]) :-
    condition_blocks_action(orc).

%% ── exhaustion is cumulative ─────────────────────────────────────────────────

test(exhaustion_level_default_zero, [setup(clear_facts)]) :-
    exhaustion_level(ranger, 0).

test(exhaustion_includes_lower_tiers,
     [setup((clear_facts, setup_exhausted_ranger)), nondet]) :-
    active_exhaustion_effect(ranger, ability_checks, disadvantage),   %% tier 1
    active_exhaustion_effect(ranger, speed, halved),                  %% tier 2
    active_exhaustion_effect(ranger, attack_saves, disadvantage).     %% tier 3

test(exhaustion_excludes_higher_tiers,
     [setup((clear_facts, setup_exhausted_ranger))]) :-
    \+ active_exhaustion_effect(ranger, hp_max, halved).              %% tier 4

%% ── condition-derived advantage / disadvantage ───────────────────────────────

test(restrained_target_grants_advantage,
     [setup((clear_facts, setup_restrained_bandit))]) :-
    condition_grants_advantage_on_attack(_, bandit).

test(poisoned_attacker_has_disadvantage,
     [setup((clear_facts, setup_poisoned_orc)), nondet]) :-
    condition_imposes_disadvantage_on_attack(orc, _).

:- end_tests(d20_conditions).
