:- use_module(library(plunit)).

:- consult('../../modules/business/approval/approval').

%% Cases from the synthetic set with planted answers (A1-A14). Records: a
%% manager may approve up to 5,000, the finance director anything, and Lee
%% legal items. An answer the platform reports as unknown (no authority, no
%% statement about the item) is a failure here: the rules alone cannot tell
%% "no" from "not loaded", which is what battery_needs/4 declares.

setup_people :-
    assertz(attribute(priya, role, manager)),
    assertz(attribute(omar,  role, finance_director)),
    assertz(attribute(dana,  role, sales_lead)),
    assertz(attribute(lee,   role, legal_counsel)).

setup_authority :-
    assertz(attribute(auth_mgr, approver_role, manager)),
    assertz(attribute(auth_mgr, up_to, 5000)),
    assertz(attribute(auth_fd,  approver_role, finance_director)),
    assertz(attribute(auth_lee, approver, lee)),
    assertz(attribute(auth_lee, covers_category, legal)).

setup_records :- setup_people, setup_authority.

item(Id, Amount) :-
    assertz(attribute(Id, title, Id)),
    assertz(attribute(Id, amount, Amount)).

stmt(Id, About, Act, By, On) :-
    assertz(attribute(Id, about, About)),
    assertz(attribute(Id, act, Act)),
    assertz(attribute(Id, by, By)),
    assertz(attribute(Id, on, On)).

setup_a1 :- setup_records, item(laptop_order, 3200),
    stmt(a1_s1, laptop_order, approve, priya, 20754).

setup_a2 :- setup_records, item(vendor_x, 4000),
    stmt(a2_s1, vendor_x, approve, priya, 20754),
    stmt(a2_s2, vendor_x, withdraw, priya, 20756).

setup_a3 :- setup_records, item(booth, 4500),
    stmt(a3_s1, booth, approve, omar, 20759), assertz(attribute(a3_s1, order, 1)),
    stmt(a3_s2, booth, reject, priya, 20759), assertz(attribute(a3_s2, order, 2)).

setup_a4 :- setup_records, item(trade_show, 4800),
    stmt(a4_s1, trade_show, reject, priya, 20760), assertz(attribute(a4_s1, order, 1)),
    stmt(a4_s2, trade_show, approve, omar, 20760), assertz(attribute(a4_s2, order, 2)).

setup_a5 :- setup_records, item(server_upgrade, 12000),
    stmt(a5_s1, server_upgrade, approve, priya, 20760).

setup_a6 :- setup_records, item(consulting, 2500),
    stmt(a6_s1, consulting, approve, omar, 20762),
    assertz(attribute(a6_s1, condition, 'after legal review')).

setup_a7 :- setup_records, item(travel_pkg, 7500),
    stmt(a7_s1, travel_pkg, approve, omar, 20762),
    assertz(attribute(a7_s1, limit, 5000)).

setup_a8 :- setup_people, item(office_move, 2000),
    stmt(a8_s1, office_move, approve, priya, 20762).

setup_a9 :- setup_records, item(software_renewal, 3000).

setup_a10 :- setup_records, item(marketing_plan, 3000),
    stmt(a10_s1, marketing_plan, reject, priya, 20762).

setup_a11 :- setup_records,
    assertz(attribute(nda_template, title, 'new NDA template')),
    assertz(attribute(nda_template, category, legal)),
    stmt(a11_s1, nda_template, approve, lee, 20762).

setup_a12 :- setup_records,
    assertz(attribute(team_offsite, title, 'team offsite')),
    stmt(a12_s1, team_offsite, approve, priya, 20762).

setup_a13 :- setup_records, item(laptop_bag, 150),
    stmt(a13_s1, laptop_bag, approve, priya, 20760),
    stmt(a13_s2, laptop_bag, withdraw, dana, 20762).

setup_a14 :- setup_records, item(demo_kit, 800),
    stmt(a14_s1, demo_kit, approve, dana, 20762).

:- begin_tests(approval).

test(a1_plain_approve, [setup(setup_a1), cleanup(clear_facts)]) :-
    assertion(approved(laptop_order)),
    assertion(approved_by(laptop_order, priya, 20754)),
    assertion(\+ rejected(laptop_order)),
    assertion(\+ withdrawn(laptop_order)).

test(a2_withdraw_after_approve, [setup(setup_a2), cleanup(clear_facts)]) :-
    assertion(\+ approved(vendor_x)),
    assertion(withdrawn(vendor_x)).

test(a3_reject_after_approve_same_day, [setup(setup_a3), cleanup(clear_facts)]) :-
    assertion(\+ approved(booth)),
    assertion(rejected(booth)).

test(a4_approve_supersedes_earlier_reject, [setup(setup_a4), cleanup(clear_facts)]) :-
    assertion(approved(trade_show)),
    assertion(\+ rejected(trade_show)).

test(a5_over_the_approvers_limit, [setup(setup_a5), cleanup(clear_facts)]) :-
    assertion(\+ approved(server_upgrade)),
    assertion(unauthorized_approval(server_upgrade, priya)).

test(a6_conditional, [setup(setup_a6), cleanup(clear_facts)]) :-
    assertion(approved(consulting)),
    assertion(conditions(consulting, 'after legal review')).

test(a7_statement_limit_below_amount, [setup(setup_a7), cleanup(clear_facts)]) :-
    assertion(\+ approved(travel_pkg)),
    assertion(\+ unauthorized_approval(travel_pkg, omar)),
    assertion(limited_approval(travel_pkg, omar, 5000)).

%% Unknown on the platform: the authority role is empty.
test(a8_no_authority_is_not_approved_by_the_rules, [setup(setup_a8), cleanup(clear_facts)]) :-
    assertion(\+ approved(office_move)).

%% Unknown on the platform: no statement is about the item.
test(a9_no_statements, [setup(setup_a9), cleanup(clear_facts)]) :-
    assertion(\+ approved(software_renewal)),
    assertion(\+ rejected(software_renewal)).

test(a10_reject_only, [setup(setup_a10), cleanup(clear_facts)]) :-
    assertion(\+ approved(marketing_plan)),
    assertion(rejected(marketing_plan)).

test(a11_named_person_and_category, [setup(setup_a11), cleanup(clear_facts)]) :-
    assertion(authorized(lee, nda_template)),
    assertion(approved(nda_template)).

%% Open point: a limited authority and an item with no amount. The approval
%% does not stand, and it is not called unauthorized either.
test(a12_limited_authority_no_amount, [setup(setup_a12), cleanup(clear_facts)]) :-
    assertion(\+ approved(team_offsite)),
    assertion(\+ unauthorized_approval(team_offsite, priya)).

test(a13_withdraw_from_a_non_approver, [setup(setup_a13), cleanup(clear_facts)]) :-
    assertion(approved(laptop_bag)),
    assertion(\+ withdrawn(laptop_bag)),
    assertion(unauthorized_withdrawal(laptop_bag, dana)).

test(a14_approval_with_no_authority, [setup(setup_a14), cleanup(clear_facts)]) :-
    assertion(\+ approved(demo_kit)),
    assertion(unauthorized_approval(demo_kit, dana)).

test(unbound_item_enumerates_standing_approvals,
     [setup((setup_a1, setup_a2_items_only)), cleanup(clear_facts)]) :-
    findall(I, approved(I), Is),
    assertion(Is == [laptop_order]).

:- end_tests(approval).

setup_a2_items_only :- item(vendor_x, 4000),
    stmt(a2_s1, vendor_x, approve, priya, 20754),
    stmt(a2_s2, vendor_x, withdraw, priya, 20756).
