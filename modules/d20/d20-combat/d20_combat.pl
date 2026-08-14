%% Battery: d20-combat v1.0.0
%% SRD 5.1 (CC BY 4.0) — AC-based hit resolution, damage, initiative, conditions.
%% Requires: d20-core AND d20-conditions in same namespace.
%% (d20_can_attack/2, advantage_on_attack/2, disadvantage_on_attack/2 all call
%%  d20_condition_active/2, which is defined by d20-conditions.)
%%
%% Exports: hits_ac/3, hits_ac/4, d20_damage/4, d20_crit_damage/4,
%%          d20_is_defeated/1, d20_initiative_order/2, d20_resistance/3, d20_damage_category/2,
%%          advantage_on_attack/2, disadvantage_on_attack/2, d20_can_attack/2,
%%          d20_attack_roll_mode/3, d20_death_save/2, d20_instant_death/2

%% Input predicates — declared dynamic for standalone (consult) use;
%% DataGrout strips directives at cell install time.
:- dynamic(attribute/3).
:- dynamic(relation/3).

battery_module('d20-combat', '1.0.0', auto).

battery_export('d20-combat', 'hits_ac/3',              'hits_ac(Attacker, Target, Roll) — true if melee Roll hits Target''s AC').
battery_export('d20-combat', 'hits_ac/4',              'hits_ac(Attacker, Target, Roll, Type) — Type: melee|ranged|spell').
battery_export('d20-combat', 'd20_damage/4',           'd20_damage(Attacker, Target, DiceRoll, Final) — final damage after ability mod and resistances').
battery_export('d20-combat', 'd20_crit_damage/4',      'd20_crit_damage(Attacker, Target, DiceRoll, Final) — critical hit doubles the dice').
battery_export('d20-combat', 'd20_is_defeated/1',          'd20_is_defeated(Entity) — Entity has 0 or fewer HP').
battery_export('d20-combat', 'd20_initiative_order/2',     'd20_initiative_order(Combatants, Ordered) — sorted by initiative descending; uses keysort, not msort').
battery_export('d20-combat', 'd20_resistance/3',           'd20_resistance(Entity, DamageType, Factor) — 0=immune, 0.5=resist, 1=normal, 2=vulnerable').
battery_export('d20-combat', 'd20_damage_category/2',      'd20_damage_category(Type, Category) — slashing/piercing/bludgeoning map to physical').
battery_export('d20-combat', 'advantage_on_attack/2',  'advantage_on_attack(Attacker, Target) — condition or terrain grants advantage').
battery_export('d20-combat', 'disadvantage_on_attack/2','disadvantage_on_attack(Attacker, Target) — condition or terrain imposes disadvantage').
battery_export('d20-combat', 'd20_can_attack/2',           'd20_can_attack(Attacker, Target) — both alive, no blocking condition, not out of range').
battery_export('d20-combat', 'd20_attack_roll_mode/3',  'd20_attack_roll_mode(Attacker, Target, Mode) — advantage|disadvantage|normal with RAW cancellation').
battery_export('d20-combat', 'd20_death_save/2',        'd20_death_save(Roll, Outcome) — critical_failure|failure|success|critical_success').
battery_export('d20-combat', 'd20_instant_death/2',     'd20_instant_death(Entity, RemainingDamage) — remaining damage at 0 HP meets or exceeds HP max').

%% ── Damage Categories ────────────────────────────────────────────────────────
%%
%% Physical damage subtypes group under `physical` so that resist_physical /
%% immune_physical catches all three without enumerating them individually.
%% Type chart lookups still use the specific subtype for inter-entity relations.

d20_damage_category(slashing,    physical).
d20_damage_category(piercing,    physical).
d20_damage_category(bludgeoning, physical).
d20_damage_category(Type,        Type).     %% all others are their own category

