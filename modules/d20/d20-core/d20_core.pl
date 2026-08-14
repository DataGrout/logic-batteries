%% Battery: d20-core v1.0.0
%% SRD 5.1 (CC BY 4.0) — ability scores, modifiers, proficiency, skills, saving throws.
%%
%% Exports: ability_modifier/2, proficiency_bonus/2, skill_modifier/3,
%%          saving_throw_modifier/3, passive_perception/2, spell_save_dc/2,
%%          attack_bonus/3, d20_check/4, d20_save/4

%% Input predicates — declared dynamic for standalone (consult) use;
%% DataGrout strips directives at cell install time.
:- dynamic(attribute/3).

battery_module('d20-core', '1.0.0', auto).

battery_export('d20-core', 'ability_modifier/2',     'ability_modifier(Score, Mod) — floor((Score-10)/2)').
battery_export('d20-core', 'proficiency_bonus/2',    'proficiency_bonus(Level, PB) — PB for a given level (2 at L1, scales up every 4 levels)').
battery_export('d20-core', 'skill_modifier/3',       'skill_modifier(Entity, Skill, Mod) — total modifier including proficiency/expertise').
battery_export('d20-core', 'saving_throw_modifier/3','saving_throw_modifier(Entity, Ability, Mod) — save modifier with proficiency if marked').
battery_export('d20-core', 'passive_perception/2',   'passive_perception(Entity, PP) — 10 + Perception modifier').
battery_export('d20-core', 'spell_save_dc/2',        'spell_save_dc(Entity, DC) — 8 + PB + spellcasting ability modifier').
battery_export('d20-core', 'attack_bonus/3',         'attack_bonus(Entity, AttackType, Bonus) — melee/ranged/spell attack bonus').
battery_export('d20-core', 'd20_check/4',            'd20_check(Entity, Skill, Roll, DC) — skill check: Roll + skill modifier meets DC').
battery_export('d20-core', 'd20_save/4',             'd20_save(Entity, Ability, Roll, DC) — saving throw: Roll + save modifier meets DC').
battery_export('d20-core', 'd20_contest/7',          'd20_contest(A, SkillA, RollA, B, SkillB, RollB, Outcome) — opposed check: a_wins | b_wins | tie').

%% ── Ability Scores ───────────────────────────────────────────────────────────
%%
%% Assert the six ability scores as attributes:
%%   attribute(fighter, str, 18)
%%   attribute(fighter, dex, 14)
%%   attribute(fighter, con, 16)
%%   attribute(fighter, int,  8)
%%   attribute(fighter, wis, 12)
%%   attribute(fighter, cha, 10)

