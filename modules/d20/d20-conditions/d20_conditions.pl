%% Battery: d20-conditions v1.0.0
%% SRD 5.1 (CC BY 4.0) — all 15 standard conditions + 6 exhaustion levels.
%%
%% Exports: d20_condition_active/2, condition_effect/3, exhaustion_level/2,
%%          active_exhaustion_effect/3, condition_blocks_action/1,
%%          condition_blocks_reaction/1, condition_grants_advantage_on_attack/2,
%%          condition_imposes_disadvantage_on_attack/2

%% Input predicates — declared dynamic for standalone (consult) use;
%% DataGrout strips directives at cell install time.
:- dynamic(attribute/3).

battery_module('d20-conditions', '1.0.0', auto).

battery_export('d20-conditions', 'd20_condition_active/2',                  'd20_condition_active(Entity, Condition) — Entity currently has Condition').
battery_export('d20-conditions', 'condition_effect/3',                      'condition_effect(Condition, Effect, Value) — what a condition does (for UI/AI)').
battery_export('d20-conditions', 'exhaustion_level/2',                      'exhaustion_level(Entity, Level) — 0 if none, 1–6 per SRD table').
battery_export('d20-conditions', 'active_exhaustion_effect/3',              'active_exhaustion_effect(Entity, Effect, Value) — cumulative exhaustion effects').
battery_export('d20-conditions', 'condition_blocks_action/1',               'condition_blocks_action(Entity) — Entity cannot take actions this turn').
battery_export('d20-conditions', 'condition_blocks_reaction/1',             'condition_blocks_reaction(Entity) — Entity cannot take reactions').
battery_export('d20-conditions', 'condition_grants_advantage_on_attack/2',  'condition_grants_advantage_on_attack(Attacker, Target) — condition gives adv').
battery_export('d20-conditions', 'condition_imposes_disadvantage_on_attack/2','condition_imposes_disadvantage_on_attack(Attacker, Target) — condition gives disadv').

%% ── Applying Conditions ──────────────────────────────────────────────────────
%%
%% Apply a condition:   attribute(entity, condition, blinded)
%% Multiple allowed:   attribute(entity, condition, stunned)
%%                     attribute(entity, condition, poisoned)
%%
%% Exhaustion uses a severity level:  attribute(entity, exhaustion, 3)

d20_condition_active(Entity, Condition) :-
    attribute(Entity, condition, Condition).

exhaustion_level(Entity, Level) :-
    ( attribute(Entity, exhaustion, Level) -> true ; Level = 0 ).

%% ── Condition Effects (SRD 5.1) ──────────────────────────────────────────────
%%
%% condition_effect(+Condition, +Effect, -Value)
%% All 15 conditions with their mechanical effects.
%% Values are atoms/lists representing the mechanical consequence.

condition_effect(blinded, attack_rolls,          disadvantage).
condition_effect(blinded, attack_rolls_incoming, advantage).
condition_effect(blinded, auto_fail_check,       [sight]).

condition_effect(charmed, attack_charmer,        blocked).
condition_effect(charmed, social_checks_by_charmer, advantage).

condition_effect(deafened, auto_fail_check,      [hearing]).

condition_effect(exhaustion, see_exhaustion_table, true).

condition_effect(frightened, attack_rolls,       disadvantage).    %% while source visible
condition_effect(frightened, ability_checks,     disadvantage).    %% while source visible
condition_effect(frightened, move_toward_source, blocked).

condition_effect(grappled, speed,                0).

condition_effect(incapacitated, actions,         none).
condition_effect(incapacitated, reactions,        none).

condition_effect(invisible, attack_rolls,        advantage).
condition_effect(invisible, attack_rolls_incoming, disadvantage).

condition_effect(paralyzed, actions,             none).
condition_effect(paralyzed, reactions,           none).
condition_effect(paralyzed, auto_fail_save,      [str, dex]).
condition_effect(paralyzed, attack_rolls_incoming, advantage).
condition_effect(paralyzed, auto_crit_incoming,  within_5ft).

condition_effect(petrified, actions,             none).
condition_effect(petrified, reactions,           none).
condition_effect(petrified, speed,               0).
condition_effect(petrified, auto_fail_save,      [str, dex]).
condition_effect(petrified, attack_rolls_incoming, advantage).
condition_effect(petrified, resistances,         all_nonmagical_damage).

condition_effect(poisoned, attack_rolls,         disadvantage).
condition_effect(poisoned, ability_checks,       disadvantage).

condition_effect(prone, attack_rolls,            disadvantage).
condition_effect(prone, attack_rolls_incoming_melee, advantage).
condition_effect(prone, attack_rolls_incoming_ranged, disadvantage).
condition_effect(prone, movement,                crawl_only).

condition_effect(restrained, speed,              0).
condition_effect(restrained, attack_rolls,       disadvantage).
condition_effect(restrained, attack_rolls_incoming, advantage).
condition_effect(restrained, dex_saves,          disadvantage).

condition_effect(stunned, actions,               none).
condition_effect(stunned, reactions,             none).
condition_effect(stunned, auto_fail_save,        [str, dex]).
condition_effect(stunned, attack_rolls_incoming, advantage).

condition_effect(unconscious, actions,           none).
condition_effect(unconscious, reactions,         none).
condition_effect(unconscious, speed,             0).
condition_effect(unconscious, auto_fail_save,    [str, dex]).
condition_effect(unconscious, attack_rolls_incoming, advantage).
condition_effect(unconscious, auto_crit_incoming, within_5ft).

%% ── Exhaustion Table (SRD 5.1) ───────────────────────────────────────────────
%%
%% Cumulative: all penalties at or below Entity's level apply.
%% exhaustion_penalty(Level, Effect, Value)

exhaustion_penalty(1, ability_checks,  disadvantage).
exhaustion_penalty(2, speed,           halved).
exhaustion_penalty(3, attack_saves,    disadvantage).
exhaustion_penalty(4, hp_max,          halved).
exhaustion_penalty(5, speed,           0).           %% supersedes level 2
exhaustion_penalty(6, death,           instant).

active_exhaustion_effect(Entity, Effect, Value) :-
    exhaustion_level(Entity, Level),
    Level > 0,
    exhaustion_penalty(Tier, Effect, Value),
    Tier =< Level.

%% ── Derived Queries ──────────────────────────────────────────────────────────

condition_blocks_action(Entity) :-
    d20_condition_active(Entity, C),
    condition_effect(C, actions, none).

condition_blocks_reaction(Entity) :-
    d20_condition_active(Entity, C),
    condition_effect(C, reactions, none).

%% Advantage when attacker has a condition, or target has one.
condition_grants_advantage_on_attack(Attacker, _Target) :-
    d20_condition_active(Attacker, invisible).
condition_grants_advantage_on_attack(_Attacker, Target) :-
    d20_condition_active(Target, C),
    condition_effect(C, attack_rolls_incoming, advantage).

%% Disadvantage when attacker has a condition.
%% Simplification: frightened should only apply while the source of fear is within
%% line of sight. Retract attribute(Entity, condition, frightened) when visibility
%% is lost for exact SRD behavior — the battery cannot know visibility state.
condition_imposes_disadvantage_on_attack(Attacker, _Target) :-
    d20_condition_active(Attacker, C),
    condition_effect(C, attack_rolls, disadvantage).
condition_imposes_disadvantage_on_attack(_Attacker, Target) :-
    d20_condition_active(Target, C),
    condition_effect(C, attack_rolls_incoming, disadvantage).
