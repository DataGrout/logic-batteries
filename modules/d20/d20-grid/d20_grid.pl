%% Battery: d20-grid v1.0.0
%% SRD 5.1 (CC BY 4.0) — square-grid combat geometry: distance, range,
%% line of sight, cover, forced movement, and burst areas.
%% Standalone (no other battery required). Pairs naturally with d20-combat:
%% feed grid_cover/3 into AC handling and grid_los/2 into targeting.
%%
%% Exports: grid_distance/3, grid_adjacent/2, grid_in_range/3, grid_los/2,
%%          grid_los_xy/4, grid_cover/3, cover_ac_bonus/2, grid_push_dest/4,
%%          grid_in_burst/4, grid_occupied/2

%% Input predicates — declared dynamic for standalone (consult) use;
%% DataGrout strips directives at cell install time.
:- dynamic(grid_pos/3).
:- dynamic(grid_blocked/2).

battery_module('d20-grid', '1.0.0', auto).

battery_export('d20-grid', 'grid_distance/3', 'grid_distance(A, B, D) — Chebyshev distance in squares between two placed entities (the SRD''s "each square is 5 feet, diagonals count as one" ruling)').
battery_export('d20-grid', 'grid_adjacent/2', 'grid_adjacent(A, B) — the two entities occupy neighbouring squares (melee reach 1)').
battery_export('d20-grid', 'grid_in_range/3', 'grid_in_range(A, B, Range) — B is within Range squares of A').
battery_export('d20-grid', 'grid_los/2',      'grid_los(A, B) — no blocking square lies strictly between the two entities (Bresenham walk over grid_blocked/2)').
battery_export('d20-grid', 'grid_los_xy/4',   'grid_los_xy(X0, Y0, X1, Y1) — line of sight between raw squares; use for tile-targeted effects').
battery_export('d20-grid', 'grid_cover/3',    'grid_cover(Attacker, Target, Cover) — none | half | total. Total when sight is blocked; half when a blocking square shields the target (adjacent to it, on the attacker''s side)').
battery_export('d20-grid', 'cover_ac_bonus/2', 'cover_ac_bonus(Cover, Bonus) — SRD cover bonuses: none 0, half +2, three_quarters +5; total cover cannot be targeted (predicate fails)').
battery_export('d20-grid', 'grid_push_dest/4', 'grid_push_dest(Attacker, Target, X, Y) — the square one step directly away from the attacker; fails if that square is blocked or occupied').
battery_export('d20-grid', 'grid_in_burst/4', 'grid_in_burst(CX, CY, Radius, E) — entity E stands within Radius squares (Chebyshev) of the burst centre').
battery_export('d20-grid', 'grid_occupied/2', 'grid_occupied(X, Y) — some entity stands on the square').

%% ── Grid Data Model ──────────────────────────────────────────────────────────
%%
%% Entity positions (one per entity; the app moves entities by retracting and
%% re-asserting, exactly like hp mutation elsewhere in the d20 suite):
%%   grid_pos(fighter, 3, 7)
%%
%% Blocking terrain (pillars, walls — blocks movement AND sight):
%%   grid_blocked(5, 5)
%%
%% Squares are integers; the battery imposes no bounds — the map's edges are
%% the application's business.

%% ── Distance & Range ─────────────────────────────────────────────────────────
%%
%% Chebyshev distance: diagonal moves cost the same as orthogonal ones, per the
%% SRD 5.1 basic rule (the optional 5-10-5 diagonal variant is not modelled).

grid_distance(A, B, D) :-
    grid_pos(A, XA, YA),
    grid_pos(B, XB, YB),
    DX is abs(XA - XB),
    DY is abs(YA - YB),
    D is max(DX, DY).

grid_adjacent(A, B) :-
    grid_distance(A, B, 1).

grid_in_range(A, B, Range) :-
    grid_distance(A, B, D),
    D =< Range.

grid_occupied(X, Y) :-
    grid_pos(_, X, Y).

%% ── Line of Sight ────────────────────────────────────────────────────────────
%%
%% A straight Bresenham walk from square to square. Endpoints never block —
%% standing in a doorway does not blind you, and a creature is never behind
%% its own square.

grid_los(A, B) :-
    grid_pos(A, XA, YA),
    grid_pos(B, XB, YB),
    grid_los_xy(XA, YA, XB, YB).

grid_los_xy(X0, Y0, X1, Y1) :-
    DX is abs(X1 - X0),
    DY is abs(Y1 - Y0),
    SX is sign(X1 - X0),
    SY is sign(Y1 - Y0),
    Err is DX - DY,
    los_walk(X0, Y0, X1, Y1, DX, DY, SX, SY, Err).

%% los_walk steps to the next square first, so the origin is skipped; it
%% succeeds on arrival, so the destination is skipped too.
los_walk(X, Y, X, Y, _, _, _, _, _) :- !.
los_walk(X, Y, X1, Y1, DX, DY, SX, SY, Err) :-
    E2 is 2 * Err,
    (   E2 > -DY
    ->  ErrA is Err - DY,
        XA is X + SX
    ;   ErrA = Err,
        XA = X
    ),
    (   E2 < DX
    ->  ErrB is ErrA + DX,
        YB is Y + SY
    ;   ErrB = ErrA,
        YB = Y
    ),
    (   XA = X1, YB = Y1
    ->  true
    ;   \+ grid_blocked(XA, YB),
        los_walk(XA, YB, X1, Y1, DX, DY, SX, SY, ErrB)
    ).

%% ── Cover ────────────────────────────────────────────────────────────────────
%%
%% Simplified SRD cover:
%%   total — the sight line is blocked outright (cannot be targeted)
%%   half  — sight is clear, but a blocking square adjacent to the target
%%           stands nearer the attacker than the target does (an obstacle the
%%           target is tucked behind)
%%   none  — a clean look
%% Three-quarters cover is accepted by cover_ac_bonus/2 for completeness but
%% is not derived in v1 (arrow slits are the application's call).

grid_cover(Attacker, Target, total) :-
    \+ grid_los(Attacker, Target),
    !.
grid_cover(Attacker, Target, half) :-
    grid_pos(Attacker, XA, YA),
    grid_pos(Target, XT, YT),
    grid_blocked(BX, BY),
    abs(BX - XT) =< 1,
    abs(BY - YT) =< 1,
    DBlock is max(abs(BX - XA), abs(BY - YA)),
    DTarget is max(abs(XT - XA), abs(YT - YA)),
    DBlock < DTarget,
    !.
grid_cover(_, _, none).

cover_ac_bonus(none, 0).
cover_ac_bonus(half, 2).
cover_ac_bonus(three_quarters, 5).

%% ── Forced Movement ──────────────────────────────────────────────────────────
%%
%% The push square is one step directly away from the attacker along each
%% axis (a diagonal shove pushes diagonally). Blocked or occupied squares
%% stop the push — the predicate fails and the target holds its ground.

grid_push_dest(Attacker, Target, X, Y) :-
    grid_pos(Attacker, XA, YA),
    grid_pos(Target, XT, YT),
    X is XT + sign(XT - XA),
    Y is YT + sign(YT - YA),
    (   X =:= XT, Y =:= YT
    ->  fail   %% attacker and target share a square — no push direction
    ;   true
    ),
    \+ grid_blocked(X, Y),
    \+ grid_occupied(X, Y).

%% ── Bursts ───────────────────────────────────────────────────────────────────

grid_in_burst(CX, CY, Radius, E) :-
    grid_pos(E, X, Y),
    abs(X - CX) =< Radius,
    abs(Y - CY) =< Radius.
