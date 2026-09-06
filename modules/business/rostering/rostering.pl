%% Battery: rostering v1.0.0
%% Requires: duty, assign
%% Exports: coverage/3, coverage_gap/3, understaffed/1, overstaffed/3,
%%          incompatible_shifts/3, roster_violation/3, roster_valid/1,
%%          candidates/3, candidate_score/3, rank_candidates/3,
%%          fill_shift/3, propose_roster/2, propose_roster/3,
%%          replacement_for/3, swap_valid/4, assigned_load/4,
%%          load_imbalance/5, roster_model/2

:- dynamic(relation/3).
:- dynamic(attribute/3).

battery_module(rostering, '1.0.0', auto).

battery_export(rostering, 'coverage/3',
    'coverage(Shift, Role, Have) — how many workers with Role are assigned to Shift, for each Role the shift needs').
battery_export(rostering, 'coverage_gap/3',
    'coverage_gap(Shift, Role, Missing) — Shift needs Missing more workers with Role (Missing > 0)').
battery_export(rostering, 'understaffed/1',
    'understaffed(Shift) — Shift has at least one coverage gap').
battery_export(rostering, 'overstaffed/3',
    'overstaffed(Shift, Role, Extra) — Shift has Extra more workers with Role than it needs (Extra > 0)').
battery_export(rostering, 'incompatible_shifts/3',
    'incompatible_shifts(Worker, Shift1, Shift2) — the same worker cannot take both: the shifts overlap, or the rest between them is below the worker''s min_rest (from the duty battery)').
battery_export(rostering, 'roster_violation/3',
    'roster_violation(Shift, Worker, Reason) — an assigned worker who should not be: any duty unfit_reason term, clash(OtherShift) for an incompatible second assignment, or role_not_needed(Role)').
battery_export(rostering, 'roster_valid/1',
    'roster_valid(Shifts) — no shift in the list has a violation or a coverage gap').
battery_export(rostering, 'candidates/3',
    'candidates(Shift, Role, Workers) — rostered workers with Role who are fit for Shift (duty battery) and not already on Shift or on an incompatible assigned shift; in roster order').
battery_export(rostering, 'candidate_score/3',
    'candidate_score(Shift, Worker, Score) — ranking key k(PrefRank, NegHeadroom, Load, NegSeniority): prefers=0/none=1/avoids=2, then more duty headroom, then fewer assigned shifts in the rolling window, then seniority; lower sorts first').
battery_export(rostering, 'rank_candidates/3',
    'rank_candidates(Shift, Role, Ranked) — candidates ordered best first by candidate_score/3').
battery_export(rostering, 'fill_shift/3',
    'fill_shift(Shift, Role, Picks) — the best-ranked candidates for the current coverage gap of Role on Shift, as a list (empty when there is no gap); nothing is asserted').
battery_export(rostering, 'propose_roster/2',
    'propose_roster(Shifts, Proposal) — greedy fill of every gap across Shifts in start order, honouring incompatibility between proposed picks; Proposal is a list of Shift-Worker pairs to assert').
battery_export(rostering, 'propose_roster/3',
    'propose_roster(Shifts, Proposal, Unfilled) — as propose_roster/2, plus Unfilled as a list of Shift-Role-Missing for gaps no candidate could cover').
battery_export(rostering, 'replacement_for/3',
    'replacement_for(Shift, Worker, Candidate) — best-first replacements for an assigned worker who drops out, same role').
battery_export(rostering, 'swap_valid/4',
    'swap_valid(Worker1, Shift1, Worker2, Shift2) — two assigned workers may trade shifts: each is fit for the other''s shift, fills a needed role there, and stays compatible with their other assignments').
battery_export(rostering, 'assigned_load/4',
    'assigned_load(Worker, WindowStart, WindowEnd, Total) — assigned shift time inside a window, clipped at the edges').
battery_export(rostering, 'load_imbalance/5',
    'load_imbalance(Role, WindowStart, WindowEnd, Max, Min) — heaviest and lightest assigned load among workers with Role in the window').
battery_export(rostering, 'roster_model/2',
    'roster_model(Shifts, Facts) — the assign battery model for the open slots of Shifts: one slot per missing seat with attribute(Slot, domain, Candidates), relation(Slot, slot_of, Shift), attribute(Slot, seat, Role), relation(Shift, distinct, Slot); assert them, add the two hook clauses from the README, and call assign_solve').

