# Village Outreach backend

This backend contains the FastAPI health endpoint, SQLAlchemy User profile,
PostgreSQL connection/session helpers, Alembic migration, and initial tests.
CCVO-6 adds Supabase access-token verification and application-profile provisioning
as reusable dependencies. Profile and request endpoints follow in their own tickets.

## Set up Python

Run these PowerShell commands from `backend` with Python 3.13 installed:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r tests/requirements.txt
.\.venv\Scripts\python.exe -m pip check
```

`requirements.txt` contains runtime dependencies; `tests/requirements.txt` adds
the test tools. Both use the pinned resolution in `constraints.txt`.
For a runtime-only installation, install `requirements.txt`.

Start the API:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

`GET http://127.0.0.1:8000/health` returns HTTP 200 with `{"status":"ok"}`.
The OpenAPI description is at `/openapi.json` and interactive docs at `/docs`.
Startup and health do not require database credentials and never run migrations.

## Development Supabase connection

Copy `.env.example` to `.env` and replace the placeholders with the isolated
development project's connection settings. Keep `.env` out of Git and chat.

- `DATABASE_URL`: backend runtime connection, normally the Supabase transaction
  pooler on port 6543. Copy its actual host and username from the Connect panel.
- `MIGRATION_DATABASE_URL`: direct PostgreSQL connection, or the session pooler
  on port 5432 when the direct IPv6 endpoint is unreachable. Alembic never falls
  back to the runtime URL and rejects the standard transaction-pooler port.
- Use `postgresql+psycopg://` URLs, percent-encode reserved password characters,
  and retain `sslmode=require` for hosted connections.
- Keep production credentials separate. Flutter receives neither database URL.

The engine uses psycopg 3 with automatic prepared statements disabled and
SQLAlchemy `NullPool`, so Supabase owns runtime pooling. Connection attempts
time out after five seconds. `session_scope()` rolls back pending work and
closes the session on both success and failure. Callers explicitly commit writes.

Run the read-only development connectivity check:

```powershell
.\.venv\Scripts\python.exe -m app.database.check
```

Success prints `Database connection check passed (SELECT 1).` and exits 0.
Failure exits 1 with a generic message and no credentials or traceback. The
command refuses `ENVIRONMENT=production`.

## User identity contract — CCVO-4

The final SDD Figure 4 maps to `app_private.users`:

| Field | Contract |
|---|---|
| `id` | UUID application primary key, generated on insert |
| `supabase_uid` | Required, unique UUID matching Supabase Auth's verified subject |
| `email` | Required profile email, 1–254 trimmed characters; not an identity key |
| `display_name` | Required, 1–100 trimmed characters |
| `role` | `neighbor` by default; `moderator` and `admin` reserved for server-controlled assignment |
| `status` | `active` by default; `inactive` or `suspended` |
| `created_at` | Server-generated timezone-aware timestamp |
| `updated_at` | Server default; SQLAlchemy-managed updates refresh this timestamp |

ORM timestamps normalize to UTC even if the PostgreSQL server uses another
timezone. Direct SQL writers must maintain `updated_at` themselves. Passwords
and password hashes are not application columns.

The SDD does not enumerate role/status values or text limits. The values above
are initial implementation choices for team review. There is no foreign key to
the hosted `auth.users` table, so isolated PostgreSQL tests remain independent
of Supabase Auth. CCVO-6 must verify the access token, derive `supabase_uid` from
its subject, and create or retrieve exactly one profile using that unique key.
Client-supplied identities or roles must not determine authorization.

## Authentication contract — CCVO-6

Flutter signs in or creates an email account using Supabase Auth. For a protected
FastAPI request, send the session's **access token**, not its refresh token or an
API key:

```http
Authorization: Bearer <current-session-access-token>
```

Flutter owns session refresh and retries an expired-token request after refreshing
the Supabase session. Never log tokens. Database credentials, signing secrets, and
service-role keys belong only on the server; they are not needed in Flutter.

Set `SUPABASE_URL=https://<project-ref>.supabase.co` in the backend's private `.env`.
Use the same Supabase project as Flutter. Required server configuration is:

| Variable | Purpose |
|---|---|
| `SUPABASE_URL` | HTTPS project origin, without credentials, query, or path |
| `DATABASE_URL` | Existing server-only PostgreSQL runtime connection |

No JWT secret or service-role key is needed for verification. Haley should confirm
that Auth uses an asymmetric **ES256 or RS256** signing key. The development
project's public JWKS endpoint published an ES256 key when checked on October 30,
2026. Legacy HS256 tokens are rejected; do not change signing keys solely to make
a client request pass. A project still issuing HS256 requires a separate reviewed
Auth-server verification path.

The verifier fetches public keys only from the configured origin at
`/auth/v1/.well-known/jwks.json`. A token cannot supply a different key URL.
Validation checks the signature against an ES256/RS256 allowlist, the exact issuer
`<SUPABASE_URL>/auth/v1`, audience `authenticated`, required unexpired `exp`, and
a UUID `sub`. Optional `iat` and `nbf` claims are validated when present. The
Supabase `role` must be `authenticated`; anonymous sign-ins and API-key roles
are rejected. An email claim is required for the current email-account MVP and
must fit the existing profile constraint. There is no expiration grace period.

JWKS responses are cached for five minutes, without indefinite per-key caching.
An unknown key ID triggers a key-set refresh. Requests time out after five seconds.
Supabase also caches JWKS at its edge, so allow its documented propagation period
when rotating keys. Restarting the backend clears its local key cache. Offline
JWT verification does not immediately revoke a token after Supabase sign-out or
user deletion; it can remain valid until expiry. Application `inactive` and
`suspended` status is checked in the database on each protected request.

Protected routes use the dependency below. This ticket adds no temporary public
authentication or profile endpoint:

