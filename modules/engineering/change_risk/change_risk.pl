%% Battery: change_risk v1.0.0
%% Requires: (nothing)
%% Exports: low_risk/1, risk_reason/2, change_blast_radius/2, affected_unit/2,
%%          unowned_file/2, owner_coverage/3, owners_of/2

:- dynamic(attribute/3).

battery_module(change_risk, '1.0.0', auto).

battery_export(change_risk, 'low_risk/1',
    'low_risk(Change) — the code calling into what the change touches stays within the policy''s blast radius, and every changed file has an owner').
battery_export(change_risk, 'risk_reason/2',
    'risk_reason(Change, Reason) — why the change is not low risk: wide_blast_radius(N, Max) or unowned_files(Count)').
battery_export(change_risk, 'change_blast_radius/2',
    'change_blast_radius(Change, N) — how many code units outside the change reach the code it touches through calls, directly or through other callers').
battery_export(change_risk, 'affected_unit/2',
    'affected_unit(Change, Unit) — Unit is outside the change and reaches the code it touches through calls').
battery_export(change_risk, 'unowned_file/2',
    'unowned_file(Change, Path) — no owner rule gives the changed file at Path an owner').
battery_export(change_risk, 'owner_coverage/3',
    'owner_coverage(Change, Owned, Total) — Owned of the change''s Total changed files have an owner').
battery_export(change_risk, 'owners_of/2',
    'owners_of(Change, Owner) — Owner owns at least one of the changed files').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). The code graph is
%% code units (functions, methods) with the file each is defined in and the
%% units each calls. Ownership is a CODEOWNERS file, one subject per line.

battery_input(change_risk, changed_file, attribute(file_of), ref(change), key,
    'The change the file is part of.').
battery_input(change_risk, changed_file, attribute(path), atom, required,
    'The file''s path from the repository root (lib/billing.ex).').
battery_input(change_risk, code_unit, attribute(defined_in), atom, key,
    'The path of the file the unit is defined in, spelled as changed files spell theirs.').
battery_input(change_risk, code_unit, attribute(calls), ref(code_unit), optional,
    'A unit this one calls; one fact per callee.').
battery_input(change_risk, owner_rule, attribute(owns_pattern), atom, key,
    'A CODEOWNERS pattern: *, *.ext, a directory (docs/, /lib/billing/) or a path.').
battery_input(change_risk, owner_rule, attribute(owner), atom, optional,
    'An owner of the files the pattern matches; one fact per owner. A rule with none leaves its files unowned.').
battery_input(change_risk, owner_rule, attribute(line), integer, optional,
    'The rule''s line in the file. When several match, the last one decides.').
battery_input(change_risk, fixed(risk_policy), attribute(max_blast_radius), integer, default(25),
    'The most affected units a low-risk change may have.').
battery_input(change_risk, fixed(risk_policy), attribute(require_owners), bool, default(true),
    'true when every changed file must have an owner.').

battery_needs(change_risk, code_unit, any,
    'The code graph: where each unit is defined and what it calls. Without it no blast radius can be measured.').
battery_needs(change_risk, owner_rule, any,
    'Who owns which paths (a CODEOWNERS file, as records). Without it ownership cannot be judged.').
battery_needs(change_risk, changed_file, attribute(file_of),
    'At least one changed file of the change.').

%% ── Data model ───────────────────────────────────────────────────────────────
%%
%%   attribute(f1, file_of, pr_7)              attribute(o1, owns_pattern, '*')
%%   attribute(f1, path, 'lib/billing.ex')     attribute(o1, owner, '@org/core')
%%   attribute(charge_1, defined_in, 'lib/billing.ex')
%%   attribute(checkout_2, defined_in, 'lib/checkout.ex')
%%   attribute(checkout_2, calls, charge_1)    attribute(o2, owns_pattern, '/lib/billing/')
%%   attribute(o2, line, 4)                    attribute(o2, owner, '@org/billing')

%% ── Changes ──────────────────────────────────────────────────────────────────

cr_target(C) :-
    ( var(C) -> cr_changes(Cs), member(C, Cs) ; true ).

cr_changes(Cs) :-
    findall(C, attribute(_, file_of, C), Cs0),
    sort(Cs0, Cs).

cr_paths(C, Paths) :-
    findall(P, ( attribute(F, file_of, C), attribute(F, path, P) ), Ps),
    sort(Ps, Paths).

cr_setting(Name, Default, Value) :-
    ( attribute(risk_policy, Name, V) -> Value = V ; Value = Default ).

cr_graph_loaded :- attribute(_, defined_in, _), !.
cr_owners_loaded :- attribute(_, owns_pattern, _), !.

%% ── Blast radius ─────────────────────────────────────────────────────────────

%% The units defined in the changed files.
cr_touched(C, Units) :-
    cr_paths(C, Paths),
    findall(U, ( member(P, Paths), attribute(U, defined_in, P) ), Us),
    sort(Us, Units).

%% Every unit that reaches Seeds through calls, found breadth first; the seeds
%% themselves are not counted.
cr_callers_of(Seeds, Affected) :-
    cr_walk(Seeds, Seeds, Reached),
    findall(U, ( member(U, Reached), \+ memberchk(U, Seeds) ), Us),
    sort(Us, Affected).

cr_walk([], Seen, Seen).
cr_walk([U|Queue], Seen, Reached) :-
    findall(X, ( attribute(X, calls, U), \+ memberchk(X, Seen) ), New0),
    sort(New0, New),
    append(Seen, New, Seen1),
    append(Queue, New, Queue1),
    cr_walk(Queue1, Seen1, Reached).