%% ── Data model ───────────────────────────────────────────────────────────────
%%
%% Shifts are duty-battery tasks with a window and one or more seat
%% requirements. Assignments are relations. Preferences are optional.
%%
%%   attribute(sh_mon_am, start, 480).  attribute(sh_mon_am, end, 1080).
%%   relation(sh_mon_am, needs, req_1).
%%   attribute(req_1, seat, nurse).     attribute(req_1, count, 2).
%%   relation(sh_mon_am, needs, req_2).
%%   attribute(req_2, seat, orderly).   attribute(req_2, count, 1).
%%   relation(sh_mon_am, requires, acls).          %% duty: qualification kinds
%%
%%   relation(sh_mon_am, assigned, alvarez).       %% an assignment
%%
%%   relation(alvarez, prefers, sh_mon_am).        %% optional
%%   relation(chen, avoids, sh_mon_am).            %% optional
%%   attribute(chen, seniority, 7).                %% optional
%%
%% Everything about a worker's legality (roles, committed duty periods,
%% unavailability, policy limits, qualifications) is the duty battery's data
%% model and is consulted through fit_for_duty/4, unfit_reason/5,
%% duty_limit/3 and duty_headroom/3. Time is the same integer timeline, and
%% intervals are half-open [Start, End) exactly as in duty and temporal.

%% ── Shifts, seats, coverage ──────────────────────────────────────────────────

rostering_shift(Shift) :-
    attribute(Shift, start, _),
    attribute(Shift, end, _),
    relation(Shift, needs, _).

rostering_window(Shift, S, E) :-
    attribute(Shift, start, S),
    attribute(Shift, end, E).

%% A requirement names the seat's role as `seat`, never `role`: `role` is the
%% duty battery's worker attribute, and sharing the name would let requirement
%% entities masquerade as workers.
rostering_seat(Shift, Role, Count) :-
    relation(Shift, needs, Req),
    attribute(Req, seat, Role),
    attribute(Req, count, Count).

rostering_needs_role(Shift, Role) :-
    relation(Shift, needs, Req),
    attribute(Req, seat, Role).

coverage(Shift, Role, Have) :-
    rostering_needs_role(Shift, Role),
    findall(W, ( relation(Shift, assigned, W), attribute(W, role, Role) ), Ws),
    length(Ws, Have).

coverage_gap(Shift, Role, Missing) :-
    rostering_seat(Shift, Role, Need),
    coverage(Shift, Role, Have),
    Missing is Need - Have,
    Missing > 0.

understaffed(Shift) :-
    rostering_shift(Shift),
    \+ \+ coverage_gap(Shift, _, _).

overstaffed(Shift, Role, Extra) :-
    rostering_seat(Shift, Role, Need),
    coverage(Shift, Role, Have),
    Extra is Have - Need,
    Extra > 0.

%% ── Compatibility between two shifts for one worker ─────────────────────────

rostering_overlaps(S1, E1, S2, E2) :-
    S1 < E2,
    E1 > S2.

%% Rest between two non-overlapping windows, whichever order they occur in.
rostering_gap(S1, E1, S2, E2, Gap) :-
    (   E1 =< S2
    ->  Gap is S2 - E1
    ;   Gap is S1 - E2
    ).

incompatible_shifts(Worker, Shift1, Shift2) :-
    Shift1 \== Shift2,
    rostering_window(Shift1, S1, E1),
    rostering_window(Shift2, S2, E2),
    (   rostering_overlaps(S1, E1, S2, E2)
    ->  true
    ;   duty_limit(Worker, min_rest, Min),
        rostering_gap(S1, E1, S2, E2, Gap),
        Gap < Min
    ).

%% ── Violations over the current assignments ─────────────────────────────────

roster_violation(Shift, Worker, Reason) :-
    relation(Shift, assigned, Worker),
    rostering_window(Shift, S, E),
    unfit_reason(Worker, Shift, S, E, Reason).
roster_violation(Shift, Worker, clash(Other)) :-
    relation(Shift, assigned, Worker),
    relation(Other, assigned, Worker),
    incompatible_shifts(Worker, Shift, Other).
roster_violation(Shift, Worker, role_not_needed(Role)) :-
    relation(Shift, assigned, Worker),
    attribute(Worker, role, Role),
    \+ rostering_needs_role(Shift, Role).

roster_valid(Shifts) :-
    \+ ( member(Shift, Shifts), roster_violation(Shift, _, _) ),
    \+ ( member(Shift, Shifts), coverage_gap(Shift, _, _) ).

%% ── Candidates ───────────────────────────────────────────────────────────────
%%
%% Extra is a list of Shift-Worker pairs treated as if already assigned: the
%% proposals accumulated so far by propose_roster/3.

rostering_assigned(Shift, Worker, Extra) :-
    (   relation(Shift, assigned, Worker)
    ;   member(Shift-Worker, Extra)
    ).

rostering_clash(Worker, Shift, Extra) :-
    rostering_assigned(Other, Worker, Extra),
    Other \== Shift,
    incompatible_shifts(Worker, Shift, Other).

