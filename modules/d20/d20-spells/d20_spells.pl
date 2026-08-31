%% Battery: d20-spells v1.0.0
%% SRD 5.1 (CC BY 4.0) — spellcasting mechanics: slots, casting gates, save
%% resolution, concentration, and a starter grimoire of 14 SRD spells with
%% cantrip scaling and upcasting.
%% Requires: d20-core in the same namespace (spell_save_dc/2,
%% saving_throw_modifier/3, ability_modifier/2).
%%
%% Exports: d20_spell/3, spell_range/2, spell_cast_action/2, spell_save/3,
%%          spell_attack_roll/1, spell_concentration/1, spell_damage_type/2,
%%          spell_known/2, spell_castable/2, spell_slots_total/3, spell_slots_expended/3,
%%          spell_slot_available/2, d20_can_cast/3, spell_effective_dice/5,
%%          spell_heal_profile/4, d20_spell_save/5, d20_concentration_dc/2,
%%          d20_concentration_check/4

%% Input predicates — declared dynamic for standalone (consult) use;
%% DataGrout strips directives at cell install time.
:- dynamic(attribute/3).
:- dynamic(relation/3).

battery_module('d20-spells', '1.0.0', auto).

battery_export('d20-spells', 'd20_spell/3',            'd20_spell(Name, Level, School) — the grimoire; Level 0 is a cantrip').
battery_export('d20-spells', 'spell_range/2',          'spell_range(Name, Range) — range in feet (0 = touch/self)').
battery_export('d20-spells', 'spell_cast_action/2',    'spell_cast_action(Name, Action) — action | bonus_action').
battery_export('d20-spells', 'spell_save/3',           'spell_save(Name, Ability, OnSuccess) — saving-throw spells; OnSuccess: none | half').
battery_export('d20-spells', 'spell_attack_roll/1',    'spell_attack_roll(Name) — the spell is delivered by a spell attack roll vs AC').
battery_export('d20-spells', 'spell_concentration/1',  'spell_concentration(Name) — the spell requires concentration').
battery_export('d20-spells', 'spell_damage_type/2',    'spell_damage_type(Name, Type) — fire/cold/radiant/force/thunder/…').
battery_export('d20-spells', 'spell_known/2',          'spell_known(Caster, Spell) — the caster knows (or has prepared, if they prepare) the spell').
battery_export('d20-spells', 'spell_castable/2',       'spell_castable(Caster, Spell) — known AND a sufficient slot remains (cantrips always)').
battery_export('d20-spells', 'spell_slots_total/3',          'spell_slots_total(Caster, SlotLevel, N) — total slots of that level').
battery_export('d20-spells', 'spell_slots_expended/3',       'spell_slots_expended(Caster, SlotLevel, N) — slots already spent (defaults 0)').
battery_export('d20-spells', 'spell_slot_available/2',       'spell_slot_available(Caster, SlotLevel) — at least one slot of that level remains').
battery_export('d20-spells', 'd20_can_cast/3',             'd20_can_cast(Caster, Spell, SlotLevel) — the full casting gate: known, level fits, slot free; cantrips cast at SlotLevel 0').
battery_export('d20-spells', 'spell_effective_dice/5', 'spell_effective_dice(Spell, CasterLevel, SlotLevel, NDice, Faces) — damage dice after cantrip scaling and upcasting; the client rolls').
battery_export('d20-spells', 'spell_heal_profile/4',   'spell_heal_profile(Spell, SlotLevel, NDice, Faces) — healing dice after upcasting; add the caster''s spellcasting ability modifier').
battery_export('d20-spells', 'd20_spell_save/5',       'd20_spell_save(Caster, Target, Spell, Roll, Outcome) — the cell adjudicates the target''s save against the caster''s DC; Outcome: save_success | save_failure').
battery_export('d20-spells', 'd20_concentration_dc/2',     'd20_concentration_dc(Damage, DC) — CON save DC when damaged while concentrating: max(10, Damage // 2)').
battery_export('d20-spells', 'd20_concentration_check/4', 'd20_concentration_check(Entity, Damage, Roll, Outcome) — Outcome: holds | broken').