%% ── Armor Class ──────────────────────────────────────────────────────────────
%%
%% Primary: assert AC directly:
%%   attribute(fighter, ac, 16)
%%
%% Or derive from base armor + DEX + shield:
%%   attribute(rogue, armor_base_ac, 12)    %% leather — DEX is added (no cap)
%%   attribute(paladin, armor_base_ac, 18)  %% plate — no DEX added
%%   attribute(paladin, no_dex_to_ac, true) %% heavy armor flag (suppresses DEX)
%%   attribute(paladin, shield, true)       %% +2 bonus
%%
%% Simplification: medium armor (DEX cap +2) is not modelled. Use no_dex_to_ac
%% for heavy armor; omit it for light/unarmored (full DEX applies in both cases).
%% Unarmored: 10 + DEX (default when no armor_base_ac or ac set).

entity_ac(Entity, AC) :-
    attribute(Entity, ac, AC), !.
entity_ac(Entity, AC) :-
    ( attribute(Entity, armor_base_ac, Base)
      -> ( attribute(Entity, no_dex_to_ac, true) -> DexBonus = 0
         ; entity_ability_mod(Entity, dex, DexBonus)
         )
      ;  Base = 10,
         entity_ability_mod(Entity, dex, DexBonus)
    ),
    ( attribute(Entity, shield, true) -> Sh = 2 ; Sh = 0 ),
    AC is Base + DexBonus + Sh.

%% ── Resistance / Immunity / Vulnerability ────────────────────────────────────
%%
%% Per-entity flags (all are booleans — presence = active):
%%   attribute(skeleton, vulnerable_bludgeoning, true)
%%   attribute(shadow,   resist_physical,        true)   %% catches slashing/piercing/bludgeoning
%%   attribute(golem,    immune_bludgeoning,      true)
%%
%% d20_resistance(+Entity, +DamageType, -Factor)
%% Checks specific type first, then its category, then defaults to 1.0.
%% Priority: immune > resist > vulnerable > 1.0
%%
%% Simplification: RAW, resistance AND vulnerability to the same type cancel
%% to normal damage. This battery gives resist priority (0.5). Retract one of
%% the flags if a campaign needs the RAW cancellation.

d20_resistance(Entity, DType, Factor) :-
    d20_damage_category(DType, Cat),
    ( ( atom_concat(immune_, DType, A), attribute(Entity, A, _) )
    ; ( atom_concat(immune_, Cat,   A), attribute(Entity, A, _) )
    ), !,
    Factor = 0.

d20_resistance(Entity, DType, Factor) :-
    d20_damage_category(DType, Cat),
    ( ( atom_concat(resist_, DType, A), attribute(Entity, A, _) )
    ; ( atom_concat(resist_, Cat,   A), attribute(Entity, A, _) )
    ), !,
    Factor = 0.5.

d20_resistance(Entity, DType, Factor) :-
    d20_damage_category(DType, Cat),
    ( ( atom_concat(vulnerable_, DType, A), attribute(Entity, A, _) )
    ; ( atom_concat(vulnerable_, Cat,   A), attribute(Entity, A, _) )
    ), !,
    Factor = 2.0.

d20_resistance(_, _, 1.0).

%% ── Hit Resolution ───────────────────────────────────────────────────────────
%%
%% hits_ac(+Attacker, +Target, +RolledD20)
%% Natural 1 always misses; natural 20 always hits; otherwise Roll+Bonus vs AC.
%%
%% The caller supplies the d20 roll — the logic cell is stateless.

hits_ac(_, _, 1)  :- !, fail.
hits_ac(_, _, 20) :- !.
hits_ac(Attacker, Target, Roll) :-
    hits_ac(Attacker, Target, Roll, melee).

hits_ac(_, _, 1,  _)    :- !, fail.
hits_ac(_, _, 20, _)    :- !.
hits_ac(Attacker, Target, Roll, AttackType) :-
    attack_bonus(Attacker, AttackType, Bonus),
    entity_ac(Target, AC),
    Roll + Bonus >= AC.

%% ── Damage Calculation ───────────────────────────────────────────────────────
%%
%% d20_damage(+Attacker, +Target, +DiceRoll, -Final)
%% DiceRoll is the raw damage dice result (e.g., 1d8 = 5).
%% Adds the relevant ability modifier, applies resistance, floors at 0.
%%
%% Damage ability defaults:
%%   melee weapon → STR (or DEX for finesse, if attribute(Entity, finesse_attack, true))
%%   ranged weapon → DEX
%%   spell → spellcasting_ability
%%
%% Override: attribute(Entity, damage_ability, dex)
%%
%% Damage type: attribute(Entity, damage_type, slashing)   [defaults to bludgeoning]

