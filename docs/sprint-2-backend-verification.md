# Sprint 2 backend verification

Date: October 31, 2026. Review base: `d243edf` on `feature/backend` after syncing
`origin/dev`. This change set covers the remaining Sprint 2 backend deliverables.

## Deliverables

| Ticket | Delivered behavior |
|---|---|
| CCVO-6 | Authentication already merged through PR #5 |
| CCVO-5 | Authenticated profile read/update, protected identity/role/status fields |
| CCVO-7 | HelpRequest model, constraints, private-table grants, additive/reversible migration |
| CCVO-8 | Authenticated request creation, owner assignment, concurrent safe retries |
| CCVO-9 | Active nearby feed, selected/manual search center, bounded pagination, approximate location |
| CCVO-35 | Details, owner edits, completion/cancellation, closed-state/feed behavior |

Offers and messaging remain backlog scope. Flutter integration is a separate
team handoff; these results do not claim a completed mobile walkthrough.

## Automated verification

With the README's disposable PostgreSQL environment configured:

```powershell
Set-Location backend
.\.venv\Scripts\python.exe -m pytest -q
```

Result: **272 passed**. Coverage includes signed tokens, profile persistence,
input and ownership failures, schema constraints/foreign keys, concurrent retry
races, failed-commit rollback, exact radius boundaries, dateline/poles, stable
pagination, closed-request visibility and transitions, safe errors and request logs.
The final suite includes regressions proving two points in the same public
coordinate cell cannot be distinguished by distance/order/radius probes, plus
half-tie rounding agreement between PostgreSQL and JSON responses. Profile
provisioning and update outages return generic 503 responses; a failed profile
save rolls back its changes.
Migration tests downgrade/reapply the new revision while preserving users, and
exercise full-base rebuild plus Alembic metadata comparison on disposable data.

Final cleanup verification: **272 tests passed** and **13 real HTTP checks passed**.
Ruff lint passes for the complete backend (`app`, `tests`, `alembic`, and
`scripts`); all **47 Python files** pass the formatter check. `pip check` reports
no broken requirements, and `git diff --check` passes.

The final cleanup removed the unused `app/core/database.py` and
`app/core/migration_engine.py` helpers. Runtime connections use
`app/database/session.py`; Alembic uses its existing explicit migration connection.
The removed helpers had no repository callers and represented an older,
inconsistent connection path. Versioned migrations and repeatable verification
tools are retained; the temporary implementation plan was removed.

## Real HTTP integration verification

```powershell
.\.venv\Scripts\python.exe -m scripts.verify_sprint2
```

Result: **13 checks passed** using real loopback HTTP and PostgreSQL. Verified:

- Profile read/update through the running backend.
- Request creation and a duplicate retry returning the same owned record.
- Conflicting retry rejected with 409.
- Another user reads approximate location but cannot close the owner's request.
- Owner edit survives a subsequent read.
- Active nearby feed includes the request; completion/cancellation remove it.
- Closed-state retry is safe; reopen and closed edits return 409.
- PostgreSQL confirms exactly two persisted closed requests before cleanup.

The smoke check uses locally generated disposable JWTs and a local JWKS server.
It does not bypass signature/issuer/audience verification. Test rows are removed
afterward, including when an assertion fails. It does not touch hosted data.

Earlier real Supabase sign-in/profile verification passed 13 checks on October 30:
hosted token acceptance, profile identity linkage, hosted persistence, single
profile creation, rejected invalid access/protected fields, and restoration of
the original test-profile display name. That evidence predates the request
migration and does not claim hosted request integration.

## Review and release handoff

Independent review found one actionable location-privacy issue: public radius
filtering initially used raw coordinates before response rounding. It is fixed:
filtering, ordering, and distance all use the same public approximate coordinate
cell. The added regressions failed before the fix and passed afterward. Canonical
half-up rounding, including near-half values, is consistent between SQL and Python.
The complete suite and HTTP smoke flow were rerun after the fix.

The new request migration remains unapplied to hosted Supabase. Before using
request routes against that project, review/apply `cbcaea6d1d8d` using the
migration connection and grant the separate runtime role the documented rights
if applicable. Never downgrade a shared database for verification.

Review the canonical category/urgency values, limits, idempotency behavior,
approximate-location policy, and Flutter JSON examples in `backend/README.md`.
This combined change set targets `dev` from `feature/backend`. Teammate review
precedes merge. API completion does not imply Flutter integration or a hosted
request migration has been completed.