%% ── Spellcasting Data Model ──────────────────────────────────────────────────
%%
%% Spell slots (mutate like hp — retract and re-assert the used count):
%%   attribute(wizard, slots_l1, 4)
%%   attribute(wizard, slots_l1_used, 1)
%%   attribute(wizard, slots_l2, 2)
%%
%% Known spells:
%%   relation(wizard, knows_spell, fire_bolt)
%%
%% Prepared casters (clerics, wizards) additionally prepare:
%%   attribute(cleric, prepares_spells, true)
%%   relation(cleric, prepared_spell, cure_wounds)
%%
%% Spellcasting ability (used by d20-core for DC and attack bonus):
%%   attribute(wizard, spellcasting_ability, int)

%% ── The Grimoire (SRD 5.1) ───────────────────────────────────────────────────
%%
%% d20_spell(Name, Level, School)

d20_spell(fire_bolt,       0, evocation).
d20_spell(ray_of_frost,    0, evocation).
d20_spell(sacred_flame,    0, evocation).
d20_spell(magic_missile,   1, evocation).
d20_spell(burning_hands,   1, evocation).
d20_spell(cure_wounds,     1, evocation).
d20_spell(healing_word,    1, evocation).
d20_spell(bless,           1, enchantment).
d20_spell(shield_of_faith, 1, abjuration).
d20_spell(thunderwave,     1, evocation).
d20_spell(hold_person,     2, enchantment).
d20_spell(misty_step,      2, conjuration).
d20_spell(scorching_ray,   2, evocation).
d20_spell(web,             2, conjuration).

spell_range(fire_bolt,       120).
spell_range(ray_of_frost,    60).
spell_range(sacred_flame,    60).
spell_range(magic_missile,   120).
spell_range(burning_hands,   15).
spell_range(cure_wounds,     0).
spell_range(healing_word,    60).
spell_range(bless,           30).
spell_range(shield_of_faith, 60).
spell_range(thunderwave,     15).
spell_range(hold_person,     60).
spell_range(misty_step,      30).
spell_range(scorching_ray,   120).
spell_range(web,             60).

spell_bonus_action(healing_word).
spell_bonus_action(misty_step).

spell_cast_action(Name, Action) :-
    d20_spell(Name, _, _),
    (   spell_bonus_action(Name)
    ->  Action = bonus_action
    ;   Action = action
    ).

spell_attack_roll(fire_bolt).
spell_attack_roll(ray_of_frost).
spell_attack_roll(scorching_ray).

spell_save(sacred_flame, dex, none).
spell_save(burning_hands, dex, half).
spell_save(thunderwave, con, half).
spell_save(hold_person, wis, none).
spell_save(web, dex, none).

spell_concentration(bless).
spell_concentration(shield_of_faith).
spell_concentration(hold_person).
spell_concentration(web).

spell_damage_type(fire_bolt,     fire).
spell_damage_type(ray_of_frost,  cold).
spell_damage_type(sacred_flame,  radiant).
spell_damage_type(magic_missile, force).
spell_damage_type(burning_hands, fire).
spell_damage_type(thunderwave,   thunder).
spell_damage_type(scorching_ray, fire).

%% Base damage dice at the spell's own level: spell_damage(Name, NDice, Faces).
spell_damage(fire_bolt,     1, 10).
spell_damage(ray_of_frost,  1, 8).
spell_damage(sacred_flame,  1, 8).
spell_damage(magic_missile, 3, 4).  %% three darts of 1d4 (+1 each — client adds)
spell_damage(burning_hands, 3, 6).
spell_damage(thunderwave,   2, 8).
spell_damage(scorching_ray, 6, 6).  %% three rays of 2d6

%% Extra dice per slot level above the spell's base level.
spell_upcast_dice(magic_missile, 1).  %% +1 dart
spell_upcast_dice(burning_hands, 1).
spell_upcast_dice(thunderwave,   1).
spell_upcast_dice(scorching_ray, 2).  %% +1 ray

spell_heal(cure_wounds,  1, 8).
spell_heal(healing_word, 1, 4).
spell_upcast_heal(cure_wounds,  1).
spell_upcast_heal(healing_word, 1).

%% ── Knowing & Preparing ──────────────────────────────────────────────────────
%%
%% Prepared casters must have the spell prepared; everyone else casts from
%% what they know. Cantrips are never prepared — known is enough for all.

spell_known(Caster, Spell) :-
    d20_spell(Spell, 0, _),
    !,
    relation(Caster, knows_spell, Spell).
spell_known(Caster, Spell) :-
    attribute(Caster, prepares_spells, true),
    !,
    relation(Caster, prepared_spell, Spell).
spell_known(Caster, Spell) :-
    relation(Caster, knows_spell, Spell).

