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
