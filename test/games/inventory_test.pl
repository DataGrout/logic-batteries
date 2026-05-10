:- use_module(library(plunit)).

:- consult('../../modules/games/inventory/inventory').

%% (clear_facts/0 and dynamic declarations are in test/support/test_helpers.pl)

%% ── Setup predicates — all assertz calls here go to user module ───────────────

setup_alice_has_sword :-
    assertz(relation(alice, has_item, sword)).

setup_alice_has_rock :-
    assertz(relation(alice, has_item, rock)).

setup_alice_sword_weight8 :-
    assertz(relation(alice, has_item, sword)),
    assertz(attribute(sword, weight, 8)).

setup_alice_sword_shield :-
    assertz(relation(alice, has_item, sword)),
    assertz(attribute(sword, weight, 8)),
    assertz(relation(alice, has_item, shield)),
    assertz(attribute(shield, weight, 5)).

setup_alice_two_items :-
    assertz(relation(alice, has_item, sword)),
    assertz(relation(alice, has_item, shield)).

setup_alice_full_by_weight :-
    assertz(attribute(alice, max_carry_weight, 10)),
    assertz(relation(alice, has_item, heavy)),
    assertz(attribute(heavy, weight, 10)).

setup_alice_full_by_slots :-
    assertz(attribute(alice, max_slots, 2)),
    assertz(relation(alice, has_item, item1)),
    assertz(relation(alice, has_item, item2)).

setup_alice_under_limits :-
    assertz(attribute(alice, max_carry_weight, 50)),
    assertz(attribute(alice, max_slots, 5)),
    assertz(relation(alice, has_item, sword)),
    assertz(attribute(sword, weight, 8)).

setup_alice_brick_weight50 :-
    assertz(relation(alice, has_item, brick)),
    assertz(attribute(brick, weight, 50)).

setup_alice_20_items :-
    forall(
        between(1, 20, I),
        ( atom_concat(item, I, Item), assertz(relation(alice, has_item, Item)) )
    ).

setup_alice_nearly_full_by_weight :-
    assertz(attribute(alice, max_carry_weight, 10)),
    assertz(relation(alice, has_item, heavy)),
    assertz(attribute(heavy, weight, 9)),
    assertz(attribute(newitem, weight, 5)).

setup_alice_one_slot_full :-
    assertz(attribute(alice, max_slots, 1)),
    assertz(relation(alice, has_item, existing)).

setup_alice_half_weight :-
    assertz(attribute(alice, max_carry_weight, 10)),
    assertz(relation(alice, has_item, partial)),
    assertz(attribute(partial, weight, 5)),
    assertz(attribute(newitem, weight, 5)).

setup_iron_sword_weight8 :-
    assertz(attribute(iron_sword, weight, 8)).

setup_alice_max_slots30 :-
    assertz(attribute(alice, max_slots, 30)).

setup_alice_max_weight80 :-
    assertz(attribute(alice, max_carry_weight, 80)).

%% ── has_item ─────────────────────────────────────────────────────────────────

:- begin_tests(inventory_has_item).

test(has_item_true, [setup(setup_alice_has_sword), cleanup(clear_facts)]) :-
    assertion(has_item(alice, sword)).

test(has_item_false, [setup(true), cleanup(clear_facts)]) :-
    assertion(\+ has_item(alice, sword)).

:- end_tests(inventory_has_item).

%% ── carrying_weight ───────────────────────────────────────────────────────────

:- begin_tests(inventory_weight).

test(weight_empty_inventory, [setup(true), cleanup(clear_facts)]) :-
    carrying_weight(alice, W),
    assertion(W == 0).

test(weight_single_item_default, [setup(setup_alice_has_rock), cleanup(clear_facts)]) :-
    carrying_weight(alice, W),
    assertion(W == 1).

test(weight_single_item_explicit, [setup(setup_alice_sword_weight8), cleanup(clear_facts)]) :-
    carrying_weight(alice, W),
    assertion(W == 8).

test(weight_multiple_items, [setup(setup_alice_sword_shield), cleanup(clear_facts)]) :-
    carrying_weight(alice, W),
    assertion(W == 13).

:- end_tests(inventory_weight).

%% ── item_count ────────────────────────────────────────────────────────────────

:- begin_tests(inventory_item_count).

test(count_empty, [setup(true), cleanup(clear_facts)]) :-
    item_count(alice, N),
    assertion(N == 0).

test(count_two_items, [setup(setup_alice_two_items), cleanup(clear_facts)]) :-
    item_count(alice, N),
    assertion(N == 2).

:- end_tests(inventory_item_count).

%% ── inventory_full ────────────────────────────────────────────────────────────

:- begin_tests(inventory_full).

test(not_full_empty, [setup(true), cleanup(clear_facts)]) :-
    assertion(\+ inventory_full(alice)).

test(full_by_weight, [setup(setup_alice_full_by_weight), cleanup(clear_facts)]) :-
    assertion(inventory_full(alice)).

test(full_by_slots, [setup(setup_alice_full_by_slots), cleanup(clear_facts)]) :-
    assertion(inventory_full(alice)).

test(not_full_under_limits, [setup(setup_alice_under_limits), cleanup(clear_facts)]) :-
    assertion(\+ inventory_full(alice)).

test(default_weight_limit_is_50, [setup(setup_alice_brick_weight50), cleanup(clear_facts)]) :-
    assertion(inventory_full(alice)).

test(default_slots_limit_is_20, [setup(setup_alice_20_items), cleanup(clear_facts)]) :-
    assertion(inventory_full(alice)).

:- end_tests(inventory_full).

%% ── can_carry ─────────────────────────────────────────────────────────────────

:- begin_tests(inventory_can_carry).

test(can_carry_empty_inventory, [setup(true), cleanup(clear_facts)]) :-
    assertion(can_carry(alice, sword)).

test(cannot_carry_already_held, [setup(setup_alice_has_sword), cleanup(clear_facts)]) :-
    assertion(\+ can_carry(alice, sword)).

test(cannot_carry_weight_exceeded, [setup(setup_alice_nearly_full_by_weight),
                                     cleanup(clear_facts)]) :-
    assertion(\+ can_carry(alice, newitem)).

test(cannot_carry_slots_full, [setup(setup_alice_one_slot_full), cleanup(clear_facts)]) :-
    assertion(\+ can_carry(alice, newitem)).

test(can_carry_exact_weight_boundary, [setup(setup_alice_half_weight),
                                        cleanup(clear_facts)]) :-
    assertion(can_carry(alice, newitem)).

:- end_tests(inventory_can_carry).

%% ── Default override ──────────────────────────────────────────────────────────

:- begin_tests(inventory_defaults).

test(default_item_weight_is_1, [setup(true), cleanup(clear_facts)]) :-
    item_weight(any_item, W),
    assertion(W == 1).

test(override_item_weight, [setup(setup_iron_sword_weight8), cleanup(clear_facts)]) :-
    item_weight(iron_sword, W),
    assertion(W == 8).

test(default_max_slots_is_20, [setup(true), cleanup(clear_facts)]) :-
    max_slots(alice, N),
    assertion(N == 20).

test(override_max_slots, [setup(setup_alice_max_slots30), cleanup(clear_facts)]) :-
    max_slots(alice, N),
    assertion(N == 30).

test(default_max_carry_weight_is_50, [setup(true), cleanup(clear_facts)]) :-
    max_carry_weight(alice, W),
    assertion(W == 50).

test(override_max_carry_weight, [setup(setup_alice_max_weight80), cleanup(clear_facts)]) :-
    max_carry_weight(alice, W),
    assertion(W == 80).

:- end_tests(inventory_defaults).
