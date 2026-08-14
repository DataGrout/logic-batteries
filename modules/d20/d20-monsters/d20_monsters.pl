%% Battery: d20-monsters v1.0.0
%% SRD 5.1 (CC BY 4.0) — stat blocks as attribute facts.
%% All stat blocks are from the SRD 5.1 published under CC BY 4.0.
%%
%% Exports: monster_cr/2, monster_type/2, monster_xp/2, srd_monster/1
%%
%% Override any attribute to customise for your campaign:
%%   attribute(skeleton, hp, 20)   — beefier skeleton

%% Input predicates — declared dynamic for standalone (consult) use;
%% DataGrout strips directives at cell install time.
:- dynamic(attribute/3).

battery_module('d20-monsters', '1.0.0', auto).

battery_export('d20-monsters', 'monster_cr/2',   'monster_cr(Name, CR) — CR as an atom (0, 1/8, 1/4, 1/2) or integer').
battery_export('d20-monsters', 'monster_type/2', 'monster_type(Name, Type) — undead/humanoid/beast/construct/giant/etc').
battery_export('d20-monsters', 'monster_xp/2',   'monster_xp(Name, XP) — base XP award for defeating this monster').
battery_export('d20-monsters', 'srd_monster/1',  'srd_monster(Name) — true for SRD stat blocks (vs custom assertions)').
battery_export('d20-monsters', 'd20_monster_attack/5', 'd20_monster_attack(Name, AttackBonus, DamageDice, DamageBonus, DamageType) — primary attack profile; the client rolls DamageDice').

monster_cr(Name, CR)   :- attribute(Name, cr, CR).
monster_type(Name, T)  :- attribute(Name, monster_type, T).
monster_xp(Name, XP)   :- attribute(Name, xp, XP).
srd_monster(Name)      :- attribute(Name, srd, true).

%% ══════════════════════════════════════════════════════════════════════════════
%% CR 0
%% ══════════════════════════════════════════════════════════════════════════════

attribute(commoner, srd, true).
attribute(commoner, cr, 0).
attribute(commoner, xp, 10).
attribute(commoner, monster_type, humanoid).
attribute(commoner, ac, 10).
attribute(commoner, hp, 4).
attribute(commoner, str, 10).
attribute(commoner, dex, 10).
attribute(commoner, con, 10).
attribute(commoner, int, 10).
attribute(commoner, wis, 10).
attribute(commoner, cha, 10).
attribute(commoner, speed, 30).

%% ══════════════════════════════════════════════════════════════════════════════
%% CR 1/8
%% ══════════════════════════════════════════════════════════════════════════════

attribute(bandit, srd, true).
attribute(bandit, cr, '1/8').
attribute(bandit, xp, 25).
attribute(bandit, monster_type, humanoid).
attribute(bandit, ac, 12).
attribute(bandit, hp, 11).
attribute(bandit, str, 11).
attribute(bandit, dex, 12).
attribute(bandit, con, 12).
attribute(bandit, int, 10).
attribute(bandit, wis, 10).
attribute(bandit, cha, 10).
attribute(bandit, speed, 30).
attribute(bandit, damage_type, slashing).

attribute(guard, srd, true).
attribute(guard, cr, '1/8').
attribute(guard, xp, 25).
attribute(guard, monster_type, humanoid).
attribute(guard, ac, 16).
attribute(guard, hp, 11).
attribute(guard, str, 13).
attribute(guard, dex, 12).
attribute(guard, con, 12).
attribute(guard, int, 10).
attribute(guard, wis, 11).
attribute(guard, cha, 10).
attribute(guard, speed, 30).
attribute(guard, damage_type, piercing).

%% ══════════════════════════════════════════════════════════════════════════════
%% CR 1/4
%% ══════════════════════════════════════════════════════════════════════════════

attribute(goblin, srd, true).
attribute(goblin, cr, '1/4').
attribute(goblin, xp, 50).
attribute(goblin, monster_type, humanoid).
attribute(goblin, ac, 15).
attribute(goblin, hp, 7).
attribute(goblin, str, 8).
attribute(goblin, dex, 14).
attribute(goblin, con, 10).
attribute(goblin, int, 10).
attribute(goblin, wis, 8).
attribute(goblin, cha, 8).
attribute(goblin, speed, 30).
attribute(goblin, damage_type, slashing).