rostering_candidate(Shift, Role, Extra, Worker) :-
    rostering_window(Shift, S, E),
    attribute(Worker, role, Role),
    \+ rostering_assigned(Shift, Worker, Extra),
    fit_for_duty(Worker, Shift, S, E),
    \+ rostering_clash(Worker, Shift, Extra).

rostering_candidates(Shift, Role, Extra, Workers) :-
    findall(W, rostering_candidate(Shift, Role, Extra, W), Workers).

candidates(Shift, Role, Workers) :-
    rostering_candidates(Shift, Role, [], Workers).

%% ── Ranking ──────────────────────────────────────────────────────────────────
%%
%% The score is a key tuple compared by standard order, so it needs no
%% weights and no unit assumptions: preference class first, then headroom
%% (more is better), then load (fewer assigned shifts in the rolling window
%% is better), then seniority (more is better).

rostering_pref_rank(Shift, Worker, Rank) :-
    (   relation(Worker, prefers, Shift) -> Rank = 0
    ;   relation(Worker, avoids, Shift)  -> Rank = 2
    ;   Rank = 1
    ).

rostering_headroom(Shift, Worker, H) :-
    rostering_window(Shift, _, E),
    (   duty_headroom(Worker, E, H0) -> H = H0 ; H = 0 ).

%% Assigned shifts of Worker inside the rolling window ending at the shift's
%% end (all assigned shifts when no rolling_window is configured).
rostering_load(Shift, Worker, Extra, Load) :-
    rostering_window(Shift, _, E),
    (   duty_limit(Worker, rolling_window, Win)
    ->  WS is E - Win
    ;   WS = none
    ),
    findall(O,
        ( rostering_assigned(O, Worker, Extra),
          rostering_window(O, OS, _),
          ( WS == none -> true ; OS >= WS ) ),
        Os),
    length(Os, Load).

rostering_seniority(Worker, S) :-
    (   attribute(Worker, seniority, S0) -> S = S0 ; S = 0 ).

rostering_score(Shift, Worker, Extra, k(Pref, NegH, Load, NegSen)) :-
    rostering_pref_rank(Shift, Worker, Pref),
    rostering_headroom(Shift, Worker, H),
    NegH is -H,
    rostering_load(Shift, Worker, Extra, Load),
    rostering_seniority(Worker, Sen),
    NegSen is -Sen.

candidate_score(Shift, Worker, Score) :-
    rostering_score(Shift, Worker, [], Score).

rostering_rank(Shift, Role, Extra, Ranked) :-
    rostering_candidates(Shift, Role, Extra, Ws),
    findall(Key-W, ( member(W, Ws), rostering_score(Shift, W, Extra, Key) ), Keyed),
    sort(Keyed, Sorted),                   %% sort/2 is ISO and on both engines
    rostering_strip_keys(Sorted, Ranked).

rostering_strip_keys([], []).
rostering_strip_keys([_-W|Ps], [W|Ws]) :- rostering_strip_keys(Ps, Ws).

rank_candidates(Shift, Role, Ranked) :-
    rostering_rank(Shift, Role, [], Ranked).

%% ── Filling ──────────────────────────────────────────────────────────────────

rostering_take(0, _, []) :- !.
rostering_take(_, [], []) :- !.
rostering_take(N, [X|Xs], [X|Ys]) :-
    N1 is N - 1,
    rostering_take(N1, Xs, Ys).

fill_shift(Shift, Role, Picks) :-
    (   coverage_gap(Shift, Role, Missing)
    ->  rank_candidates(Shift, Role, Ranked),
        rostering_take(Missing, Ranked, Picks)
    ;   Picks = []
    ).

%% Missing seats for Role on Shift counting proposals already made.
rostering_open_seats(Shift, Role, Extra, Missing) :-
    rostering_seat(Shift, Role, Need),
    findall(W, ( rostering_assigned(Shift, W, Extra), attribute(W, role, Role) ), Ws),
    length(Ws, Have),
    Missing is Need - Have,
    Missing > 0.

propose_roster(Shifts, Proposal) :-
    propose_roster(Shifts, Proposal, _).

propose_roster(Shifts, Proposal, Unfilled) :-
    findall(S-Sh, ( member(Sh, Shifts), attribute(Sh, start, S) ), Keyed),
    sort(Keyed, Sorted),
    rostering_strip_keys(Sorted, Ordered),
    rostering_propose(Ordered, [], Proposal, [], Unfilled).

rostering_propose([], Acc, Acc, Unf, Unfilled) :-
    reverse(Unf, Unfilled).
