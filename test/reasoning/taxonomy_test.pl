:- use_module(library(plunit)).

:- consult('../../modules/reasoning/taxonomy/taxonomy').

%% (clear_facts/0 is in test/support/test_helpers.pl)

%% ── Setup predicates ─────────────────────────────────────────────────────────

%% goblin → humanoid → creature → being
setup_creature_hierarchy :-
    assertz(relation(goblin,   is_a, humanoid)),
    assertz(relation(humanoid, is_a, creature)),
    assertz(relation(creature, is_a, being)).

setup_property_inheritance :-
    setup_creature_hierarchy,
    assertz(attribute(creature, has_soul,     true)),
    assertz(attribute(humanoid, speaks_language, true)),
    assertz(attribute(goblin,   color, green)).

setup_siblings :-
    assertz(relation(elf,   is_a, humanoid)),
    assertz(relation(dwarf, is_a, humanoid)),
    assertz(relation(orc,   is_a, humanoid)).

setup_depth :-
    setup_creature_hierarchy.

setup_direct_overrides_ancestor :-
    setup_property_inheritance,
    assertz(attribute(goblin, has_soul, false)).

%% ── isa/2 ────────────────────────────────────────────────────────────────────

:- begin_tests(taxonomy_isa).

test(direct_isa, [setup(setup_creature_hierarchy), cleanup(clear_facts)]) :-
    assertion(isa(goblin, humanoid)).

test(transitive_isa_one_hop, [setup(setup_creature_hierarchy), cleanup(clear_facts)]) :-
    assertion(isa(goblin, creature)).

test(transitive_isa_two_hops, [setup(setup_creature_hierarchy), cleanup(clear_facts)]) :-
    assertion(isa(goblin, being)).

test(isa_not_reverse, [setup(setup_creature_hierarchy), cleanup(clear_facts)]) :-
    assertion(\+ isa(humanoid, goblin)).

test(isa_not_sibling, [setup((setup_creature_hierarchy, setup_siblings)), cleanup(clear_facts)]) :-
    assertion(\+ isa(elf, dwarf)).

:- end_tests(taxonomy_isa).

%% ── inherits_property/3 ──────────────────────────────────────────────────────

:- begin_tests(taxonomy_inherits_property).

test(direct_attribute_wins, [setup(setup_property_inheritance), cleanup(clear_facts)]) :-
    assertion(inherits_property(goblin, color, green)).

test(inherited_from_parent, [setup(setup_property_inheritance), cleanup(clear_facts)]) :-
    assertion(inherits_property(goblin, speaks_language, true)).

test(inherited_from_grandparent, [setup(setup_property_inheritance), cleanup(clear_facts)]) :-
    assertion(inherits_property(goblin, has_soul, true)).

test(direct_wins_over_ancestor, [setup(setup_direct_overrides_ancestor), cleanup(clear_facts)]) :-
    assertion(inherits_property(goblin, has_soul, false)).

test(no_such_property, [setup(setup_property_inheritance), cleanup(clear_facts)]) :-
    assertion(\+ inherits_property(goblin, wings, _)).

:- end_tests(taxonomy_inherits_property).

%% ── most_specific_class/2 ────────────────────────────────────────────────────

:- begin_tests(taxonomy_most_specific_class).

test(single_direct_class, [setup(setup_creature_hierarchy), cleanup(clear_facts)]) :-
    assertion(most_specific_class(goblin, humanoid)).

test(root_class_entity, [setup(setup_creature_hierarchy), cleanup(clear_facts)]) :-
    assertion(most_specific_class(humanoid, creature)).

:- end_tests(taxonomy_most_specific_class).

%% ── common_ancestor/3 ────────────────────────────────────────────────────────

:- begin_tests(taxonomy_common_ancestor).

test(siblings_share_parent, [setup((setup_creature_hierarchy, setup_siblings)), cleanup(clear_facts)]) :-
    assertion(common_ancestor(elf, dwarf, humanoid)).

test(siblings_share_grandparent, [setup((setup_creature_hierarchy, setup_siblings)), cleanup(clear_facts)]) :-
    assertion(common_ancestor(elf, goblin, creature)).

test(ancestor_of_self, [setup(setup_creature_hierarchy), cleanup(clear_facts)]) :-
    assertion(common_ancestor(goblin, goblin, humanoid)).

test(no_common_ancestor_for_roots, [setup(setup_creature_hierarchy), cleanup(clear_facts)]) :-
    assertion(\+ common_ancestor(being, being, _)).

:- end_tests(taxonomy_common_ancestor).

%% ── siblings/2 ───────────────────────────────────────────────────────────────

:- begin_tests(taxonomy_siblings).

test(two_siblings, [setup((setup_creature_hierarchy, setup_siblings)), cleanup(clear_facts)]) :-
    assertion(siblings(elf, dwarf)).

test(sibling_symmetric, [setup((setup_creature_hierarchy, setup_siblings)), cleanup(clear_facts)]) :-
    assertion(siblings(dwarf, elf)).

test(not_sibling_of_self, [setup((setup_creature_hierarchy, setup_siblings)), cleanup(clear_facts)]) :-
    assertion(\+ siblings(elf, elf)).

test(not_sibling_across_levels, [setup(setup_creature_hierarchy), cleanup(clear_facts)]) :-
    assertion(\+ siblings(goblin, creature)).

:- end_tests(taxonomy_siblings).

%% ── subclasses/2 and class_members/2 ─────────────────────────────────────────

:- begin_tests(taxonomy_subclasses).

test(direct_and_transitive_subclasses, [setup((setup_creature_hierarchy, setup_siblings)), cleanup(clear_facts)]) :-
    subclasses(humanoid, Subs),
    assertion(memberchk(goblin, Subs)),
    assertion(memberchk(elf,    Subs)),
    assertion(memberchk(dwarf,  Subs)).

