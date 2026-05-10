%% Tether Module: loyalty v1.0.0
%% Exports: loyalty_tier/2, points_balance/2, reward_eligible/2,
%%          points_to_redeem/3, tier_benefit/3

tether_module(loyalty, '1.0.0', auto).

tether_export(loyalty, 'loyalty_tier/2',      'loyalty_tier(Customer, Tier) — Tier is bronze/silver/gold/platinum based on lifetime points').
tether_export(loyalty, 'points_balance/2',    'points_balance(Customer, Points) — current redeemable points balance').
tether_export(loyalty, 'reward_eligible/2',   'reward_eligible(Customer, Reward) — Customer has enough points for Reward').
tether_export(loyalty, 'points_to_redeem/3',  'points_to_redeem(Customer, Reward, Points) — Points required to claim Reward, accounting for tier multiplier').
tether_export(loyalty, 'tier_benefit/3',      'tier_benefit(Customer, Benefit, Value) — a named benefit the Customer receives at their tier').

%% ── Loyalty Data Model ────────────────────────────────────────────────────────
%%
%% Customer points:
%%   attribute(customer_123, lifetime_points, 2500)   %% total ever earned
%%   attribute(customer_123, redeemed_points, 500)    %% total ever redeemed
%%
%% Tier thresholds (defaults; override with attribute(loyalty, ...)):
%%   attribute(loyalty, platinum_threshold, 5000)
%%   attribute(loyalty, gold_threshold,     2000)
%%   attribute(loyalty, silver_threshold,    500)
%%
%% Rewards catalog:
%%   attribute(free_coffee, points_cost, 100)
%%   attribute(free_shipping, points_cost, 200)
%%
%% Tier benefits:
%%   relation(gold,     has_benefit, early_access)
%%   attribute(early_access, benefit_value, true)
%%   relation(platinum, has_benefit, dedicated_support)
%%   attribute(dedicated_support, benefit_value, true)
%%
%% Tier redemption multipliers (fewer points needed at higher tiers):
%%   attribute(loyalty, platinum_redemption_multiplier, 0.7)
%%   attribute(loyalty, gold_redemption_multiplier,     0.85)
%%   attribute(loyalty, silver_redemption_multiplier,   1.0)

%% ── Tier thresholds ──────────────────────────────────────────────────────────

tier_threshold(platinum, T) :- attribute(loyalty, platinum_threshold, T), !.
tier_threshold(platinum, 5000).
tier_threshold(gold,     T) :- attribute(loyalty, gold_threshold, T), !.
tier_threshold(gold,     2000).
tier_threshold(silver,   T) :- attribute(loyalty, silver_threshold, T), !.
tier_threshold(silver,   500).

%% loyalty_tier(+Customer, -Tier)
loyalty_tier(Customer, platinum) :-
    attribute(Customer, lifetime_points, P),
    tier_threshold(platinum, T), P >= T, !.
loyalty_tier(Customer, gold) :-
    attribute(Customer, lifetime_points, P),
    tier_threshold(gold, T), P >= T, !.
loyalty_tier(Customer, silver) :-
    attribute(Customer, lifetime_points, P),
    tier_threshold(silver, T), P >= T, !.
loyalty_tier(_, bronze).

%% points_balance(+Customer, -Points)
points_balance(Customer, Balance) :-
    attribute(Customer, lifetime_points, Earned),
    ( attribute(Customer, redeemed_points, Redeemed) -> true ; Redeemed = 0 ),
    Balance is Earned - Redeemed.

%% ── Redemption multipliers ───────────────────────────────────────────────────

redemption_multiplier(platinum, M) :- attribute(loyalty, platinum_redemption_multiplier, M), !.
redemption_multiplier(platinum, 0.7).
redemption_multiplier(gold,     M) :- attribute(loyalty, gold_redemption_multiplier, M), !.
redemption_multiplier(gold,     0.85).
redemption_multiplier(silver,   M) :- attribute(loyalty, silver_redemption_multiplier, M), !.
redemption_multiplier(silver,   1.0).
redemption_multiplier(bronze,   1.0).

%% points_to_redeem(+Customer, +Reward, -Points)
points_to_redeem(Customer, Reward, Points) :-
    attribute(Reward, points_cost, BaseCost),
    loyalty_tier(Customer, Tier),
    redemption_multiplier(Tier, Mult),
    Points is ceiling(BaseCost * Mult).

%% reward_eligible(+Customer, +Reward)
reward_eligible(Customer, Reward) :-
    points_balance(Customer, Balance),
    points_to_redeem(Customer, Reward, Cost),
    Balance >= Cost.

%% tier_benefit(+Customer, +Benefit, -Value)
tier_benefit(Customer, Benefit, Value) :-
    loyalty_tier(Customer, Tier),
    ( relation(Tier, has_benefit, Benefit)
    ; ( relation(ParentTier, has_benefit, Benefit),
        tier_outranks(Tier, ParentTier) ) ),
    attribute(Benefit, benefit_value, Value).

tier_outranks(platinum, gold).
tier_outranks(platinum, silver).
tier_outranks(platinum, bronze).
tier_outranks(gold,     silver).
tier_outranks(gold,     bronze).
tier_outranks(silver,   bronze).
