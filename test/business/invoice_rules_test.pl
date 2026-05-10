:- use_module(library(plunit)).

:- consult('../../modules/business/invoice_rules/invoice_rules').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_today_april_25 :-
    assertz(attribute(today, year,  2026)),
    assertz(attribute(today, month, 4)),
    assertz(attribute(today, day,   25)).

setup_overdue_invoice :-
    %% Due March 10, today is April 25 → overdue
    assertz(attribute(inv_001, amount,    1500)),
    assertz(attribute(inv_001, due_year,  2026)),
    assertz(attribute(inv_001, due_month, 3)),
    assertz(attribute(inv_001, due_day,   10)),
    assertz(attribute(inv_001, paid,      false)).

setup_current_invoice :-
    %% Due April 30, today is April 25 → not overdue
    assertz(attribute(inv_002, amount,    500)),
    assertz(attribute(inv_002, due_year,  2026)),
    assertz(attribute(inv_002, due_month, 4)),
    assertz(attribute(inv_002, due_day,   30)).

setup_paid_invoice :-
    setup_overdue_invoice,
    retractall(attribute(inv_001, paid, false)),
    assertz(attribute(inv_001, paid, true)).

setup_billing_flat_fee :-
    assertz(attribute(billing, late_fee_flat, 50)).

setup_billing_pct_fee :-
    assertz(attribute(billing, late_fee_pct, 0.01)).

setup_billing_pct_with_cap :-
    assertz(attribute(billing, late_fee_pct, 0.1)),
    assertz(attribute(billing, late_fee_cap, 100)).

setup_escalation_thresholds :-
    assertz(attribute(billing, warning_days,     15)),
    assertz(attribute(billing, collections_days, 60)).

%% Days overdue from March 10 to April 25 (using Y*365+M*30+D approximation):
%% Due  = 2026*365 + 3*30  + 10 = 739490 + 90  + 10  = 739590
%% Today= 2026*365 + 4*30  + 25 = 739490 + 120 + 25  = 739635
%% Diff = 45 days

%% ── invoice_overdue/1 ─────────────────────────────────────────────────────────

:- begin_tests(invoice_overdue).

test(overdue_invoice, [setup((setup_today_april_25, setup_overdue_invoice)), cleanup(clear_facts)]) :-
    assertion(invoice_overdue(inv_001)).

test(current_not_overdue, [setup((setup_today_april_25, setup_current_invoice)), cleanup(clear_facts)]) :-
    assertion(\+ invoice_overdue(inv_002)).

test(paid_not_overdue, [setup((setup_today_april_25, setup_paid_invoice)), cleanup(clear_facts)]) :-
    assertion(\+ invoice_overdue(inv_001)).

:- end_tests(invoice_overdue).

%% ── days_overdue/2 ───────────────────────────────────────────────────────────

:- begin_tests(invoice_days_overdue).

test(days_overdue_computed, [setup((setup_today_april_25, setup_overdue_invoice)), cleanup(clear_facts)]) :-
    days_overdue(inv_001, D), assertion(D == 45).

test(current_invoice_zero_days, [setup((setup_today_april_25, setup_current_invoice)), cleanup(clear_facts)]) :-
    days_overdue(inv_002, D), assertion(D == 0).

:- end_tests(invoice_days_overdue).

%% ── late_fee/2 ───────────────────────────────────────────────────────────────

:- begin_tests(invoice_late_fee).

test(flat_fee, [setup((setup_today_april_25, setup_overdue_invoice, setup_billing_flat_fee)), cleanup(clear_facts)]) :-
    late_fee(inv_001, F), assertion(F == 50).

test(pct_fee, [setup((setup_today_april_25, setup_overdue_invoice, setup_billing_pct_fee)), cleanup(clear_facts)]) :-
    %% round(1500 * 0.01) = 15
    late_fee(inv_001, F), assertion(F == 15).

test(pct_fee_with_cap, [setup((setup_today_april_25, setup_overdue_invoice, setup_billing_pct_with_cap)), cleanup(clear_facts)]) :-
    %% round(1500 * 0.1) = 150, capped at 100
    late_fee(inv_001, F), assertion(F == 100).

test(current_invoice_no_fee, [setup((setup_today_april_25, setup_current_invoice)), cleanup(clear_facts)]) :-
    late_fee(inv_002, F), assertion(F == 0).

:- end_tests(invoice_late_fee).

%% ── escalation_level/2 ───────────────────────────────────────────────────────

:- begin_tests(invoice_escalation).

test(reminder_level, [setup((setup_today_april_25, setup_overdue_invoice, setup_escalation_thresholds)), cleanup(clear_facts)]) :-
    %% 45 days > 15 warning threshold → warning
    escalation_level(inv_001, L), assertion(L == warning).

test(current_is_current, [setup((setup_today_april_25, setup_current_invoice)), cleanup(clear_facts)]) :-
    escalation_level(inv_002, L), assertion(L == current).

:- end_tests(invoice_escalation).

%% ── payment_due_amount/2 ─────────────────────────────────────────────────────

:- begin_tests(invoice_payment_due).

test(total_with_flat_fee, [setup((setup_today_april_25, setup_overdue_invoice, setup_billing_flat_fee)), cleanup(clear_facts)]) :-
    payment_due_amount(inv_001, A), assertion(A == 1550).

test(total_current_no_fee, [setup((setup_today_april_25, setup_current_invoice)), cleanup(clear_facts)]) :-
    payment_due_amount(inv_002, A), assertion(A == 500).

:- end_tests(invoice_payment_due).
