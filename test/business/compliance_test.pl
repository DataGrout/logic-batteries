:- use_module(library(plunit)).

:- consult('../../modules/business/compliance/compliance').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_gdpr_policy :-
    assertz(relation(gdpr, requires, marketing_consent)),
    assertz(relation(gdpr, requires, data_minimization)).

setup_entity_fully_compliant :-
    assertz(attribute(customer_123, marketing_consent, true)),
    assertz(attribute(customer_123, data_minimization, true)).

setup_entity_missing_consent :-
    assertz(attribute(customer_123, data_minimization, true)).
    %% missing marketing_consent

setup_hipaa_policy :-
    assertz(relation(hipaa, requires, phi_encryption)),
    assertz(relation(hipaa, requires, audit_log)).

setup_system_hipaa_compliant :-
    assertz(attribute(system_789, phi_encryption, true)),
    assertz(attribute(system_789, audit_log, true)).

setup_today_date :-
    assertz(attribute(today, date, 20260510)).

setup_fresh_record :-
    assertz(attribute(record_456, created_day, 20260101)).

setup_old_record :-
    %% ~10 years old in simple approximation
    assertz(attribute(record_456, created_day, 20150101)).

setup_gdpr_retention :-
    assertz(attribute(gdpr, retention_days, 2555)).

setup_newsletter_consent :-
    assertz(attribute(send_newsletter, requires_consent, marketing)).

setup_customer_has_marketing_consent :-
    assertz(relation(customer_123, granted_consent, marketing)).

%% ── compliant/2 ───────────────────────────────────────────────────────────────

:- begin_tests(compliance_compliant).

test(entity_compliant_when_all_met, [setup((setup_gdpr_policy, setup_entity_fully_compliant)), cleanup(clear_facts)]) :-
    assertion(compliant(customer_123, gdpr)).

test(entity_not_compliant_when_missing, [setup((setup_gdpr_policy, setup_entity_missing_consent)), cleanup(clear_facts)]) :-
    assertion(\+ compliant(customer_123, gdpr)).

test(system_compliant_hipaa, [setup((setup_hipaa_policy, setup_system_hipaa_compliant)), cleanup(clear_facts)]) :-
    assertion(compliant(system_789, hipaa)).

:- end_tests(compliance_compliant).

%% ── violation/3 ───────────────────────────────────────────────────────────────

:- begin_tests(compliance_violations).

test(violation_missing_requirement, [setup((setup_gdpr_policy, setup_entity_missing_consent)), cleanup(clear_facts)]) :-
    violation(customer_123, gdpr, missing_requirement(marketing_consent)).

test(no_violation_when_met, [setup((setup_gdpr_policy, setup_entity_fully_compliant)), cleanup(clear_facts)]) :-
    assertion(\+ violation(customer_123, gdpr, _)).

:- end_tests(compliance_violations).

%% ── data_retention_ok/2 ───────────────────────────────────────────────────────

:- begin_tests(compliance_retention).

test(fresh_record_within_window, [setup((setup_today_date, setup_fresh_record, setup_gdpr_retention)), cleanup(clear_facts)]) :-
    assertion(data_retention_ok(record_456, gdpr)).

test(old_record_outside_window, [setup((setup_today_date, setup_old_record, setup_gdpr_retention)), cleanup(clear_facts)]) :-
    assertion(\+ data_retention_ok(record_456, gdpr)).

:- end_tests(compliance_retention).

%% ── consent_required/2 ────────────────────────────────────────────────────────

:- begin_tests(compliance_consent_required).

test(consent_required_for_action, [setup(setup_newsletter_consent), cleanup(clear_facts)]) :-
    consent_required(send_newsletter, marketing).

test(no_consent_required_for_unconfigured, [cleanup(clear_facts)]) :-
    assertion(\+ consent_required(read_article, _)).

:- end_tests(compliance_consent_required).

%% ── consent_given/2 ───────────────────────────────────────────────────────────

:- begin_tests(compliance_consent_given).

test(consent_given, [setup(setup_customer_has_marketing_consent), cleanup(clear_facts)]) :-
    assertion(consent_given(customer_123, marketing)).

test(consent_not_given, [cleanup(clear_facts)]) :-
    assertion(\+ consent_given(customer_123, marketing)).

:- end_tests(compliance_consent_given).