```python
from typing import Annotated
from fastapi import Depends
from app.auth.dependencies import get_current_user
from app.models import User

# In a protected route signature:
# user: Annotated[User, Depends(get_current_user)]
```

The dependency resolves profiles only by the **verified subject**. First access
creates a `neighbor`/`active` profile. A concurrent first request is handled by the
unique subject constraint and `ON CONFLICT DO NOTHING`. Provisioning explicitly
commits before returning; use this dependency before a route starts its own
write transaction. Existing profile email, display name, role, and status remain
unchanged. Matching email addresses do not link different subjects. Only the
optional display name comes from user metadata; it is bounded to 100 trimmed
characters with `Neighbor` as a fallback. User metadata never assigns privileges.

Errors have stable generic bodies and contain no token, key, or upstream details:

| Status | JSON body | Meaning |
|---|---|---|
| 401 | `{"detail":"Invalid or missing access token."}` | Missing, malformed, expired, wrong-project, or otherwise invalid token; includes `WWW-Authenticate: Bearer` |
| 403 | `{"detail":"Account is not active."}` | Verified user has an inactive/suspended application profile |
| 503 | `{"detail":"Authentication is temporarily unavailable."}` | Missing backend auth configuration, unreachable public-key service, or unusable upstream key set |

Health and application import remain independent of authentication/database
configuration. Tests sign tokens with disposable local keys; database tests use
only the disposable PostgreSQL fixture, including a concurrent provisioning test.
The hosted project check confirms public-key availability, not a live user login.

References: [Supabase JWT verification](https://supabase.com/docs/guides/auth/jwts),
[signing keys and rotation](https://supabase.com/docs/guides/auth/signing-keys), and
[PyJWT verification](https://pyjwt.readthedocs.io/en/stable/usage.html).

## Alembic migrations — CCVO-28

Inspect the planned SQL before applying a migration to the development database:

```powershell
.\.venv\Scripts\python.exe -m alembic upgrade head --sql
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m alembic current
.\.venv\Scripts\python.exe -m alembic check
```

The initial revision creates only the User table and its constraints. A follow-up
revision normalizes the four check-constraint names to match the model. Future
model tickets add the other entities. Migration reflection is restricted to
`app_private`; it excludes Supabase's unrelated public tables. New revisions
must be reviewed before use. Migrations run as a separate development/release
step, never from an API request or app startup.

Application tables stay in `app_private`, which must **not** be added to the
Supabase Data API's exposed schemas. The migration revokes schema/table access
from PUBLIC and, when present, `anon` and `authenticated`. The backend uses a
server-only database role with the required schema/table permissions. The
migration owner already has those rights; any separate runtime role needs
explicit `USAGE` on the schema and `SELECT, INSERT, UPDATE` on the User table.
Do not grant the Flutter/Data API roles application-table access.

`downgrade base` deletes User data. Use downgrade/reapply only on a disposable
test database. Use reviewed corrective migrations for shared data.

## Run the full test suite — CCVO-30

The suite uses real PostgreSQL, not SQLite. Start the disposable Docker database
from `backend` after Docker Desktop is running:

```powershell
docker compose -p village-outreach-backend-test -f compose.test.yaml up -d --wait
$env:ENVIRONMENT = 'test'
$env:ALLOW_TEST_DATABASE_RESET = '1'
$env:TEST_DATABASE_URL = 'postgresql+psycopg://vo_test:local-test-only@127.0.0.1:55439/village_outreach_test'
.\.venv\Scripts\python.exe -m pytest -q
```

The password above is only for the throwaway loopback Docker database. Its data
is stored in tmpfs, and the port is not exposed beyond this computer. A separate
local PostgreSQL instance can also be used with a dedicated `_test` database.

Tests read `TEST_DATABASE_URL` from the process environment, never the app's
`.env`. They refuse remote hosts, databases not ending in `_test`, production
environment settings, URL connection overrides, and a target also configured
as the runtime or migration database. Missing test setup is a failure rather
than a silently skipped database suite.

The fixture applies migrations, gives each test a transaction/savepoint, and
rolls back test records even when the test calls `commit()`. Migration tests
also downgrade/reapply the initial revision. Never point these commands at
valuable data or a forwarded shared database.

For database-free checks only:

```powershell
.\.venv\Scripts\python.exe -m pytest -q -m 'not database'
```

Additional checks:

```powershell
.\.venv\Scripts\python.exe -m app.database.check --test
.\.venv\Scripts\python.exe -m ruff check app tests alembic
.\.venv\Scripts\python.exe -m ruff format --check app tests alembic
```

Stop the disposable database:

```powershell
docker compose -p village-outreach-backend-test -f compose.test.yaml down
Remove-Item Env:TEST_DATABASE_URL, Env:ALLOW_TEST_DATABASE_RESET
Remove-Item Env:ENVIRONMENT
```

Future API tests can use `db_session` and override the `get_session` FastAPI
dependency. Add requester/helper fixtures when those models and protected
routes exist; this sprint does not invent their authorization behavior.

## Review workflow

Work is developed on `feature/backend`. After local testing, submit a PR into
`dev` for teammate review. Test the integrated dev build before the team
reviews promotion to `main`.

References: [Final SDD](https://docs.google.com/document/d/1jHAX5MNiE9HQ4lKZ0HHIHjGlyKtQqxiE/edit),
[Supabase connections](https://supabase.com/docs/guides/database/connecting-to-postgres),
[psycopg prepared statements](https://www.psycopg.org/psycopg3/docs/advanced/prepare.html),
[SQLAlchemy test transactions](https://docs.sqlalchemy.org/en/20/orm/session_transaction.html#joining-a-session-into-an-external-transaction-such-as-for-test-suites).
