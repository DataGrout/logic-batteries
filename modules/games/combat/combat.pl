%% Battery: combat v1.0.0
%% Exports: effective_damage/4, can_attack/2, status_effect_active/2,
%%          turn_order/2, is_defeated/1, resistance/3

battery_module(combat, '1.0.0', auto).

battery_export(combat, 'effective_damage/4',    'effective_damage(Attacker, Target, BaseAmt, FinalAmt) — FinalAmt after type interactions, armor, resistances, and buffs').
battery_export(combat, 'can_attack/2',          'can_attack(Attacker, Target) — true if Attacker may act against Target this turn').
battery_export(combat, 'status_effect_active/2','status_effect_active(Entity, Effect) — Entity currently has Effect applied').
battery_export(combat, 'turn_order/2',          'turn_order(Combatants, Ordered) — Ordered is Combatants sorted by speed (desc), ties broken by entity name').
battery_export(combat, 'is_defeated/1',         'is_defeated(Entity) — Entity has 0 or fewer HP').
battery_export(combat, 'resistance/3',          'resistance(Entity, DamageType, Factor) — Factor (0.0–2.0) applied to DamageType against Entity').

%% ── Damage Types ─────────────────────────────────────────────────────────────
%%
%% Elemental type chart:
%%   relation(fire,       strong_against,   ice)
%%   relation(fire,       weak_against,     water)
%%   relation(ice,        strong_against,   earth)
%%   relation(lightning,  strong_against,   water)
%%   ...
%%
%% Per-entity resistances / weaknesses:
%%   attribute(goblin, resist_fire, 0.5)      %% fire does half damage
%%   attribute(goblin, weak_water,  2.0)      %% water does double damage
%%   attribute(dragon, immune_fire, 0)        %% fire does zero damage
%%
%% Entity type (used for type-chart lookups):
%%   attribute(goblin, element, earth)

%% resistance(+Entity, +DamageType, -Factor)
%% Factor applied to damage of DamageType against Entity.
%% 0.0 = immune, 0.5 = resist, 1.0 = neutral, 2.0 = weak
resistance(Entity, DType, Factor) :-
    atom_concat(immune_, DType, Attr),
    attribute(Entity, Attr, _), !,
    Factor = 0.
resistance(Entity, DType, Factor) :-
    atom_concat(resist_, DType, Attr),
    attribute(Entity, Attr, Factor), !.
resistance(Entity, DType, Factor) :-
    atom_concat(weak_, DType, Attr),
    attribute(Entity, Attr, Factor), !.
resistance(Entity, DType, Factor) :-
    %% Type-chart: check entity's element vs damage type
    attribute(Entity, element, Element),
    relation(DType, strong_against, Element), !,
    Factor = 2.0.
resistance(Entity, DType, Factor) :-
    attribute(Entity, element, Element),
    relation(DType, weak_against, Element), !,
    Factor = 0.5.
resistance(_, _, 1.0).

%% ── Armor ────────────────────────────────────────────────────────────────────
%%
%% Flat damage reduction:
%%   attribute(knight, armor, 15)   %% reduces incoming damage by 15 (after type mods)
%%   attribute(knight, armor_type, physical)  %% only blocks physical damage (optional)

armor_reduction(Target, DamageType, Reduction) :-
    attribute(Target, armor, Reduction),
    ( attribute(Target, armor_type, AType)
      -> AType == DamageType
      ;  true ), !.
armor_reduction(_, _, 0).

%% ── Buffs / Debuffs ──────────────────────────────────────────────────────────
%%
%% Damage multiplier buffs on the attacker:
%%   attribute(alice, buff_damage, 1.5)    %% 50% damage boost
%%   attribute(alice, debuff_damage, 0.5)  %% 50% damage penalty

attacker_damage_factor(Attacker, Factor) :-
    ( attribute(Attacker, buff_damage,   Buff)   -> true ; Buff   = 1.0 ),
    ( attribute(Attacker, debuff_damage, Debuff) -> true ; Debuff = 1.0 ),
    Factor is Buff * Debuff.

%% ── effective_damage/4 ───────────────────────────────────────────────────────
%%
%% effective_damage(+Attacker, +Target, +Base, -Final)
%% Applies: attacker buffs → type resistance → armor reduction → floor at 0.
%%
%% Damage type is read from:
%%   attribute(Attacker, damage_type, fire)   %% attacker's elemental type
%% Falls back to 'physical' if not set.

effective_damage(Attacker, Target, Base, Final) :-
    ( attribute(Attacker, damage_type, DType) -> true ; DType = physical ),
    attacker_damage_factor(Attacker, AttFactor),
    resistance(Target, DType, ResFactor),
    armor_reduction(Target, DType, Armor),
    Raw is Base * AttFactor * ResFactor - Armor,
    Final is max(0, round(Raw)).

%% ── can_attack/2 ─────────────────────────────────────────────────────────────
%%
%% Conditions that prevent attacking:
%%   attribute(alice, status, stunned)
%%   attribute(alice, status, frozen)
%%   attribute(alice, status, sleeping)
%%   attribute(alice, out_of_range, goblin)   %% target too far away
%%
%% Attacking a defeated target is not allowed.

can_attack(Attacker, Target) :-
    \+ is_defeated(Attacker),
    \+ is_defeated(Target),
    \+ status_blocks_action(Attacker),
    \+ relation(Attacker, out_of_range, Target).

status_blocks_action(Entity) :-
    status_effect_active(Entity, stunned).
status_blocks_action(Entity) :-
    status_effect_active(Entity, frozen).
status_blocks_action(Entity) :-
    status_effect_active(Entity, sleeping).

%% ── status_effect_active/2 ───────────────────────────────────────────────────
%%
%% Assert status effects:
%%   attribute(alice, status, poisoned)
%%   attribute(alice, status, burning)
%%
%% Multiple effects are supported — each status is a separate attribute fact.
%% Duration tracking (optional):
%%   attribute(alice, status_turns_poisoned, 3)

status_effect_active(Entity, Effect) :-
    attribute(Entity, status, Effect).

%% ── is_defeated/1 ────────────────────────────────────────────────────────────
%%
%%   attribute(goblin, hp, 0)   → defeated
%%   attribute(goblin, hp, -5)  → defeated

is_defeated(Entity) :-
    attribute(Entity, hp, HP),
    HP =< 0.

%% ── turn_order/2 ─────────────────────────────────────────────────────────────
%%
%% Sort combatants by speed descending; ties broken alphabetically by name.
%%   attribute(alice,  speed, 12)
%%   attribute(goblin, speed, 8)
%%
%% Default speed is 0 (acts last).

%% Negate speed so msort ascending = fastest first; ties break alphabetically.
turn_order(Combatants, Ordered) :-
    maplist(combatant_sort_key, Combatants, Pairs),
    msort(Pairs, Sorted),
    pairs_values(Sorted, Ordered).

combatant_sort_key(Entity, NegSpeed-Entity) :-
    ( attribute(Entity, speed, S) -> true ; S = 0 ),
    NegSpeed is -S.