test(transitive_subclasses_of_root, [setup(setup_creature_hierarchy), cleanup(clear_facts)]) :-
    subclasses(being, Subs),
    assertion(memberchk(goblin, Subs)),
    assertion(memberchk(humanoid, Subs)),
    assertion(memberchk(creature, Subs)).

test(class_members, [setup((setup_creature_hierarchy, setup_siblings)), cleanup(clear_facts)]) :-
    class_members(humanoid, Members),
    assertion(memberchk(goblin, Members)),
    assertion(memberchk(elf,    Members)),
    assertion(memberchk(dwarf,  Members)).

:- end_tests(taxonomy_subclasses).

%% ── depth_in_hierarchy/2 ─────────────────────────────────────────────────────

:- begin_tests(taxonomy_depth).

test(root_depth_zero, [setup(setup_depth), cleanup(clear_facts)]) :-
    assertion(depth_in_hierarchy(being, 0)).

test(one_hop_depth, [setup(setup_depth), cleanup(clear_facts)]) :-
    assertion(depth_in_hierarchy(creature, 1)).

test(two_hop_depth, [setup(setup_depth), cleanup(clear_facts)]) :-
    assertion(depth_in_hierarchy(humanoid, 2)).

test(leaf_depth, [setup(setup_depth), cleanup(clear_facts)]) :-
    assertion(depth_in_hierarchy(goblin, 3)).

:- end_tests(taxonomy_depth).

%% ── compatible_types/2 ───────────────────────────────────────────────────────

:- begin_tests(taxonomy_compatible_types).

test(siblings_compatible, [setup((setup_creature_hierarchy, setup_siblings)), cleanup(clear_facts)]) :-
    assertion(compatible_types(elf, dwarf)).

test(ancestor_descendant_compatible, [setup(setup_creature_hierarchy), cleanup(clear_facts)]) :-
    assertion(compatible_types(goblin, humanoid)).

:- end_tests(taxonomy_compatible_types).

%% ── is_a cycles terminate (v1.0.1) ───────────────────────────────────────────

setup_tax_fix_cycle :-
    assertz(relation(x_cls, is_a, y_cls)),
    assertz(relation(y_cls, is_a, x_cls)),
    assertz(attribute(y_cls, color, blue)).

:- begin_tests(taxonomy_cycle).

test(isa_through_cycle, [setup(setup_tax_fix_cycle), cleanup(clear_facts)]) :-
    assertion(isa(x_cls, y_cls)).

test(isa_missing_class_fails_instead_of_looping, [setup(setup_tax_fix_cycle), cleanup(clear_facts)]) :-
    assertion(\+ isa(x_cls, z_cls)).

test(inherits_through_cycle, [setup(setup_tax_fix_cycle), cleanup(clear_facts)]) :-
    assertion(inherits_property(x_cls, color, blue)).

test(inherits_missing_property_fails_instead_of_looping, [setup(setup_tax_fix_cycle), cleanup(clear_facts)]) :-
    assertion(\+ inherits_property(x_cls, wings, _)).

test(depth_of_a_cycle_with_no_root_fails, [setup(setup_tax_fix_cycle), cleanup(clear_facts)]) :-
    assertion(\+ depth_in_hierarchy(x_cls, _)).

:- end_tests(taxonomy_cycle).

%% ── inherits_property: the nearest definition wins, per property ─────────────
%% goblin → humanoid → creature → being; goblin overrides has_soul. A second
%% parent chain puts a closer definition behind a farther one in fact order.

setup_tax_nearest :-
    setup_direct_overrides_ancestor,
    assertz(attribute(being, has_soul, maybe)),
    assertz(relation(imp, is_a, deep_a)),
    assertz(relation(imp, is_a, near_b)),
    assertz(relation(deep_a, is_a, deep_a2)),
    assertz(attribute(deep_a2, size, huge)),
    assertz(attribute(near_b, size, small)).

:- begin_tests(taxonomy_inherits_nearest).

test(bound_value_from_ancestor_does_not_override_own, [setup(setup_tax_nearest), cleanup(clear_facts)]) :-
    assertion(\+ inherits_property(goblin, has_soul, true)),
    assertion(\+ inherits_property(goblin, has_soul, maybe)),
    assertion(inherits_property(goblin, has_soul, false)).

test(bound_value_on_class_takes_its_nearest, [setup(setup_tax_nearest), cleanup(clear_facts)]) :-
    assertion(inherits_property(humanoid, has_soul, true)),
    assertion(\+ inherits_property(humanoid, has_soul, maybe)).

test(unbound_value_is_one_answer, [setup(setup_tax_nearest), cleanup(clear_facts)]) :-
    findall(V, inherits_property(goblin, has_soul, V), Vs),
    assertion(Vs == [false]).

test(unbound_property_enumerates_each_once, [setup(setup_tax_nearest), cleanup(clear_facts)]) :-
    findall(P-V, inherits_property(goblin, P, V), PVs),
    msort(PVs, Sorted),
    assertion(Sorted == [color-green, has_soul-false, speaks_language-true]).

test(closest_ancestor_beats_earlier_parent_chain, [setup(setup_tax_nearest), cleanup(clear_facts)]) :-
    findall(V, inherits_property(imp, size, V), Vs),
    assertion(Vs == [small]).

test(unbound_entity_lists_each_subject_property, [setup(setup_tax_nearest), cleanup(clear_facts)]) :-
    findall(E-V, inherits_property(E, has_soul, V), EVs),
    msort(EVs, Sorted),
    assertion(Sorted == [being-maybe, creature-true, goblin-false, humanoid-true]).

:- end_tests(taxonomy_inherits_nearest).
