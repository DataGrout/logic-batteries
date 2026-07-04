%% Battery: pricing_rules v1.0.0
%% Exports: effective_price/3, discount_applicable/2, bulk_discount/3,
%%          price_tier/3, price_capped/3

battery_module(pricing_rules, '1.0.0', auto).

battery_export(pricing_rules, 'effective_price/3',    'effective_price(Item, Customer, Price) — final price after all applicable discounts').
battery_export(pricing_rules, 'discount_applicable/2','discount_applicable(Item, Discount) — Discount rule applies to Item').
battery_export(pricing_rules, 'bulk_discount/3',      'bulk_discount(Item, Qty, PctOff) — percentage discount for purchasing Qty units').
battery_export(pricing_rules, 'price_tier/3',         'price_tier(Item, Customer, Tier) — pricing tier: standard/member/vip').
battery_export(pricing_rules, 'price_capped/3',       'price_capped(Item, Customer, Price) — effective price clipped to floor/ceiling').

%% ── Pricing Data Model ────────────────────────────────────────────────────────
%%
%% Item base price:
%%   attribute(widget, base_price,  100)
%%   attribute(widget, price_floor,  50)     %% minimum allowed price
%%   attribute(widget, price_ceil,  200)     %% maximum allowed price
%%
%% Discount rules (relation links item to rule):
%%   relation(widget, has_discount, widget_sale)
%%   attribute(widget_sale, pct_off,    20)        %% percentage off base
%%   attribute(widget_sale, flat_off,   10)        %% flat amount off (alternative)
%%   attribute(widget_sale, requires_tier, member) %% optional tier gate
%%
%% Bulk discounts:
%%   attribute(widget, bulk_qty_1,  10)   %% quantity threshold
%%   attribute(widget, bulk_pct_1,   5)   %% % off at that threshold
%%   attribute(widget, bulk_qty_2,  50)
%%   attribute(widget, bulk_pct_2,  15)
%%
%% Customer tiers:
%%   attribute(customer_123, pricing_tier, member)   %% standard/member/vip
%%
%% Tier multipliers (override defaults):
%%   attribute(pricing, member_multiplier, 0.9)   %% 10% off for members
%%   attribute(pricing, vip_multiplier,    0.8)   %% 20% off for vip

%% ── Tier multipliers ─────────────────────────────────────────────────────────

tier_multiplier(standard, 1.0).
tier_multiplier(member,   M) :- attribute(pricing, member_multiplier, M), !.
tier_multiplier(member,   0.9).
tier_multiplier(vip,      M) :- attribute(pricing, vip_multiplier, M), !.
tier_multiplier(vip,      0.8).

%% price_tier(+Item, +Customer, -Tier)
price_tier(_, Customer, Tier) :-
    attribute(Customer, pricing_tier, Tier), !.
price_tier(_, _, standard).

%% ── Discount applicability ────────────────────────────────────────────────────

discount_applicable(Item, Discount) :-
    relation(Item, has_discount, Discount),
    ( attribute(Discount, requires_tier, _) -> true ; true ).

discount_applicable_for(Item, Customer, Discount) :-
    discount_applicable(Item, Discount),
    ( attribute(Discount, requires_tier, ReqTier)
      -> price_tier(Item, Customer, Tier), Tier = ReqTier
      ;  true ).

discount_amount(Item, _Customer, Discount, Amount) :-
    attribute(Item, base_price, Base),
    ( attribute(Discount, pct_off, Pct)
      -> Amount is round(Base * Pct / 100)
      ;  ( attribute(Discount, flat_off, Amount) -> true ; Amount = 0 ) ).

%% ── Bulk discounts ────────────────────────────────────────────────────────────

bulk_discount(Item, Qty, PctOff) :-
    findall(Threshold-Pct,
            (bulk_tier(Item, Threshold, Pct), Qty >= Threshold),
            Tiers),
    Tiers \= [],
    msort(Tiers, Sorted),
    last(Sorted, _-PctOff), !.
bulk_discount(_, _, 0).

bulk_tier(Item, Threshold, Pct) :-
    member(N, [1,2,3,4,5]),
    atom_concat(bulk_qty_, N, QAttr),
    atom_concat(bulk_pct_, N, PAttr),
    attribute(Item, QAttr, Threshold),
    attribute(Item, PAttr, Pct).

%% ── effective_price/3 ─────────────────────────────────────────────────────────

effective_price(Item, Customer, Price) :-
    attribute(Item, base_price, Base),
    price_tier(Item, Customer, Tier),
    tier_multiplier(Tier, Mult),
    TierPrice is round(Base * Mult),
    sum_discounts(Item, Customer, TierPrice, Price).

sum_discounts(Item, Customer, StartPrice, FinalPrice) :-
    findall(Amt,
            ( discount_applicable_for(Item, Customer, Disc),
              discount_amount(Item, Customer, Disc, Amt) ),
            Amts),
    sum_list(Amts, Total),
    FinalPrice is max(0, StartPrice - Total).

%% price_capped(+Item, +Customer, -Price)
price_capped(Item, Customer, Price) :-
    effective_price(Item, Customer, Raw),
    ( attribute(Item, price_floor, Floor) -> Price1 is max(Raw, Floor) ; Price1 = Raw ),
    ( attribute(Item, price_ceil,  Ceil)  -> Price  is min(Price1, Ceil) ; Price = Price1 ).