d20_damage(Attacker, Target, DiceRoll, Final) :-
    ( attribute(Attacker, damage_bonus, DAbilMod)
      %% explicit flat bonus (monster stat blocks) beats ability derivation
      -> true
      ; damage_abil_mod_(Attacker, DAbilMod)
    ),
    ( attribute(Attacker, damage_type, DType) -> true ; DType = bludgeoning ),
    d20_resistance(Target, DType, Factor),
    Raw is max(0, (DiceRoll + DAbilMod) * Factor),
    %% SRD 5.1: when resistance halves damage, round DOWN (7 resisted = 3).
    Final is floor(Raw).

damage_abil_mod_(Attacker, DAbilMod) :-
    ( attribute(Attacker, damage_ability, DAbil)
      -> entity_ability_mod(Attacker, DAbil, DAbilMod)
      ;  ( attribute(Attacker, finesse_attack, true)
           -> entity_ability_mod(Attacker, str, StrM),
              entity_ability_mod(Attacker, dex, DexM),
              DAbilMod is max(StrM, DexM)
           ;  entity_ability_mod(Attacker, str, DAbilMod)
         )
    ).

%% Critical hit: double the dice roll (SRD 5.1), then add mod and apply resistance.
d20_crit_damage(Attacker, Target, DiceRoll, Final) :-
    CritRoll is DiceRoll * 2,
    d20_damage(Attacker, Target, CritRoll, Final).

%% ── Defeat ───────────────────────────────────────────────────────────────────

d20_is_defeated(Entity) :-
    attribute(Entity, hp, HP),
    HP =< 0.

%% ── Initiative Order ─────────────────────────────────────────────────────────
%%
%% d20_initiative_order(+Combatants, -Ordered)
%% Ordered is Combatants sorted by initiative descending. Tied initiatives
%% keep no guaranteed order — assert distinct initiative values (or re-roll)
%% when order among ties matters.
%%
%% Assert rolled initiatives:  attribute(fighter, initiative, 17)
%% Fallback: DEX modifier (unrolled, for static ordering).
%%
%% Uses keysort/2 (ISO-standard) — does NOT rely on msort/2.

entity_initiative(Entity, Init) :-
    ( attribute(Entity, initiative, Init) -> true
    ; entity_ability_mod(Entity, dex, Init)
    ).

%% Keys are negated, so ascending keysort IS descending initiative —
%% no reverse (negate + reverse would double-invert back to ascending).
%% d20_pair_values_/2 is hand-rolled: library(pairs) is not in the ISO
%% (Scryer) prelude, and this battery must run on both engines.
d20_initiative_order(Combatants, Ordered) :-
    maplist(initiative_key_, Combatants, Pairs),
    keysort(Pairs, Sorted),
    d20_pair_values_(Sorted, Ordered).

d20_pair_values_([], []).
d20_pair_values_([_-V|T], [V|VT]) :- d20_pair_values_(T, VT).

initiative_key_(Entity, NegInit-Entity) :-
    entity_initiative(Entity, Init),
    NegInit is -Init.

%% ── Action Gating ────────────────────────────────────────────────────────────

d20_can_attack(Attacker, Target) :-
    \+ d20_is_defeated(Attacker),
    \+ d20_is_defeated(Target),
    \+ d20_action_blocked(Attacker),
    \+ relation(Attacker, out_of_range, Target).

d20_action_blocked(Entity) :-
    d20_condition_active(Entity, paralyzed).
d20_action_blocked(Entity) :-
    d20_condition_active(Entity, stunned).
d20_action_blocked(Entity) :-
    d20_condition_active(Entity, unconscious).
d20_action_blocked(Entity) :-
    d20_condition_active(Entity, incapacitated).

