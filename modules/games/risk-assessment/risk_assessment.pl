%% Tether Module: risk-assessment v1.0.0
%% Requires: combat
%% Exports: survival_probability/4, recommended_action/3,
%%          kills_to_exhaust/4, fight_outcome_summary/5

tether_module('risk-assessment', '1.0.0', auto).

tether_export('risk-assessment', 'survival_probability/4',
    'survival_probability(Player, Enemy, HP, P) — P is probability (0.0–1.0) Player survives a fight, HP is remaining health').
tether_export('risk-assessment', 'recommended_action/3',
    'recommended_action(Player, Enemy, Action) — Action is fight or flee based on survival probability').
tether_export('risk-assessment', 'kills_to_exhaust/4',
    'kills_to_exhaust(Player, Enemy, MaxHP, N) — N is expected kills before Player HP drops to 0').
tether_export('risk-assessment', 'fight_outcome_summary/5',
    'fight_outcome_summary(Player, Enemy, TurnsToKill, DamageTaken, P) — full breakdown of a combat encounter').

%% ── Survival probability ───────────────────────────────────────────────────
%% Requires combat battery in the same namespace.
%% Assert: { type:"attribute", entity:"player", attribute:"hp", value:80 }
%%         { type:"attribute", entity:"goblin", attribute:"hp", value:30 }
%%         { type:"attribute", entity:"goblin", attribute:"base_damage", value:10 }
%%         { type:"attribute", entity:"player", attribute:"base_damage", value:15 }

survival_probability(Player, Enemy, HPRemaining, P) :-
    attribute(Player, hp, PHP),
    attribute(Player, base_damage, PD),
    attribute(Enemy, hp, EHP),
    attribute(Enemy, base_damage, ED),
    PD > 0,
    TurnsToKill is ceiling(EHP / PD),
    DamageTaken is TurnsToKill * ED,
    HPRemaining is max(0, PHP - DamageTaken),
    (   DamageTaken >= PHP
    ->  P is max(0.05, 0.5 - (DamageTaken - PHP) / (PHP * 2.0))
    ;   P is min(0.99, 1.0 - (DamageTaken / PHP) * 0.5)
    ).

%% ── Fight recommendation ───────────────────────────────────────────────────

recommended_action(Player, Enemy, fight) :-
    survival_probability(Player, Enemy, _, P), P > 0.6.
recommended_action(Player, Enemy, flee) :-
    survival_probability(Player, Enemy, _, P), P =< 0.6.

%% ── Kills to HP exhaustion ─────────────────────────────────────────────────
%% How many of this enemy can Player defeat before dying?

kills_to_exhaust(Player, Enemy, MaxHP, N) :-
    attribute(Enemy, base_damage, ED),
    attribute(Player, base_damage, PD),
    attribute(Enemy, hp, EHP),
    ED > 0, PD > 0,
    TurnsPerKill is ceiling(EHP / PD),
    DamagePerKill is TurnsPerKill * ED,
    N is max(1, floor(MaxHP / DamagePerKill)).

%% ── Full encounter summary ─────────────────────────────────────────────────

fight_outcome_summary(Player, Enemy, TurnsToKill, DamageTaken, P) :-
    attribute(Player, base_damage, PD),
    attribute(Enemy, hp, EHP),
    attribute(Enemy, base_damage, ED),
    attribute(Player, hp, PHP),
    PD > 0,
    TurnsToKill is ceiling(EHP / PD),
    DamageTaken is TurnsToKill * ED,
    (   DamageTaken >= PHP
    ->  P is max(0.05, 0.5 - (DamageTaken - PHP) / (PHP * 2.0))
    ;   P is min(0.99, 1.0 - (DamageTaken / PHP) * 0.5)
    ).
