%% Battery: loyalty v1.0.0
%% Exports: loyalty_tier/2, points_balance/2, reward_eligible/2,
%%          points_to_redeem/3, tier_benefit/3

battery_module(loyalty, '1.0.0', auto).

battery_export(loyalty, 'loyalty_tier/2',      'loyalty_tier(Customer, Tier) — Tier is bronze/silver/gold/platinum based on lifetime points').
battery_export(loyalty, 'points_balance/2',    'points_balance(Customer, Points) — current redeemable points balance').
battery_export(loyalty, 'reward_eligible/2',   'reward_eligible(Customer, Reward) — Customer has enough points for Reward').
battery_export(loyalty, 'points_to_redeem/3',  'points_to_redeem(Customer, Reward, Points) — Points required to claim Reward, accounting for tier multiplier').
battery_export(loyalty, 'tier_benefit/3',      'tier_benefit(Customer, Benefit, Value) — a named benefit the Customer receives at their tier').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). A customer is
%% anything with lifetime points, a reward anything with a points cost. Tiers
%% are the literal subjects platinum, gold, silver and bronze; thresholds and
%% multipliers live on the fixed subject `loyalty` and all have defaults.

battery_input(loyalty, customer, attribute(lifetime_points), integer, key,
    'Points ever earned: sets the tier and is the base of the balance.').
battery_input(loyalty, customer, attribute(redeemed_points), integer, default(0),
    'Points ever redeemed, subtracted from lifetime_points for the balance.').
battery_input(loyalty, reward, attribute(points_cost), integer, key,
    'Points the reward costs before the tier''s redemption multiplier.').
battery_input(loyalty, tier, relation(has_benefit), ref(benefit), key,
    'A benefit granted at this tier (platinum, gold, silver or bronze) and every tier above it.').
battery_input(loyalty, benefit, attribute(benefit_value), atom, key,
    'What tier_benefit returns for this benefit, as given (true, or a level such as priority).').
battery_input(loyalty, fixed(loyalty), attribute(platinum_threshold), integer, default(5000),
    'Lifetime points at which a customer is platinum.').
battery_input(loyalty, fixed(loyalty), attribute(gold_threshold), integer, default(2000),
    'Lifetime points at which a customer is gold.').
battery_input(loyalty, fixed(loyalty), attribute(silver_threshold), integer, default(500),
    'Lifetime points at which a customer is silver; below it the customer is bronze.').
battery_input(loyalty, fixed(loyalty), attribute(platinum_redemption_multiplier), number, default(0.7),
    'Multiplier on a reward''s points cost for platinum customers (0.7 is 30% fewer points).').
battery_input(loyalty, fixed(loyalty), attribute(gold_redemption_multiplier), number, default(0.85),
    'Multiplier on a reward''s points cost for gold customers.').
battery_input(loyalty, fixed(loyalty), attribute(silver_redemption_multiplier), number, default(1.0),
    'Multiplier on a reward''s points cost for silver customers; bronze always pays 1.0.').

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

%% tier_benefit(+Customer, ?Benefit, -Value)
%% A benefit attached to several of the tiers the customer holds or outranks is
%% reported once.
tier_benefit(Customer, Benefit, Value) :-
    loyalty_tier(Customer, Tier),
    setof(B, loyalty_benefit_at(Tier, B), Benefits),
    member(Benefit, Benefits),
    attribute(Benefit, benefit_value, Value).

loyalty_benefit_at(Tier, Benefit) :-
    relation(Tier, has_benefit, Benefit).
loyalty_benefit_at(Tier, Benefit) :-
    relation(Lower, has_benefit, Benefit),
    tier_outranks(Tier, Lower).

tier_outranks(platinum, gold).
tier_outranks(platinum, silver).
tier_outranks(platinum, bronze).
tier_outranks(gold,     silver).
tier_outranks(gold,     bronze).
tier_outranks(silver,   bronze).
