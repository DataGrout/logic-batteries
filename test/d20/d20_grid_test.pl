:- use_module(library(plunit)).

%% d20-grid is standalone — no other battery required.
:- consult('../../modules/d20/d20-grid/d20_grid').

%% ── Setup predicates ─────────────────────────────────────────────────────────

clear_grid :-
    retractall(grid_pos(_, _, _)),
    retractall(grid_blocked(_, _)).

setup_pair :-
    assertz(grid_pos(archer, 1, 1)),
    assertz(grid_pos(orc, 5, 1)).

setup_pair_diagonal :-
    assertz(grid_pos(archer, 1, 1)),
    assertz(grid_pos(orc, 4, 4)).

setup_wall_between :-
    setup_pair,
    assertz(grid_blocked(3, 1)).

setup_wall_beside_line :-
    %% blocker off the sight line: LOS stays clear
    setup_pair,
    assertz(grid_blocked(3, 2)).

setup_target_tucked :-
    %% pillar adjacent to the target, nearer the archer: half cover, LOS clear
    assertz(grid_pos(archer, 1, 1)),
    assertz(grid_pos(orc, 6, 1)),
    assertz(grid_blocked(5, 2)).

setup_push_line :-
    assertz(grid_pos(fighter, 2, 2)),
    assertz(grid_pos(zombie, 3, 2)).

setup_push_into_wall :-
    setup_push_line,
    assertz(grid_blocked(4, 2)).

setup_push_into_ally :-
    setup_push_line,
    assertz(grid_pos(ghoul, 4, 2)).

setup_push_diagonal :-
    assertz(grid_pos(fighter, 2, 2)),
    assertz(grid_pos(zombie, 3, 3)).

setup_burst_field :-
    assertz(grid_pos(near, 5, 5)),
    assertz(grid_pos(edge, 7, 7)),
    assertz(grid_pos(far, 9, 5)).

setup_adjacent_wall_endpoints :-
    %% blockers on the endpoints themselves never blind anyone
    assertz(grid_pos(a, 1, 1)),
    assertz(grid_pos(b, 2, 2)),
    assertz(grid_blocked(1, 1)),
    assertz(grid_blocked(2, 2)).

:- begin_tests(d20_grid, [setup(clear_grid), cleanup(clear_grid)]).

%% ── Distance & range ─────────────────────────────────────────────────────────

test(chebyshev_straight, [setup(setup_pair), cleanup(clear_grid)]) :-
    grid_distance(archer, orc, 4).

test(chebyshev_diagonal_counts_one, [setup(setup_pair_diagonal), cleanup(clear_grid)]) :-
    grid_distance(archer, orc, 3).

test(adjacent_true_diagonally, [setup(setup_push_diagonal), cleanup(clear_grid)]) :-
    grid_adjacent(fighter, zombie).

test(in_range_boundary, [setup(setup_pair), cleanup(clear_grid)]) :-
    grid_in_range(archer, orc, 4),
    \+ grid_in_range(archer, orc, 3).

test(occupied, [setup(setup_pair), cleanup(clear_grid)]) :-
    grid_occupied(5, 1),
    \+ grid_occupied(9, 9).

%% ── Line of sight ────────────────────────────────────────────────────────────

test(los_clear_straight, [setup(setup_pair), cleanup(clear_grid)]) :-
    grid_los(archer, orc).

test(los_blocked_by_wall, [setup(setup_wall_between), cleanup(clear_grid)]) :-
    \+ grid_los(archer, orc).

test(los_ignores_offline_blocker, [setup(setup_wall_beside_line), cleanup(clear_grid)]) :-
    grid_los(archer, orc).

test(los_endpoints_never_block, [setup(setup_adjacent_wall_endpoints), cleanup(clear_grid)]) :-
    grid_los(a, b).

test(los_xy_raw_squares, [setup(setup_wall_between), cleanup(clear_grid)]) :-
    \+ grid_los_xy(1, 1, 5, 1),
    grid_los_xy(1, 3, 5, 3).

%% ── Cover ────────────────────────────────────────────────────────────────────

test(cover_none_on_clean_look, [setup(setup_pair), cleanup(clear_grid)]) :-
    grid_cover(archer, orc, none).

test(cover_total_when_sight_blocked, [setup(setup_wall_between), cleanup(clear_grid)]) :-
    grid_cover(archer, orc, total).

test(cover_half_when_tucked, [setup(setup_target_tucked), cleanup(clear_grid)]) :-
    grid_cover(archer, orc, half).

test(cover_ac_bonuses) :-
    cover_ac_bonus(none, 0),
    cover_ac_bonus(half, 2),
    cover_ac_bonus(three_quarters, 5),
    \+ cover_ac_bonus(total, _).

%% ── Forced movement ──────────────────────────────────────────────────────────

test(push_straight_away, [setup(setup_push_line), cleanup(clear_grid)]) :-
    grid_push_dest(fighter, zombie, 4, 2).

test(push_diagonal_away, [setup(setup_push_diagonal), cleanup(clear_grid)]) :-
    grid_push_dest(fighter, zombie, 4, 4).

test(push_stopped_by_wall, [setup(setup_push_into_wall), cleanup(clear_grid)]) :-
    \+ grid_push_dest(fighter, zombie, _, _).

test(push_stopped_by_body, [setup(setup_push_into_ally), cleanup(clear_grid)]) :-
    \+ grid_push_dest(fighter, zombie, _, _).

%% ── Bursts ───────────────────────────────────────────────────────────────────

test(burst_membership, [setup(setup_burst_field), cleanup(clear_grid)]) :-
    grid_in_burst(5, 5, 2, near),
    grid_in_burst(5, 5, 2, edge),
    \+ grid_in_burst(5, 5, 2, far).

test(burst_enumerates_all, [setup(setup_burst_field), cleanup(clear_grid)]) :-
    findall(E, grid_in_burst(5, 5, 4, E), Es),
    sort(Es, [edge, far, near]).

:- end_tests(d20_grid).
