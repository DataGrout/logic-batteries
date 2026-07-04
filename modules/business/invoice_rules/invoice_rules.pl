%% Battery: invoice_rules v1.0.0
%% Exports: invoice_overdue/1, days_overdue/2, late_fee/2,
%%          escalation_level/2, payment_due_amount/2

battery_module(invoice_rules, '1.0.0', auto).

battery_export(invoice_rules, 'invoice_overdue/1',     'invoice_overdue(Invoice) — Invoice is past its due date').
battery_export(invoice_rules, 'days_overdue/2',        'days_overdue(Invoice, Days) — Invoice is Days days past due (0 if not overdue)').
battery_export(invoice_rules, 'late_fee/2',            'late_fee(Invoice, Fee) — Fee is the late charge added to Invoice''s balance').
battery_export(invoice_rules, 'escalation_level/2',    'escalation_level(Invoice, Level) — Level is reminder/warning/collections based on days overdue').
battery_export(invoice_rules, 'payment_due_amount/2',  'payment_due_amount(Invoice, Amount) — total amount now due including any late fee').

%% ── Invoice Data Model ────────────────────────────────────────────────────────
%%
%% Invoice facts:
%%   attribute(inv_001, amount,    1500)
%%   attribute(inv_001, due_day,   10)     %% day-of-period (1–31)
%%   attribute(inv_001, due_month, 3)
%%   attribute(inv_001, due_year,  2026)
%%   attribute(inv_001, paid,      false)
%%
%% Current date (assert at runtime):
%%   attribute(today, day,   25)
%%   attribute(today, month, 4)
%%   attribute(today, year,  2026)
%%
%% Late fee configuration:
%%   attribute(billing, late_fee_flat,    50)     %% flat fee (default)
%%   attribute(billing, late_fee_pct,     0.015)  %% percentage of amount (alternative)
%%   attribute(billing, late_fee_cap,     200)    %% max late fee
%%
%% Escalation thresholds:
%%   attribute(billing, warning_days,     15)     %% default
%%   attribute(billing, collections_days, 60)     %% default

%% ── Date arithmetic ──────────────────────────────────────────────────────────
%%
%% For production use, assert precomputed absolute day counts to avoid the
%% month-approximation error in date_to_days/4 (which treats all months as 30
%% days). The absolute_days / due_absolute_days facts take priority.
%%
%%   attribute(today,   absolute_days,    738970)   %% days since any epoch
%%   attribute(inv_001, due_absolute_days, 738924)

date_to_days(Y, M, D, Days) :-
    Days is Y * 365 + M * 30 + D.

today_days(Days) :-
    attribute(today, absolute_days, Days), !.
today_days(Days) :-
    attribute(today, year,  Y),
    attribute(today, month, Mo),
    attribute(today, day,   D),
    date_to_days(Y, Mo, D, Days).

due_days(Invoice, Days) :-
    attribute(Invoice, due_absolute_days, Days), !.
due_days(Invoice, Days) :-
    attribute(Invoice, due_year,  Y),
    attribute(Invoice, due_month, Mo),
    attribute(Invoice, due_day,   D),
    date_to_days(Y, Mo, D, Days).

%% invoice_overdue(+Invoice)
invoice_overdue(Invoice) :-
    \+ attribute(Invoice, paid, true),
    today_days(Today),
    due_days(Invoice, Due),
    Today > Due.

%% days_overdue(+Invoice, -Days)
days_overdue(Invoice, Days) :-
    invoice_overdue(Invoice), !,
    today_days(Today),
    due_days(Invoice, Due),
    Days is Today - Due.
days_overdue(_, 0).

%% late_fee(+Invoice, -Fee)
late_fee(Invoice, Fee) :-
    invoice_overdue(Invoice), !,
    attribute(Invoice, amount, Amount),
    ( attribute(billing, late_fee_pct, Pct)
      -> Raw is round(Amount * Pct)
      ;  ( attribute(billing, late_fee_flat, Flat) -> Raw = Flat ; Raw = 50 ) ),
    ( attribute(billing, late_fee_cap, Cap)
      -> Fee is min(Raw, Cap)
      ;  Fee = Raw ).
late_fee(_, 0).

%% escalation_level(+Invoice, -Level)
escalation_level(Invoice, collections) :-
    days_overdue(Invoice, D),
    ( attribute(billing, collections_days, T) -> true ; T = 60 ),
    D >= T, !.
escalation_level(Invoice, warning) :-
    days_overdue(Invoice, D),
    ( attribute(billing, warning_days, T) -> true ; T = 15 ),
    D >= T, !.
escalation_level(Invoice, reminder) :-
    invoice_overdue(Invoice), !.
escalation_level(_, current).

%% payment_due_amount(+Invoice, -Amount)
payment_due_amount(Invoice, Amount) :-
    attribute(Invoice, amount, Base),
    late_fee(Invoice, Fee),
    Amount is Base + Fee.