%% ── Slots ────────────────────────────────────────────────────────────────────

slot_attr(1, slots_l1, slots_l1_used).
slot_attr(2, slots_l2, slots_l2_used).
slot_attr(3, slots_l3, slots_l3_used).
slot_attr(4, slots_l4, slots_l4_used).
slot_attr(5, slots_l5, slots_l5_used).

spell_slots_total(Caster, SlotLevel, N) :-
    slot_attr(SlotLevel, Attr, _),
    attribute(Caster, Attr, N).

spell_slots_expended(Caster, SlotLevel, N) :-
    slot_attr(SlotLevel, _, UsedAttr),
    (   attribute(Caster, UsedAttr, N)
    ->  true
    ;   N = 0
    ).

spell_slot_available(Caster, SlotLevel) :-
    spell_slots_total(Caster, SlotLevel, Total),
    spell_slots_expended(Caster, SlotLevel, Used),
    Used < Total.

%% ── The Casting Gate ─────────────────────────────────────────────────────────
%%
%% d20_can_cast(Caster, Spell, SlotLevel):
%%   cantrips cast at SlotLevel 0, always free;
%%   levelled spells need a free slot at their level or higher (upcasting).

d20_can_cast(Caster, Spell, 0) :-
    d20_spell(Spell, 0, _),
    !,
    spell_known(Caster, Spell).
d20_can_cast(Caster, Spell, SlotLevel) :-
    d20_spell(Spell, Level, _),
    Level >= 1,
    spell_known(Caster, Spell),
    slot_attr(SlotLevel, _, _),
    SlotLevel >= Level,
    spell_slot_available(Caster, SlotLevel).

spell_castable(Caster, Spell) :-
    d20_can_cast(Caster, Spell, _),
    !.

%% ── Damage Scaling ───────────────────────────────────────────────────────────
%%
%% Cantrips scale with CASTER level (SRD tiers: 1 / 5 / 11 / 17); levelled
%% spells scale with the SLOT they are cast from.

cantrip_multiplier(CasterLevel, 4) :- CasterLevel >= 17, !.
cantrip_multiplier(CasterLevel, 3) :- CasterLevel >= 11, !.
cantrip_multiplier(CasterLevel, 2) :- CasterLevel >= 5, !.
cantrip_multiplier(_, 1).

spell_effective_dice(Spell, CasterLevel, 0, NDice, Faces) :-
    d20_spell(Spell, 0, _),
    !,
    spell_damage(Spell, Base, Faces),
    cantrip_multiplier(CasterLevel, M),
    NDice is Base * M.
spell_effective_dice(Spell, _, SlotLevel, NDice, Faces) :-
    d20_spell(Spell, Level, _),
    Level >= 1,
    spell_damage(Spell, Base, Faces),
    (   spell_upcast_dice(Spell, PerSlot)
    ->  true
    ;   PerSlot = 0
    ),
    Extra is max(0, SlotLevel - Level) * PerSlot,
    NDice is Base + Extra.

spell_heal_profile(Spell, SlotLevel, NDice, Faces) :-
    spell_heal(Spell, Base, Faces),
    d20_spell(Spell, Level, _),
    (   spell_upcast_heal(Spell, PerSlot)
    ->  true
    ;   PerSlot = 0
    ),
    Extra is max(0, SlotLevel - Level) * PerSlot,
    NDice is Base + Extra.

%% ── Save Resolution ──────────────────────────────────────────────────────────
%%
%% The application rolls the die; the cell owns the DC, the modifier, and the
%% ruling — same division of labour as d20_check/4 in d20-core.

d20_spell_save(Caster, Target, Spell, Roll, Outcome) :-
    spell_save(Spell, Ability, _),
    spell_save_dc(Caster, DC),
    saving_throw_modifier(Target, Ability, Mod),
    Total is Roll + Mod,
    (   Total >= DC
    ->  Outcome = save_success
    ;   Outcome = save_failure
    ).

%% ── Concentration ────────────────────────────────────────────────────────────

d20_concentration_dc(Damage, DC) :-
    Half is Damage // 2,
    (   Half > 10
    ->  DC = Half
    ;   DC = 10
    ).

d20_concentration_check(Entity, Damage, Roll, Outcome) :-
    d20_concentration_dc(Damage, DC),
    saving_throw_modifier(Entity, con, Mod),
    Total is Roll + Mod,
    (   Total >= DC
    ->  Outcome = holds
    ;   Outcome = broken
    ).