%% div (floored division), NOT (//)/2: ISO // truncates toward zero, which
%% breaks odd scores below 10 — score 7 must be -2 (floor(-1.5)), not -1.
ability_modifier(Score, Mod) :-
    Mod is (Score - 10) div 2.

entity_ability_mod(Entity, Ability, Mod) :-
    attribute(Entity, Ability, Score),
    ability_modifier(Score, Mod), !.
entity_ability_mod(_, _, 0).

%% ── Proficiency Bonus ────────────────────────────────────────────────────────
%%
%% SRD 5.1: PB = 2 at levels 1–4, +1 every 4 levels thereafter.
%% Assert level:  attribute(fighter, level, 5)
%% Monsters use CR-equivalent level or assert directly.

proficiency_bonus(Level, PB) :-
    PB is max(2, 2 + ((Level - 1) // 4)).

entity_proficiency_bonus(Entity, PB) :-
    ( attribute(Entity, level, Level) -> true ; Level = 1 ),
    proficiency_bonus(Level, PB).

%% ── Skills ───────────────────────────────────────────────────────────────────
%%
%% Skill → governing ability (SRD 5.1 complete list).
skill_ability(acrobatics,      dex).
skill_ability(animal_handling, wis).
skill_ability(arcana,          int).
skill_ability(athletics,       str).
skill_ability(deception,       cha).
skill_ability(history,         int).
skill_ability(insight,         wis).
skill_ability(intimidation,    cha).
skill_ability(investigation,   int).
skill_ability(medicine,        wis).
skill_ability(nature,          int).
skill_ability(perception,      wis).
skill_ability(performance,     cha).
skill_ability(persuasion,      cha).
skill_ability(religion,        int).
skill_ability(sleight_of_hand, dex).
skill_ability(stealth,         dex).
skill_ability(survival,        wis).

%% Proficiency:  attribute(ranger, proficient_stealth, true)
%% Expertise:    attribute(rogue,  expertise_stealth, true)   (double PB)
%%
%% skill_modifier(+Entity, +Skill, -Mod)

%% Explicit override first: attribute(goblin, skill_stealth, 6) beats the
%% derived value (stat-block skills bake in bonuses derivation can't know).
skill_modifier(Entity, Skill, Mod) :-
    atom_concat(skill_, Skill, SkillAttr),
    attribute(Entity, SkillAttr, Mod), !.

skill_modifier(Entity, Skill, Mod) :-
    skill_ability(Skill, Ability),
    entity_ability_mod(Entity, Ability, AbilMod),
    entity_proficiency_bonus(Entity, PB),
    atom_concat(proficient_, Skill, ProfAttr),
    atom_concat(expertise_,  Skill, ExpAttr),
    ( attribute(Entity, ExpAttr, true)  -> ProfMod is PB * 2
    ; attribute(Entity, ProfAttr, true) -> ProfMod is PB
    ;                                      ProfMod = 0
    ),
    Mod is AbilMod + ProfMod.

passive_perception(Entity, PP) :-
    skill_modifier(Entity, perception, Mod),
    PP is 10 + Mod.

%% ── Saving Throws ────────────────────────────────────────────────────────────
%%
%% Proficiency: attribute(fighter, save_str, true)
%%              attribute(fighter, save_con, true)
%%
%% saving_throw_modifier(+Entity, +Ability, -Mod)

saving_throw_modifier(Entity, Ability, Mod) :-
    entity_ability_mod(Entity, Ability, AbilMod),
    entity_proficiency_bonus(Entity, PB),
    atom_concat(save_, Ability, SaveAttr),
    ( attribute(Entity, SaveAttr, true) -> ProfMod = PB ; ProfMod = 0 ),
    Mod is AbilMod + ProfMod.

%% ── Spell Save DC ────────────────────────────────────────────────────────────
%%
%% Declare spellcasting ability:
%%   attribute(wizard, spellcasting_ability, int)

spell_save_dc(Entity, DC) :-
    attribute(Entity, spellcasting_ability, Ability),
    entity_ability_mod(Entity, Ability, AbilMod),
    entity_proficiency_bonus(Entity, PB),
    DC is 8 + PB + AbilMod.

%% ── Attack Bonus ─────────────────────────────────────────────────────────────
%%
%% attack_bonus(+Entity, +AttackType, -Bonus)
%% AttackType: melee | ranged | spell
%%
%% Declare which ability governs weapon attacks:
%%   attribute(fighter, attack_ability, str)
%%   attribute(fighter, proficient_attack, true)
%%
%% Finesse (rogue/ranger with rapier — pick best of STR/DEX):
%%   attribute(rogue, finesse_attack, true)

%% Explicit override first: stat blocks assert attribute(E, attack_bonus, N)
%% (proficiency and weapon specifics baked in), which beats derivation for
%% every attack type.
attack_bonus(Entity, _AttackType, Bonus) :-
    attribute(Entity, attack_bonus, Bonus), !.

attack_bonus(Entity, melee, Bonus) :-
    ( attribute(Entity, finesse_attack, true)
      -> entity_ability_mod(Entity, str, StrMod),
         entity_ability_mod(Entity, dex, DexMod),
         AbilMod is max(StrMod, DexMod)
      ;  ( attribute(Entity, attack_ability, Ability) -> true ; Ability = str ),
         entity_ability_mod(Entity, Ability, AbilMod)
    ),
    entity_proficiency_bonus(Entity, PB),
    ( attribute(Entity, proficient_attack, true) -> ProfMod = PB ; ProfMod = 0 ),
    Bonus is AbilMod + ProfMod.

attack_bonus(Entity, ranged, Bonus) :-
    ( attribute(Entity, attack_ability, Ability) -> true ; Ability = dex ),
    entity_ability_mod(Entity, Ability, AbilMod),
    entity_proficiency_bonus(Entity, PB),
    ( attribute(Entity, proficient_attack, true) -> ProfMod = PB ; ProfMod = 0 ),
    Bonus is AbilMod + ProfMod.

attack_bonus(Entity, spell, Bonus) :-
    attribute(Entity, spellcasting_ability, Ability),
    entity_ability_mod(Entity, Ability, AbilMod),
    entity_proficiency_bonus(Entity, PB),
    Bonus is AbilMod + PB.

%% ── Checks and Saves ─────────────────────────────────────────────────────────
%%
%% The caller supplies the d20 roll — the logic cell is stateless.
%%
%% d20_check(+Entity, +Skill, +Roll, +DC)   — ability (skill) check vs a DC
%% d20_save(+Entity, +Ability, +Roll, +DC)  — saving throw vs a DC
%%
%% Auto-fail interactions (e.g. paralyzed auto-fails STR/DEX saves) live in
%% d20-conditions as condition_effect(C, auto_fail_save, Abilities); consult
%% those before rolling when conditions are in play.

d20_check(Entity, Skill, Roll, DC) :-
    skill_modifier(Entity, Skill, Mod),
    Roll + Mod >= DC.

d20_save(Entity, Ability, Roll, DC) :-
    saving_throw_modifier(Entity, Ability, Mod),
    Roll + Mod >= DC.

%% ── Contests ─────────────────────────────────────────────────────────────────
%%
%% Opposed checks (grapple: athletics vs athletics-or-acrobatics; shove; hide
%% vs perception). RAW: on a tie, the situation does not change — the caller
%% interprets `tie` accordingly (e.g. a grapple attempt fails on a tie).

d20_contest(A, SkillA, RollA, B, SkillB, RollB, Outcome) :-
    skill_modifier(A, SkillA, ModA),
    skill_modifier(B, SkillB, ModB),
    TotalA is RollA + ModA,
    TotalB is RollB + ModB,
    ( TotalA > TotalB -> Outcome = a_wins
    ; TotalB > TotalA -> Outcome = b_wins
    ;                    Outcome = tie
    ).
