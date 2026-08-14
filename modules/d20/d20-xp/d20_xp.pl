%% Battery: d20-xp v1.0.0
%% SRD 5.1 (CC BY 4.0) — encounter building, XP by CR, difficulty thresholds.
%%
%% Exports: xp_for_cr/2, encounter_threshold/3, xp_multiplier/2,
%%          adjusted_xp/3, encounter_difficulty/4, party_encounter_difficulty/4

%% Input predicates — declared dynamic for standalone (consult) use;
%% DataGrout strips directives at cell install time.
:- dynamic(attribute/3).

battery_module('d20-xp', '1.0.0', auto).

battery_export('d20-xp', 'xp_for_cr/2',                 'xp_for_cr(CR, XP) — base XP for a monster of this CR').
battery_export('d20-xp', 'encounter_threshold/3',        'encounter_threshold(PartyLevel, Difficulty, XPPerPlayer) — threshold table').
battery_export('d20-xp', 'xp_multiplier/2',             'xp_multiplier(MonsterCount, Multiplier) — action-economy multiplier').
battery_export('d20-xp', 'adjusted_xp/3',               'adjusted_xp(XPList, AdjustedTotal, Multiplier) — total XP after multiplier').
battery_export('d20-xp', 'encounter_difficulty/4',       'encounter_difficulty(PartyLevel, PartySize, XPList, Difficulty) — trivial/easy/medium/hard/deadly').
battery_export('d20-xp', 'party_encounter_difficulty/4', 'party_encounter_difficulty(Level, Size, MonsterNames, Difficulty) — requires d20-monsters').

%% ── XP by CR ─────────────────────────────────────────────────────────────────
%% SRD 5.1 Table: Experience Points by Challenge Rating.
%% Fractional CRs are atoms: '1/8', '1/4', '1/2'.

xp_for_cr(0,      10).
xp_for_cr('1/8',  25).
xp_for_cr('1/4',  50).
xp_for_cr('1/2',  100).
xp_for_cr(1,      200).
xp_for_cr(2,      450).
xp_for_cr(3,      700).
xp_for_cr(4,      1100).
xp_for_cr(5,      1800).
xp_for_cr(6,      2300).
xp_for_cr(7,      2900).
xp_for_cr(8,      3900).
xp_for_cr(9,      5000).
xp_for_cr(10,     5900).
xp_for_cr(11,     7200).
xp_for_cr(12,     8400).
xp_for_cr(13,     10000).
xp_for_cr(14,     11500).
xp_for_cr(15,     13000).
xp_for_cr(16,     15000).
xp_for_cr(17,     18000).
xp_for_cr(18,     20000).
xp_for_cr(19,     22000).
xp_for_cr(20,     25000).
xp_for_cr(21,     33000).
xp_for_cr(22,     41000).
xp_for_cr(23,     50000).
xp_for_cr(24,     62000).
xp_for_cr(25,     75000).
xp_for_cr(26,     90000).
xp_for_cr(27,     105000).
xp_for_cr(28,     120000).
xp_for_cr(29,     135000).
xp_for_cr(30,     155000).

%% ── Encounter Difficulty Thresholds ──────────────────────────────────────────
%% SRD 5.1 Table: Encounter Difficulty Thresholds (XP per player character).
%% encounter_threshold(+PartyLevel, +Difficulty, -XPPerPlayer)

encounter_threshold(1,  easy,   25).   encounter_threshold(1,  medium,  50).
encounter_threshold(1,  hard,   75).   encounter_threshold(1,  deadly,  100).

encounter_threshold(2,  easy,   50).   encounter_threshold(2,  medium,  100).
encounter_threshold(2,  hard,   150).  encounter_threshold(2,  deadly,  200).

encounter_threshold(3,  easy,   75).   encounter_threshold(3,  medium,  150).
encounter_threshold(3,  hard,   225).  encounter_threshold(3,  deadly,  400).

encounter_threshold(4,  easy,   125).  encounter_threshold(4,  medium,  250).
encounter_threshold(4,  hard,   375).  encounter_threshold(4,  deadly,  500).

encounter_threshold(5,  easy,   250).  encounter_threshold(5,  medium,  500).
encounter_threshold(5,  hard,   750).  encounter_threshold(5,  deadly,  1100).

encounter_threshold(6,  easy,   300).  encounter_threshold(6,  medium,  600).
encounter_threshold(6,  hard,   900).  encounter_threshold(6,  deadly,  1400).

encounter_threshold(7,  easy,   350).  encounter_threshold(7,  medium,  750).
encounter_threshold(7,  hard,   1100). encounter_threshold(7,  deadly,  1700).

encounter_threshold(8,  easy,   450).  encounter_threshold(8,  medium,  900).
encounter_threshold(8,  hard,   1400). encounter_threshold(8,  deadly,  2100).