cr_affected(C, Affected) :-
    cr_touched(C, Seeds),
    cr_callers_of(Seeds, Affected).

%% ── Ownership ────────────────────────────────────────────────────────────────

cr_line(R, L) :- ( attribute(R, line, L0) -> L = L0 ; L = 0 ).

%% cr_rule_for(+Path, -Rule): the last owner rule whose pattern matches Path.
cr_rule_for(Path, Rule) :-
    findall(L-R, ( attribute(R, owns_pattern, Pat), cr_match(Pat, Path), cr_line(R, L) ), Ps0),
    keysort(Ps0, Ps1),
    reverse(Ps1, [_-Rule|_]).

cr_owned(Path) :-
    cr_rule_for(Path, R),
    attribute(R, owner, _).

%% CODEOWNERS patterns, matched against a root-relative path. * matches
%% within one path segment, ** across segments and ? one character. A pattern
%% starting with / or with a / inside it is anchored at the root; otherwise it
%% matches a segment at any depth. A pattern ending in / names a directory
%% and owns everything under it; one ending in /* owns only the files directly
%% in its directory; any other pattern owns the path it matches and, as a
%% directory, everything under it.
cr_match('*', _) :- !.
cr_match(Pat, Path) :-
    atom_codes(Pat, P0),
    atom_codes(Path, Cs),
    (   P0 = [47|P1] -> Lead = true ; P1 = P0, Lead = false ),
    (   append(Body, [47], P1) -> Kind = dir
    ;   append(_, [47, 42], P1) -> Body = P1, Kind = files
    ;   Body = P1, Kind = path
    ),
    (   Lead == true -> Anchored = true
    ;   memberchk(47, Body) -> Anchored = true
    ;   Anchored = false
    ),
    cr_target(Kind, Cs, Target),
    cr_glob_at(Anchored, Body, Target),
    !.

%% The paths a pattern is tried against: the file itself unless the pattern
%% names a directory, and each directory above it unless it owns files only.
cr_target(Kind, Cs, Cs) :- Kind \== dir.
cr_target(Kind, Cs, Dir) :-
    Kind \== files,
    append(Dir, [47|_], Cs),
    Dir \== [].

%% An unanchored pattern has no / in it and is matched against the target's
%% last segment.
cr_glob_at(true, Body, Target) :- cr_glob(Body, Target).
cr_glob_at(false, Body, Target) :-
    cr_last_segment(Target, Segment),
    cr_glob(Body, Segment).

cr_last_segment(Cs, Segment) :-
    (   append(_, [47|Rest], Cs), \+ memberchk(47, Rest) -> Segment = Rest ; Segment = Cs ).

%% cr_glob(+Pattern, +Text): code lists; 42 is *, 63 is ?, 47 is /.
cr_glob([], []).
cr_glob([42, 42, 47|P], S) :-
    (   cr_glob(P, S)
    ;   append(_, [47|Rest], S), cr_glob(P, Rest)
    ).
cr_glob([42, 42], _) :- !.
cr_glob([42|P], S) :-
    P \= [42|_],
    (   cr_glob(P, S)
    ;   S = [C|S1], C =\= 47, cr_glob([42|P], S1)
    ).
cr_glob([63|P], [C|S]) :-
    C =\= 47,
    cr_glob(P, S).
cr_glob([C|P], [C|S]) :-
    C =\= 42, C =\= 63,
    cr_glob(P, S).

%% ── Exports ──────────────────────────────────────────────────────────────────

%% affected_unit(?Change, ?Unit)
affected_unit(C, U) :-
    cr_target(C),
    cr_graph_loaded,
    cr_affected(C, Us),
    member(U, Us).

%% change_blast_radius(?Change, ?N)
change_blast_radius(C, N) :-
    cr_target(C),
    cr_graph_loaded,
    cr_affected(C, Us),
    length(Us, N).

%% unowned_file(?Change, ?Path)
unowned_file(C, Path) :-
    cr_target(C),
    cr_owners_loaded,
    cr_paths(C, Paths),
    member(Path, Paths),
    \+ cr_owned(Path).

%% owner_coverage(?Change, ?Owned, ?Total)
owner_coverage(C, Owned, Total) :-
    cr_target(C),
    cr_owners_loaded,
    cr_paths(C, Paths),
    length(Paths, Total),
    findall(P, ( member(P, Paths), cr_owned(P) ), Os),
    length(Os, Owned).

%% owners_of(?Change, ?Owner)
owners_of(C, Owner) :-
    cr_target(C),
    cr_paths(C, Paths),
    findall(O, ( member(P, Paths), cr_rule_for(P, R), attribute(R, owner, O) ), Os0),
    sort(Os0, Os),
    member(Owner, Os).

%% risk_reason(?Change, ?Reason)
risk_reason(C, wide_blast_radius(N, Max)) :-
    change_blast_radius(C, N),
    cr_setting(max_blast_radius, 25, Max),
    N > Max.
risk_reason(C, unowned_files(Count)) :-
    cr_setting(require_owners, true, true),
    cr_target(C),
    cr_owners_loaded,
    findall(P, unowned_file(C, P), Ps),
    length(Ps, Count),
    Count > 0.

%% low_risk(?Change): decided only with the code graph, at least one changed
%% file and, when owners are required, the owner rules loaded.
low_risk(C) :-
    cr_target(C),
    cr_graph_loaded,
    ( cr_setting(require_owners, true, true) -> cr_owners_loaded ; true ),
    cr_paths(C, [_|_]),
    \+ risk_reason(C, _).