attribute(skeleton, srd, true).
attribute(skeleton, cr, '1/4').
attribute(skeleton, xp, 50).
attribute(skeleton, monster_type, undead).
attribute(skeleton, ac, 13).
attribute(skeleton, hp, 13).
attribute(skeleton, str, 10).
attribute(skeleton, dex, 14).
attribute(skeleton, con, 15).
attribute(skeleton, int, 6).
attribute(skeleton, wis, 8).
attribute(skeleton, cha, 5).
attribute(skeleton, speed, 30).
attribute(skeleton, damage_type, piercing).
attribute(skeleton, immune_poison, true).
attribute(skeleton, immune_exhaustion, true).
attribute(skeleton, vulnerable_bludgeoning, true).

attribute(zombie, srd, true).
attribute(zombie, cr, '1/4').
attribute(zombie, xp, 50).
attribute(zombie, monster_type, undead).
attribute(zombie, ac, 8).
attribute(zombie, hp, 22).
attribute(zombie, str, 13).
attribute(zombie, dex, 6).
attribute(zombie, con, 16).
attribute(zombie, int, 3).
attribute(zombie, wis, 6).
attribute(zombie, cha, 5).
attribute(zombie, speed, 20).
attribute(zombie, damage_type, bludgeoning).
attribute(zombie, immune_poison, true).
attribute(zombie, immune_exhaustion, true).

%% ══════════════════════════════════════════════════════════════════════════════
%% CR 1/2
%% ══════════════════════════════════════════════════════════════════════════════

attribute(orc, srd, true).
attribute(orc, cr, '1/2').
attribute(orc, xp, 100).
attribute(orc, monster_type, humanoid).
attribute(orc, ac, 13).
attribute(orc, hp, 15).
attribute(orc, str, 16).
attribute(orc, dex, 12).
attribute(orc, con, 16).
attribute(orc, int, 7).
attribute(orc, wis, 11).
attribute(orc, cha, 10).
attribute(orc, speed, 30).
attribute(orc, damage_type, slashing).

attribute(shadow, srd, true).
attribute(shadow, cr, '1/2').
attribute(shadow, xp, 100).
attribute(shadow, monster_type, undead).
attribute(shadow, ac, 12).
attribute(shadow, hp, 16).
attribute(shadow, str, 6).
attribute(shadow, dex, 14).
attribute(shadow, con, 13).
attribute(shadow, int, 6).
attribute(shadow, wis, 10).
attribute(shadow, cha, 8).
attribute(shadow, speed, 40).
attribute(shadow, damage_type, necrotic).
attribute(shadow, resist_acid, true).
attribute(shadow, resist_fire, true).
attribute(shadow, resist_lightning, true).
attribute(shadow, resist_thunder, true).
attribute(shadow, resist_physical, true).  %% catches slashing/piercing/bludgeoning via d20_damage_category
attribute(shadow, immune_cold, true).
attribute(shadow, immune_necrotic, true).
attribute(shadow, immune_poison, true).
attribute(shadow, immune_exhaustion, true).

%% ══════════════════════════════════════════════════════════════════════════════
%% CR 1
%% ══════════════════════════════════════════════════════════════════════════════

attribute(ghoul, srd, true).
attribute(ghoul, cr, 1).
attribute(ghoul, xp, 200).
attribute(ghoul, monster_type, undead).
attribute(ghoul, ac, 12).
attribute(ghoul, hp, 22).
attribute(ghoul, str, 13).
attribute(ghoul, dex, 15).
attribute(ghoul, con, 10).
attribute(ghoul, int, 7).
attribute(ghoul, wis, 10).
attribute(ghoul, cha, 6).
attribute(ghoul, speed, 30).
attribute(ghoul, damage_type, piercing).
attribute(ghoul, immune_poison, true).
attribute(ghoul, immune_charmed, true).
attribute(ghoul, immune_exhaustion, true).