rostering_propose([Shift|Rest], Acc, Proposal, Unf0, Unfilled) :-
    findall(Role, rostering_needs_role(Shift, Role), Roles0),
    sort(Roles0, Roles),
    rostering_propose_roles(Roles, Shift, Acc, Acc1, Unf0, Unf1),
    rostering_propose(Rest, Acc1, Proposal, Unf1, Unfilled).

rostering_propose_roles([], _, Acc, Acc, Unf, Unf).
rostering_propose_roles([Role|Roles], Shift, Acc0, Acc, Unf0, Unf) :-
    (   rostering_open_seats(Shift, Role, Acc0, Missing)
    ->  rostering_rank(Shift, Role, Acc0, Ranked),
        rostering_take(Missing, Ranked, Picks),
        rostering_pairs(Picks, Shift, Pairs),
        append(Acc0, Pairs, Acc1),
        length(Picks, Got),
        Left is Missing - Got,
        (   Left > 0 -> Unf1 = [Shift-Role-Left|Unf0] ; Unf1 = Unf0 )
    ;   Acc1 = Acc0, Unf1 = Unf0
    ),
    rostering_propose_roles(Roles, Shift, Acc1, Acc, Unf1, Unf).

rostering_pairs([], _, []).
rostering_pairs([W|Ws], Shift, [Shift-W|Ps]) :- rostering_pairs(Ws, Shift, Ps).

%% ── Changes: replacements and swaps ──────────────────────────────────────────

replacement_for(Shift, Worker, Candidate) :-
    relation(Shift, assigned, Worker),
    attribute(Worker, role, Role),
    rank_candidates(Shift, Role, Ranked),
    member(Candidate, Ranked).

%% Worker may take Shift given that Leaving is the assignment being given up.
rostering_can_take(Worker, Shift, Leaving) :-
    attribute(Worker, role, Role),
    rostering_needs_role(Shift, Role),
    rostering_window(Shift, S, E),
    fit_for_duty(Worker, Shift, S, E),
    \+ ( relation(Other, assigned, Worker),
         Other \== Leaving,
         Other \== Shift,
         incompatible_shifts(Worker, Shift, Other) ).

swap_valid(Worker1, Shift1, Worker2, Shift2) :-
    Shift1 \== Shift2,
    Worker1 \== Worker2,
    relation(Shift1, assigned, Worker1),
    relation(Shift2, assigned, Worker2),
    rostering_can_take(Worker1, Shift2, Shift1),
    rostering_can_take(Worker2, Shift1, Shift2).

%% ── Load and fairness ────────────────────────────────────────────────────────

rostering_clipped(S, E, WS, WE, Len) :-
    CS is max(S, WS),
    CE is min(E, WE),
    Len is max(0, CE - CS).

assigned_load(Worker, WS, WE, Total) :-
    findall(Len,
        ( relation(Shift, assigned, Worker),
          rostering_window(Shift, S, E),
          rostering_clipped(S, E, WS, WE, Len) ),
        Lens),
    sum_list(Lens, Total).

load_imbalance(Role, WS, WE, Max, Min) :-
    findall(L, ( attribute(W, role, Role), assigned_load(W, WS, WE, L) ), Ls),
    Ls = [_|_],
    sort(Ls, Asc),                         %% ascending; dropped duplicates do not move the ends
    Asc = [Min|_],
    reverse(Asc, [Max|_]).

%% ── The assign model for open seats ──────────────────────────────────────────
%%
%% One slot per missing seat. Slots of the same shift form a distinct group so
%% no worker fills two seats on one shift. Candidates are computed against the
%% current assignments only; cross-shift compatibility is the pair hook's job
%% (see README), because it depends on which values the search picks.

roster_model(Shifts, Facts) :-
    findall(F, ( member(Shift, Shifts), rostering_slot_fact(Shift, F) ), Facts).

rostering_slot_fact(Shift, Fact) :-
    coverage_gap(Shift, Role, Missing),
    candidates(Shift, Role, Cands),
    rostering_count_up(1, Missing, I),
    rostering_slot_name(Shift, Role, I, Slot),
    (   Fact = attribute(Slot, domain, Cands)
    ;   Fact = relation(Slot, slot_of, Shift)
    ;   Fact = attribute(Slot, seat, Role)
    ;   Fact = relation(Shift, distinct, Slot)
    ).

rostering_count_up(I, N, I) :- I =< N.
rostering_count_up(I, N, J) :- I < N, I1 is I + 1, rostering_count_up(I1, N, J).

rostering_slot_name(Shift, Role, I, Slot) :-
    number_codes(I, Cs),
    atom_codes(IA, Cs),
    atom_concat(Shift, '_', A1),
    atom_concat(A1, Role, A2),
    atom_concat(A2, '_', A3),
    atom_concat(A3, IA, Slot).
