%% Tether Module: compliance v1.0.0
%% Exports: compliant/2, violation/3, data_retention_ok/2,
%%          consent_required/2, consent_given/2

tether_module(compliance, '1.0.0', auto).

tether_export(compliance, 'compliant/2',          'compliant(Entity, Policy) — Entity satisfies all requirements of Policy').
tether_export(compliance, 'violation/3',           'violation(Entity, Policy, Reason) — Entity violates Policy for Reason').
tether_export(compliance, 'data_retention_ok/2',  'data_retention_ok(Record, Policy) — Record is within the retention window of Policy').
tether_export(compliance, 'consent_required/2',   'consent_required(Action, ConsentType) — ConsentType must be obtained before performing Action').
tether_export(compliance, 'consent_given/2',       'consent_given(Customer, ConsentType) — Customer has granted ConsentType consent').

%% ── Compliance Data Model ─────────────────────────────────────────────────────
%%
%% Policies and requirements:
%%   relation(gdpr, requires, marketing_consent)
%%   relation(gdpr, requires, data_minimization)
%%   relation(hipaa, requires, phi_encryption)
%%   relation(hipaa, requires, audit_log)
%%
%% Entity compliance attributes:
%%   attribute(customer_123, marketing_consent, true)
%%   attribute(customer_123, data_minimization, true)
%%   attribute(record_456,   phi_encryption,    true)
%%   attribute(system_789,   audit_log,         true)
%%
%% Data retention:
%%   attribute(gdpr,  retention_days, 2555)    %% 7 years
%%   attribute(hipaa, retention_days, 2190)    %% 6 years
%%   attribute(record_456, created_day,  20240101)   %% YYYYMMDD integer
%%   attribute(today, date, 20260510)
%%
%% Consent registry:
%%   relation(customer_123, granted_consent, marketing)
%%   relation(customer_123, granted_consent, analytics)
%%
%% Action → consent mapping:
%%   attribute(send_newsletter, requires_consent, marketing)
%%   attribute(track_behavior,  requires_consent, analytics)
%%
%% Region overrides:
%%   attribute(customer_123, region, eu)
%%   attribute(eu, stricter_than, standard)   %% eu rules apply extra requirements
%%   relation(eu_data_rules, requires, explicit_consent)

%% ── compliant/2 ───────────────────────────────────────────────────────────────

compliant(Entity, Policy) :-
    \+ violation(Entity, Policy, _).

%% ── violation/3 ───────────────────────────────────────────────────────────────

violation(Entity, Policy, missing_requirement(Req)) :-
    relation(Policy, requires, Req),
    \+ requirement_met(Entity, Req).

requirement_met(Entity, Req) :-
    attribute(Entity, Req, true).
requirement_met(Entity, Req) :-
    attribute(Entity, Req, Value),
    Value \= false,
    Value \= none,
    Value \= missing.

%% ── data_retention_ok/2 ───────────────────────────────────────────────────────

data_retention_ok(Record, Policy) :-
    attribute(Record, created_day, Created),
    attribute(today, date, Today),
    ( attribute(Policy, retention_days, Limit) -> true ; Limit = 2555 ),
    Age is Today - Created,
    Age =< Limit.

%% ── consent_required/2 ────────────────────────────────────────────────────────

consent_required(Action, ConsentType) :-
    attribute(Action, requires_consent, ConsentType).

%% ── consent_given/2 ───────────────────────────────────────────────────────────

consent_given(Customer, ConsentType) :-
    relation(Customer, granted_consent, ConsentType).