attribute(giant_spider, srd, true).
attribute(giant_spider, cr, 1).
attribute(giant_spider, xp, 200).
attribute(giant_spider, monster_type, beast).
attribute(giant_spider, ac, 14).
attribute(giant_spider, hp, 26).
attribute(giant_spider, str, 14).
attribute(giant_spider, dex, 16).
attribute(giant_spider, con, 12).
attribute(giant_spider, int, 2).
attribute(giant_spider, wis, 11).
attribute(giant_spider, cha, 4).
attribute(giant_spider, speed, 30).
attribute(giant_spider, damage_type, piercing).

%% ══════════════════════════════════════════════════════════════════════════════
%% CR 2
%% ══════════════════════════════════════════════════════════════════════════════

attribute(ogre, srd, true).
attribute(ogre, cr, 2).
attribute(ogre, xp, 450).
attribute(ogre, monster_type, giant).
attribute(ogre, ac, 11).
attribute(ogre, hp, 59).
attribute(ogre, str, 19).
attribute(ogre, dex, 8).
attribute(ogre, con, 16).
attribute(ogre, int, 5).
attribute(ogre, wis, 7).
attribute(ogre, cha, 7).
attribute(ogre, speed, 40).
attribute(ogre, damage_type, bludgeoning).

%% ══════════════════════════════════════════════════════════════════════════════
%% CR 3
%% ══════════════════════════════════════════════════════════════════════════════

attribute(manticore, srd, true).
attribute(manticore, cr, 3).
attribute(manticore, xp, 700).
attribute(manticore, monster_type, monstrosity).
attribute(manticore, ac, 14).
attribute(manticore, hp, 68).
attribute(manticore, str, 17).
attribute(manticore, dex, 16).
attribute(manticore, con, 17).
attribute(manticore, int, 7).
attribute(manticore, wis, 12).
attribute(manticore, cha, 8).
attribute(manticore, speed, 30).
attribute(manticore, damage_type, piercing).

attribute(minotaur, srd, true).
attribute(minotaur, cr, 3).
attribute(minotaur, xp, 700).
attribute(minotaur, monster_type, monstrosity).
attribute(minotaur, ac, 14).
attribute(minotaur, hp, 76).
attribute(minotaur, str, 18).
attribute(minotaur, dex, 11).
attribute(minotaur, con, 16).
attribute(minotaur, int, 6).
attribute(minotaur, wis, 16).
attribute(minotaur, cha, 9).
attribute(minotaur, speed, 40).
attribute(minotaur, damage_type, piercing).

%% ══════════════════════════════════════════════════════════════════════════════
%% CR 5
%% ══════════════════════════════════════════════════════════════════════════════

attribute(troll, srd, true).
attribute(troll, cr, 5).
attribute(troll, xp, 1800).
attribute(troll, monster_type, giant).
attribute(troll, ac, 15).
attribute(troll, hp, 84).
attribute(troll, str, 18).
attribute(troll, dex, 13).
attribute(troll, con, 20).
attribute(troll, int, 7).
attribute(troll, wis, 9).
attribute(troll, cha, 7).
attribute(troll, speed, 30).
attribute(troll, damage_type, slashing).
attribute(troll, vulnerable_fire, true).
attribute(troll, vulnerable_acid, true).

%% ══════════════════════════════════════════════════════════════════════════════
%% CR 10
%% ══════════════════════════════════════════════════════════════════════════════

attribute(stone_golem, srd, true).
attribute(stone_golem, cr, 10).
attribute(stone_golem, xp, 5900).
attribute(stone_golem, monster_type, construct).
attribute(stone_golem, ac, 17).
attribute(stone_golem, hp, 178).
attribute(stone_golem, str, 22).
attribute(stone_golem, dex, 9).
attribute(stone_golem, con, 20).
attribute(stone_golem, int, 3).
attribute(stone_golem, wis, 11).
attribute(stone_golem, cha, 1).
attribute(stone_golem, speed, 30).
attribute(stone_golem, damage_type, bludgeoning).
attribute(stone_golem, immune_poison, true).
attribute(stone_golem, immune_psychic, true).
%% SRD: immune to nonmagical bludgeoning/piercing/slashing.
%% resist_physical catches all three via d20_damage_category in d20-combat.
attribute(stone_golem, immune_physical, true).

%% ══════════════════════════════════════════════════════════════════════════════
%% CR 13
%% ══════════════════════════════════════════════════════════════════════════════

