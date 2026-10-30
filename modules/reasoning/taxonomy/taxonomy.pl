%% Battery: taxonomy v1.0.1
%% Exports: isa/2, inherits_property/3, most_specific_class/2,
%%          common_ancestor/3, siblings/2, subclasses/2, class_members/2,
%%          depth_in_hierarchy/2, compatible_types/2, root_class/1

battery_module(taxonomy, '1.0.1', auto).

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

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). Members and
%% classes are one kind of subject, linked by is_a. inherits_property/3 also
%% reads attribute(Entity, Property, Value) for whichever Property it is asked
%% about (or every one, when none is named), on the entity first and then up
%% the is_a chain, so there is no fixed attribute name to declare. root_class/1 enumerates entity/1 facts, which
%% are outside the contract's attribute, relation and metric kinds.

battery_input(taxonomy, entity, relation(is_a), ref(entity), key,
    'A direct parent class of this member or subclass, followed transitively; several parents are allowed and a cycle is tolerated.').

%% ── Core is-a hierarchy ──────────────────────────────────────────────────────
%% Assert: { type="relation", subject="goblin", relation="is_a", object="humanoid" }
%%         { type="relation", subject="humanoid", relation="is_a", object="creature" }

%% Every walk over is_a carries a visited set, so a cycle in the hierarchy
%% terminates instead of looping. Directives are stripped at install, so
%% tabling is not available for this.
isa(Entity, Class) :-
    isa_(Entity, Class, [Entity]).

isa_(Entity, Class, _) :-
    relation(Entity, is_a, Class).
isa_(Entity, Class, Seen) :-
    relation(Entity, is_a, Mid),
    \+ member(Mid, Seen),
    isa_(Mid, Class, [Mid|Seen]).

%% ── Property inheritance ─────────────────────────────────────────────────────
%% For each property the nearest definition wins: the entity's own attribute,
%% else the closest ancestor that has one (fewest is_a hops; at equal distance,
%% the first in fact order). A bound Value is compared against that nearest
%% value, so an ancestor's value never answers for an entity that overrides it.
%% Unbound Property enumerates each property the entity has or inherits, once;
%% unbound Entity enumerates every subject that carries an attribute or an
%% is_a edge.
%% Assert: { type="attribute", entity="creature", attribute="has_soul", value=true }

inherits_property(Entity, Property, Value) :-
    ( var(Entity) -> taxonomy_subject(Entity) ; true ),
    ( var(Property) -> taxonomy_visible_property(Entity, Property) ; true ),
    taxonomy_nearest_value([Entity], [Entity], Property, Nearest),
    Value = Nearest.

taxonomy_subject(Entity) :-
    setof(E, P^V^C^( attribute(E, P, V) ; relation(E, is_a, C) ), Es),
    member(Entity, Es).

taxonomy_visible_property(Entity, Property) :-
    setof(P, N^V^( ( N = Entity ; isa(Entity, N) ), attribute(N, P, V) ), Ps),
    member(Property, Ps).

%% Breadth-first over is_a, one level at a time, with a visited set so a cycle
%% terminates. Deterministic: the first level holding the property answers.
taxonomy_nearest_value(Level, Seen, Property, Value) :-
    (   member(N, Level), attribute(N, Property, V)
    ->  Value = V
    ;   findall(P, ( member(N, Level), relation(N, is_a, P) ), Ps),
        taxonomy_fresh(Ps, Seen, Next, Seen1),
        Next \== [],
        taxonomy_nearest_value(Next, Seen1, Property, Value)
    ).

%% taxonomy_fresh(+Xs, +Seen0, -New, -Seen): Xs not yet seen, first occurrence
%% only, in order.
taxonomy_fresh([], Seen, [], Seen).
taxonomy_fresh([X|Xs], Seen0, New, Seen) :-
    (   member(X, Seen0)
    ->  New = New1, Seen1 = Seen0
    ;   New = [X|New1], Seen1 = [X|Seen0]
    ),
    taxonomy_fresh(Xs, Seen1, New1, Seen).

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

depth_in_hierarchy(Class, Depth) :-
    depth_in_hierarchy_(Class, Depth, [Class]).

depth_in_hierarchy_(Class, 0, _) :-
    \+ relation(Class, is_a, _), !.
depth_in_hierarchy_(Class, Depth, Seen) :-
    relation(Class, is_a, Parent),
    \+ member(Parent, Seen),
    depth_in_hierarchy_(Parent, ParentDepth, [Parent|Seen]),
    Depth is ParentDepth + 1.

root_class(Class) :-
    entity(Class),
    \+ relation(Class, is_a, _).

compatible_types(E1, E2) :-
    common_ancestor(E1, E2, _), !.
