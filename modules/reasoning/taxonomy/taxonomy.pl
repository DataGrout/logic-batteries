%% Battery: taxonomy v1.0.0
%% Exports: isa/2, inherits_property/3, most_specific_class/2,
%%          common_ancestor/3, siblings/2, subclasses/2, class_members/2,
%%          depth_in_hierarchy/2, compatible_types/2, root_class/1

battery_module(taxonomy, '1.0.0', auto).

battery_export(taxonomy, 'isa/2',
    'isa(Entity, Class) — Entity is a Class (direct or transitive via is_a relations)').
battery_export(taxonomy, 'inherits_property/3',
    'inherits_property(Entity, Property, Value) — Entity has Property via direct attribute or ancestor chain').
battery_export(taxonomy, 'most_specific_class/2',
    'most_specific_class(Entity, Class) — Class is the most specific is_a class Entity has').
battery_export(taxonomy, 'common_ancestor/3',
    'common_ancestor(E1, E2, Ancestor) — Ancestor is a shared isa ancestor of E1 and E2').
battery_export(taxonomy, 'siblings/2',
    'siblings(E1, E2) — E1 and E2 share the same direct parent class').
battery_export(taxonomy, 'subclasses/2',
    'subclasses(Class, Subs) — Subs is the list of all transitive subclasses of Class').
battery_export(taxonomy, 'class_members/2',
    'class_members(Class, Members) — Members is the list of entities that isa Class').
battery_export(taxonomy, 'depth_in_hierarchy/2',
    'depth_in_hierarchy(Class, Depth) — Depth is the number of hops from Class to a root (no parent)').
battery_export(taxonomy, 'compatible_types/2',
    'compatible_types(E1, E2) — E1 and E2 share at least one common ancestor').
battery_export(taxonomy, 'root_class/1',
    'root_class(Class) — Class has no is_a parent').

%% ── Core is-a hierarchy ──────────────────────────────────────────────────────
%% Assert: { type="relation", subject="goblin", relation="is_a", object="humanoid" }
%%         { type="relation", subject="humanoid", relation="is_a", object="creature" }

isa(Entity, Class) :-
    relation(Entity, is_a, Class).
isa(Entity, Class) :-
    relation(Entity, is_a, Mid),
    isa(Mid, Class).

%% ── Property inheritance ─────────────────────────────────────────────────────
%% Direct attribute wins; if absent, walks up is_a chain.
%% Assert: { type="attribute", entity="creature", attribute="has_soul", value=true }

inherits_property(Entity, Property, Value) :-
    attribute(Entity, Property, Value), !.
inherits_property(Entity, Property, Value) :-
    relation(Entity, is_a, Parent),
    inherits_property(Parent, Property, Value).

%% ── Classification queries ───────────────────────────────────────────────────

most_specific_class(Entity, Class) :-
    findall(C, relation(Entity, is_a, C), DirectClasses),
    DirectClasses \= [],
    member(Class, DirectClasses),
    \+ (member(Other, DirectClasses), Other \= Class, isa(Other, Class)).

common_ancestor(E1, E2, Ancestor) :-
    isa(E1, Ancestor),
    isa(E2, Ancestor).

siblings(E1, E2) :-
    relation(E1, is_a, Parent),
    relation(E2, is_a, Parent),
    E1 \= E2.

subclasses(Class, Subs) :-
    findall(Sub, isa(Sub, Class), Subs).

class_members(Class, Members) :-
    findall(E, isa(E, Class), Members).

%% ── Structural queries ───────────────────────────────────────────────────────

depth_in_hierarchy(Class, 0) :-
    \+ relation(Class, is_a, _), !.
depth_in_hierarchy(Class, Depth) :-
    relation(Class, is_a, Parent),
    depth_in_hierarchy(Parent, ParentDepth),
    Depth is ParentDepth + 1.

root_class(Class) :-
    entity(Class),
    \+ relation(Class, is_a, _).

compatible_types(E1, E2) :-
    common_ancestor(E1, E2, _), !.