attribute(vampire, srd, true).
attribute(vampire, cr, 13).
attribute(vampire, xp, 10000).
attribute(vampire, monster_type, undead).
attribute(vampire, ac, 16).
attribute(vampire, hp, 144).
attribute(vampire, str, 18).
attribute(vampire, dex, 18).
attribute(vampire, con, 18).
attribute(vampire, int, 17).
attribute(vampire, wis, 15).
attribute(vampire, cha, 18).
attribute(vampire, speed, 30).
attribute(vampire, damage_type, piercing).
attribute(vampire, resist_necrotic, true).
attribute(vampire, resist_physical, true).

%% ── Attack Profiles (SRD 5.1 primary attacks) ────────────────────────────────
%%
%% attack_bonus / damage_bonus are EXPLICIT OVERRIDES — d20-core's attack_bonus/3
%% and d20-combat's d20_damage/4 prefer them over ability-derived math, because
%% monster attack numbers bake in proficiency and weapon specifics the derived
%% path can't know. attacks_per_action > 1 encodes Multiattack.
%% The client rolls damage_dice; the cell supplies everything else.

attribute(commoner, attack_bonus, 2).
attribute(commoner, damage_dice, '1d4').
attribute(commoner, damage_bonus, 0).

attribute(bandit, attack_bonus, 3).
attribute(bandit, damage_dice, '1d6').
attribute(bandit, damage_bonus, 1).

attribute(guard, attack_bonus, 3).
attribute(guard, damage_dice, '1d6').
attribute(guard, damage_bonus, 1).

attribute(goblin, attack_bonus, 4).
attribute(goblin, damage_dice, '1d6').
attribute(goblin, damage_bonus, 2).
attribute(goblin, skill_stealth, 6).         %% SRD: Stealth +6

attribute(skeleton, attack_bonus, 4).
attribute(skeleton, damage_dice, '1d6').
attribute(skeleton, damage_bonus, 2).

attribute(zombie, attack_bonus, 3).
attribute(zombie, damage_dice, '1d6').
attribute(zombie, damage_bonus, 1).

attribute(orc, attack_bonus, 5).
attribute(orc, damage_dice, '1d12').
attribute(orc, damage_bonus, 3).

attribute(shadow, attack_bonus, 4).
attribute(shadow, damage_dice, '2d6').
attribute(shadow, damage_bonus, 2).

attribute(ghoul, attack_bonus, 4).
attribute(ghoul, damage_dice, '2d4').
attribute(ghoul, damage_bonus, 2).
attribute(ghoul, damage_type_override_note, claws).

attribute(giant_spider, attack_bonus, 5).
attribute(giant_spider, damage_dice, '1d8'). attribute(giant_spider, damage_bonus, 3).

attribute(ogre, attack_bonus, 6).
attribute(ogre, damage_dice, '2d8').
attribute(ogre, damage_bonus, 4).

attribute(manticore, attack_bonus, 5).
attribute(manticore, damage_dice, '1d8').
attribute(manticore, damage_bonus, 3).
attribute(manticore, attacks_per_action, 3).

attribute(minotaur, attack_bonus, 6).
attribute(minotaur, damage_dice, '2d12').
attribute(minotaur, damage_bonus, 4).

attribute(troll, attack_bonus, 7).
attribute(troll, damage_dice, '2d6').
attribute(troll, damage_bonus, 4).
attribute(troll, attacks_per_action, 3).

attribute(stone_golem, attack_bonus, 10).
attribute(stone_golem, damage_dice, '3d8').
attribute(stone_golem, damage_bonus, 6).
attribute(stone_golem, attacks_per_action, 2).

attribute(vampire, attack_bonus, 9).
attribute(vampire, damage_dice, '1d8').
attribute(vampire, damage_bonus, 4).
attribute(vampire, attacks_per_action, 2).

%% d20_monster_attack(+Name, -AttackBonus, -DamageDice, -DamageBonus, -DamageType)
d20_monster_attack(Name, AB, Dice, DB, DType) :-
    attribute(Name, attack_bonus, AB),
    attribute(Name, damage_dice, Dice),
    attribute(Name, damage_bonus, DB),
    ( attribute(Name, damage_type, DType) -> true ; DType = bludgeoning ).