encounter_threshold(9,  easy,   550).  encounter_threshold(9,  medium,  1100).
encounter_threshold(9,  hard,   1600). encounter_threshold(9,  deadly,  2400).

encounter_threshold(10, easy,   600).  encounter_threshold(10, medium,  1200).
encounter_threshold(10, hard,   1900). encounter_threshold(10, deadly,  2800).

encounter_threshold(11, easy,   800).  encounter_threshold(11, medium,  1600).
encounter_threshold(11, hard,   2400). encounter_threshold(11, deadly,  3600).

encounter_threshold(12, easy,   1000). encounter_threshold(12, medium,  2000).
encounter_threshold(12, hard,   3000). encounter_threshold(12, deadly,  4500).

encounter_threshold(13, easy,   1100). encounter_threshold(13, medium,  2200).
encounter_threshold(13, hard,   3400). encounter_threshold(13, deadly,  5100).

encounter_threshold(14, easy,   1250). encounter_threshold(14, medium,  2500).
encounter_threshold(14, hard,   3800). encounter_threshold(14, deadly,  5700).

encounter_threshold(15, easy,   1400). encounter_threshold(15, medium,  2800).
encounter_threshold(15, hard,   4300). encounter_threshold(15, deadly,  6400).

encounter_threshold(16, easy,   1600). encounter_threshold(16, medium,  3200).
encounter_threshold(16, hard,   4800). encounter_threshold(16, deadly,  7200).

encounter_threshold(17, easy,   2000). encounter_threshold(17, medium,  3900).
encounter_threshold(17, hard,   5900). encounter_threshold(17, deadly,  8800).

encounter_threshold(18, easy,   2100). encounter_threshold(18, medium,  4200).
encounter_threshold(18, hard,   6300). encounter_threshold(18, deadly,  9500).

encounter_threshold(19, easy,   2400). encounter_threshold(19, medium,  4900).
encounter_threshold(19, hard,   7300). encounter_threshold(19, deadly,  10900).

encounter_threshold(20, easy,   2800). encounter_threshold(20, medium,  5700).
encounter_threshold(20, hard,   8500). encounter_threshold(20, deadly,  12700).

%% ── XP Multiplier ────────────────────────────────────────────────────────────
%% SRD 5.1: multiply total monster XP by this factor to account for action economy.
%% xp_multiplier(+MonsterCount, -Multiplier)

xp_multiplier(1,  1.0).
xp_multiplier(2,  1.5).
xp_multiplier(N,  2.0) :- N >= 3,  N =< 6.
xp_multiplier(N,  2.5) :- N >= 7,  N =< 10.
xp_multiplier(N,  3.0) :- N >= 11, N =< 14.
xp_multiplier(N,  4.0) :- N >= 15.

%% ── Adjusted XP ──────────────────────────────────────────────────────────────
%% adjusted_xp(+XPList, -AdjustedTotal, -Multiplier)
%% XPList: list of base XP values, one per monster.
%% AdjustedTotal: total after the action-economy multiplier.

xp_sum_([], 0).
xp_sum_([H|T], Sum) :- xp_sum_(T, Rest), Sum is H + Rest.

adjusted_xp(XPList, Adjusted, Mult) :-
    length(XPList, Count),
    xp_sum_(XPList, RawXP),
    xp_multiplier(Count, Mult),
    Adjusted is round(RawXP * Mult).

%% ── Encounter Difficulty ─────────────────────────────────────────────────────
%% encounter_difficulty(+PartyLevel, +PartySize, +XPList, -Difficulty)
%% XPList: list of base XP per monster (not pre-multiplied).
%% Difficulty: trivial | easy | medium | hard | deadly.

encounter_difficulty(PartyLevel, PartySize, XPList, Difficulty) :-
    adjusted_xp(XPList, AdjXP, _),
    XPPerPlayer is AdjXP / PartySize,
    encounter_threshold(PartyLevel, deadly, Deadly),
    encounter_threshold(PartyLevel, hard,   Hard),
    encounter_threshold(PartyLevel, medium, Medium),
    encounter_threshold(PartyLevel, easy,   Easy),
    ( XPPerPlayer >= Deadly  -> Difficulty = deadly
    ; XPPerPlayer >= Hard    -> Difficulty = hard
    ; XPPerPlayer >= Medium  -> Difficulty = medium
    ; XPPerPlayer >= Easy    -> Difficulty = easy
    ;                           Difficulty = trivial
    ).

%% ── Name-based Encounter Difficulty ─────────────────────────────────────────
%% Requires d20-monsters installed in the same namespace.
%% party_encounter_difficulty(+PartyLevel, +PartySize, +MonsterNames, -Difficulty)

party_encounter_difficulty(PartyLevel, PartySize, MonsterNames, Difficulty) :-
    maplist(monster_base_xp_, MonsterNames, XPList),
    encounter_difficulty(PartyLevel, PartySize, XPList, Difficulty).

monster_base_xp_(Name, XP) :-
    attribute(Name, xp, XP).