%% ── Advantage / Disadvantage ─────────────────────────────────────────────────
%%
%% advantage_on_attack(+Attacker, +Target) and
%% disadvantage_on_attack(+Attacker, +Target)
%%
%% The client takes the higher/lower of two d20 rolls.
%% These predicates derive the state — they don't produce a roll.
%%
%% Condition-based advantage/disadvantage is forwarded from d20-conditions.
%% Terrain/positional advantage can be asserted:
%%   relation(fighter, has_high_ground_vs, goblin)  → advantage
%%   relation(ranger,  has_cover_vs, orc)            → disadvantage

advantage_on_attack(Attacker, _Target) :-
    d20_condition_active(Attacker, invisible), !.
advantage_on_attack(_Attacker, Target) :-
    d20_condition_active(Target, blinded), !.
advantage_on_attack(_Attacker, Target) :-
    ( d20_condition_active(Target, paralyzed)
    ; d20_condition_active(Target, unconscious)
    ; d20_condition_active(Target, stunned)
    ), !.
advantage_on_attack(Attacker, Target) :-
    d20_condition_active(Target, prone),
    relation(Attacker, adjacent_to, Target), !.
advantage_on_attack(Attacker, Target) :-
    relation(Attacker, has_high_ground_vs, Target), !.
advantage_on_attack(Attacker, Target) :-
    relation(Attacker, flanking, Target), !.

disadvantage_on_attack(Attacker, _Target) :-
    ( d20_condition_active(Attacker, poisoned)
    ; d20_condition_active(Attacker, blinded)
    ; d20_condition_active(Attacker, prone)
    ; d20_condition_active(Attacker, restrained)
    ), !.
disadvantage_on_attack(Attacker, Target) :-
    d20_condition_active(Attacker, frightened),
    relation(Attacker, can_see, Target), !.
disadvantage_on_attack(_Attacker, Target) :-
    d20_condition_active(Target, invisible), !.
disadvantage_on_attack(Attacker, Target) :-
    d20_condition_active(Target, prone),
    \+ relation(Attacker, adjacent_to, Target), !.
disadvantage_on_attack(Attacker, Target) :-
    relation(Attacker, has_cover_vs, Target), !.

%% ── Net Roll Mode ────────────────────────────────────────────────────────────
%%
%% d20_attack_roll_mode(+Attacker, +Target, -Mode)
%% Mode: advantage | disadvantage | normal.
%%
%% RAW: multiple sources of advantage don't stack, and if the roll has BOTH
%% advantage and disadvantage from any sources, they cancel to a normal roll.
%% This is the one predicate a client needs before rolling — it resolves the
%% whole advantage/disadvantage matrix into an instruction.

d20_attack_roll_mode(Attacker, Target, Mode) :-
    ( advantage_on_attack(Attacker, Target)    -> Adv = true ; Adv = false ),
    ( disadvantage_on_attack(Attacker, Target) -> Dis = true ; Dis = false ),
    ( Adv == Dis        -> Mode = normal        %% both or neither → cancel
    ; Adv == true       -> Mode = advantage
    ;                      Mode = disadvantage
    ).

%% ── Death Saves ──────────────────────────────────────────────────────────────
%%
%% d20_death_save(+Roll, -Outcome)  — pure classifier; the caller tracks the
%% success/failure tally (three of either ends the sequence).
%%   natural 1  → critical_failure (counts as two failures)
%%   2–9        → failure
%%   10–19      → success
%%   natural 20 → critical_success (regain 1 HP, conscious)

d20_death_save(1,  critical_failure) :- !.
d20_death_save(20, critical_success) :- !.
d20_death_save(Roll, failure) :- Roll >= 2,  Roll =< 9,  !.
d20_death_save(Roll, success) :- Roll >= 10, Roll =< 19.

%% ── Instant Death ────────────────────────────────────────────────────────────
%%
%% d20_instant_death(+Entity, +RemainingDamage)
%% RAW: damage that reduces you to 0 HP kills outright when the REMAINING
%% damage meets or exceeds your HP maximum.
%% Assert the maximum:  attribute(fighter, hp_max, 44)

d20_instant_death(Entity, RemainingDamage) :-
    attribute(Entity, hp_max, Max),
    RemainingDamage >= Max.
