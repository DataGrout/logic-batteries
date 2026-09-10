%% Battery: prob-detection v1.0.0
%% Requires: combat
%% Exports: detected/2, detection_probability/3, stealth_success/2,
%%          environmental_detection_factor/2

battery_module('prob-detection', '1.0.1', auto).

battery_export('prob-detection', 'detected/2',
    'detected(Guard, Player) — probabilistic: Guard detects Player based on perception and alert state').
battery_export('prob-detection', 'detection_probability/3',
    'detection_probability(Guard, Player, P) — P is the probability (0.0–1.0) Guard detects Player').
battery_export('prob-detection', 'stealth_success/2',
    'stealth_success(Guard, Player) — true when Player is NOT detected (complement of detected/2)').
battery_export('prob-detection', 'environmental_detection_factor/2',
    'environmental_detection_factor(Condition, Factor) — Factor (0.0–1.0) multiplied into detection probability').

%% ── Detection probability by perception tier and alert state ─────────────────
%% Requires combat battery (uses can_attack/2 to establish line-of-sight/range).
%%
%% Assert guard stats:
%%   attribute(guard_a, perception, 9)         %% 1–10 scale
%%   attribute(guard_a, alert_state, active)   %% active | passive
%%
%% Assert player equipment affecting stealth:
%%   relation(player, has_item, guard_uniform)
%%   attribute(player, stealth_bonus, 3)

%% Active, high-perception guard
0.95::detected(Guard, Player) :-
    can_attack(Guard, Player),
    attribute(Guard, perception, P), P > 8,
    attribute(Guard, alert_state, active).

%% Active, medium-perception guard
0.75::detected(Guard, Player) :-
    can_attack(Guard, Player),
    attribute(Guard, perception, P), P > 5, P =< 8,
    attribute(Guard, alert_state, active).

%% Active, low-perception guard
0.45::detected(Guard, Player) :-
    can_attack(Guard, Player),
    attribute(Guard, perception, P), P =< 5,
    attribute(Guard, alert_state, active).

%% Passive (unalerted) guard — base perception still applies
0.60::detected(Guard, Player) :-
    can_attack(Guard, Player),
    attribute(Guard, perception, P), P > 8,
    \+ attribute(Guard, alert_state, active).

0.35::detected(Guard, Player) :-
    can_attack(Guard, Player),
    attribute(Guard, perception, P), P > 5, P =< 8,
    \+ attribute(Guard, alert_state, active).

0.15::detected(Guard, Player) :-
    can_attack(Guard, Player),
    attribute(Guard, perception, P), P =< 5,
    \+ attribute(Guard, alert_state, active).

%% Disguise: player wearing a uniform that matches the guard's faction
0.10::detected(Guard, Player) :-
    attribute(Guard, faction, Faction),
    relation(Player, has_item, Uniform),
    attribute(Uniform, disguise_faction, Faction),
    \+ attribute(Guard, alert_state, active).

%% ── Deterministic probability accessor ─────────────────────────────────────
%% Returns a numeric probability without ProbLog inference.
%% Combines perception, alert state, and environmental factors.

detection_probability(Guard, Player, P) :-
    base_detection_probability(Guard, Player, Base),
    environmental_detection_factor(Guard, EnvFactor),
    stealth_factor(Player, StealthFactor),
    P is min(0.99, max(0.01, Base * EnvFactor * StealthFactor)).

%% One model. The base is the same tier table the annotated detected/2 clauses
%% carry, so a ProbLog marginal and this accessor start from the same number;
%% environment and stealth then multiply in. (An earlier version used
%% perception/10 × 1.3 here, which disagreed with the table.) A guard with no
%% perception score keeps the 0.3 passive / 0.5 active defaults.
base_detection_probability(Guard, Player, Base) :-
    ( attribute(Guard, alert_state, active) -> Active = true ; Active = false ),
    (   Active == false, disguised_for(Guard, Player)
    ->  Base = 0.10
    ;   attribute(Guard, perception, Perc)
    ->  perception_tier_base(Perc, Active, Base)
    ;   Active == true
    ->  Base = 0.5
    ;   Base = 0.3
    ).
perception_tier_base(P, true,  0.95) :- P > 8, !.
perception_tier_base(P, true,  0.75) :- P > 5, !.
perception_tier_base(_, true,  0.45).
perception_tier_base(P, false, 0.60) :- P > 8, !.
perception_tier_base(P, false, 0.35) :- P > 5, !.
perception_tier_base(_, false, 0.15).
%% The player holds an item whose disguise_faction matches the guard's faction.
disguised_for(Guard, Player) :-
    attribute(Guard, faction, Faction),
    relation(Player, has_item, Uniform),
    attribute(Uniform, disguise_faction, Faction).

%% ── Environmental factors ──────────────────────────────────────────────────
%% Assert world conditions:
%%   attribute(world, light_level, dark)     %% dark | dim | bright
%%   attribute(world, noise_level, loud)     %% silent | ambient | loud
%%   attribute(world, weather, rain)         %% rain reduces vision

environmental_detection_factor(_, Factor) :-
    findall(F, env_factor(F), Fs),
    env_product(Fs, 1.0, Factor).
%% Plain recursion rather than foldl with a yall lambda: `>>` is SWI-only.
env_product([], Acc, Acc).
env_product([F|Fs], Acc, Product) :-
    Acc1 is Acc * F,
    env_product(Fs, Acc1, Product).

env_factor(0.5) :- attribute(world, light_level, dark).
env_factor(0.75) :- attribute(world, light_level, dim).
env_factor(0.8) :- attribute(world, weather, rain).
env_factor(0.85) :- attribute(world, weather, fog).
env_factor(1.3) :- attribute(world, noise_level, loud).

%% ── Stealth factor ─────────────────────────────────────────────────────────
%% Player stealth_bonus reduces detection probability.
%%   attribute(player, stealth_bonus, 4)   %% 0–10 scale, reduces by ~4% per point

stealth_factor(Player, Factor) :-
    attribute(Player, stealth_bonus, Bonus),
    Factor is max(0.1, 1.0 - Bonus * 0.07).
stealth_factor(Player, 1.0) :-
    \+ attribute(Player, stealth_bonus, _).

%% ── Stealth success ─────────────────────────────────────────────────────────

stealth_success(Guard, Player) :-
    detection_probability(Guard, Player, P),
    P < 0.5.
