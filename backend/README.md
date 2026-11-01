# Village Outreach backend

This backend contains the FastAPI health endpoint, SQLAlchemy User profile,
PostgreSQL connection/session helpers, Alembic migration, and initial tests.
CCVO-6 adds Supabase access-token verification and application-profile provisioning
as reusable dependencies. CCVO-5 adds authenticated profile read/update endpoints;
CCVO-7/8/9/35 add request persistence, creation, nearby browsing, details,
and owner updates/completion/cancellation.

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
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --no-access-log
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
of Supabase Auth. CCVO-6 verifies the access token, derives `supabase_uid` from
its subject, and creates or retrieves exactly one profile using that unique key.
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

Protected routes use the dependency below. CCVO-6 adds no temporary public
authentication endpoint; CCVO-5's profile routes use this dependency:

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

## Profile API contract — CCVO-5

Both endpoints require `Authorization: Bearer <current-session-access-token>`
and operate on the verified signed-in user's profile. There is no private-profile
lookup by caller-supplied user ID. Interactive endpoint schemas are available at
`/docs` and `/openapi.json`.

| Method | Path | Success |
|---|---|---|
| GET | `/users/me` | 200 with the current profile |
| PATCH | `/users/me` | 200 with the saved profile |

The response has these fields:

| Field | Type | Editable here? |
|---|---|---|
| `id` | UUID application profile ID | No |
| `email` | String, 1–254 trimmed characters from initial Auth provisioning | No |
| `display_name` | String, 1–100 characters after trimming whitespace | Yes |
| `role` | `neighbor`, `moderator`, or `admin` | No |
| `status` | `active`, `inactive`, or `suspended` | No |
| `created_at` | UTC ISO 8601 timestamp | No |
| `updated_at` | UTC ISO 8601 timestamp | No |

The internal `supabase_uid` is not included in responses. Email/account changes
belong to the Auth flow; this endpoint does not change Auth email or credentials.

Example PATCH body:

```json
{"display_name": "Eric Reyes"}
```

Example successful GET/PATCH response (illustrative IDs and timestamps):

```json
{
  "id": "00000000-0000-0000-0000-000000000001",
  "email": "neighbor@example.com",
  "display_name": "Eric Reyes",
  "role": "neighbor",
  "status": "active",
  "created_at": "2026-10-30T08:00:00Z",
  "updated_at": "2026-10-30T08:05:00Z"
}
```

PATCH requires `display_name`; an empty object is invalid. Values must be strings,
not null, numbers, or arrays. Whitespace is trimmed before length validation.
Blank names, names longer than 100 characters, NUL characters, and malformed
Unicode are rejected. Unknown or read-only fields reject the **entire** request,
even when a valid display name is also supplied. No fields are silently ignored.
A read after a successful PATCH returns the saved name. `created_at` stays fixed;
`updated_at` advances when a stored value changes.

Missing profiles follow CCVO-6: a verified email-account identity provisions one
`neighbor`/`active` profile on first GET or PATCH. Repeat calls reuse it. If the
profile is deleted between authentication and the PATCH's locked database check,
PATCH returns 404 instead of recreating it during the write. That check also
rejects an account suspended since authentication. No new migration is required.

| Status | Body | When |
|---|---|---|
| 401 | `{"detail":"Invalid or missing access token."}` | Missing or rejected authentication; includes `WWW-Authenticate: Bearer` |
| 403 | `{"detail":"Account is not active."}` | Inactive/suspended application account |
| 404 | `{"detail":"Profile not found."}` | Profile deleted before the update's locked check |
| 422 | `{"detail":"Invalid request data."}` | Invalid JSON/body/name, missing display name, or unknown/read-only fields |
| 503 | `{"detail":"Authentication is temporarily unavailable."}` | Auth configuration or public-key service unavailable |
| 503 | `{"detail":"Profile storage is temporarily unavailable."}` | Profile lookup/provisioning/update failed; pending changes rolled back |

Request-validation errors use the generic 422 body above and do not echo submitted
profile data. The response model excludes database-only identity fields. Tests
exercise the real FastAPI routes with signed disposable tokens and PostgreSQL,
including two users, persistence, first access, rejected changes, and status/deletion
checks. Live Supabase sign-in through Flutter remains an integration check.

## Help requests — CCVO-7, CCVO-8, CCVO-9, CCVO-35

All request endpoints require the same bearer token as the profile API. The
verified application user is the requester; bodies cannot supply an owner ID.

| Method | Path | Result |
|---|---|---|
| POST | `/requests` | 201 created; 200 for an exact creation retry |
| GET | `/requests` | 200 array of active nearby requests, possibly `[]` |
| GET | `/requests/{id}` | 200 current details, including closed status |
| PATCH | `/requests/{id}` | 200 saved owner edit, completion, or cancellation |

### Create and retry

POST requires an `Idempotency-Key` header: 8–128 ASCII letters, digits, `.`, `_`,
`:`, or `-`. Generate one UUID per user submission and **reuse it with the same
body when retrying** after a timeout. A new submission gets a new key.

```http
POST /requests
Authorization: Bearer <access-token>
Idempotency-Key: 64f289f2-46ac-4b27-9092-d51ab40a801a
Content-Type: application/json
```

```json
{
  "title": "Grocery pickup",
  "description": "Help picking up groceries this weekend.",
  "category": "FOOD_ASSISTANCE",
  "urgency": "standard",
  "latitude": 35.123456,
  "longitude": -97.654321,
  "area": "Selected neighborhood"
}
```

Every field above is required. Title is 1–120, description 1–4000, and area 1–100
Unicode characters after trimming whitespace. Strings must not contain NUL or
invalid Unicode. Coordinates must be finite, with latitude between -90 and 90
and longitude between -180 and 180. `area` labels the selected neighborhood/area;
it is not geocoded by this API. Avoid entering a precise address in public text.

Categories are `FOOD_ASSISTANCE`, `TRANSPORTATION`, `CHILDCARE`, `DONATED_ITEMS`,
`DELIVERY_HELP`, and `LOCAL_SERVICES`, matching the current AI evaluation dataset.
Urgency is `standard` or `time_sensitive`. These API values, text limits, and
coordinate rounding are implementation choices where the SDD does not enumerate
values. Flutter should map them to readable labels; the earlier static feed's
labels are not the API enum values.

Unknown fields, IDs, requester identity, role, timestamps, operation fields, and
caller-selected initial status are rejected with 422. New requests start `active`.
The database enforces one `(requester_id, idempotency_key)` pair. An immutable
SHA-256 digest of normalized creation input distinguishes an exact retry (200)
from a conflicting payload (409), including simultaneous retries. Different
users may use the same key independently. Retrying creation after an owner edit
returns the existing request's current state; it does not overwrite or reopen it.

Example create/detail/update response (illustrative identifiers/timestamps):

```json
{
  "id": "00000000-0000-0000-0000-000000000002",
  "requester_id": "00000000-0000-0000-0000-000000000001",
  "title": "Grocery pickup",
  "description": "Help picking up groceries this weekend.",
  "category": "FOOD_ASSISTANCE",
  "urgency": "standard",
  "latitude": 35.12,
  "longitude": -97.65,
  "area": "Selected neighborhood",
  "status": "active",
  "created_at": "2026-10-31T08:00:00Z",
  "updated_at": "2026-10-31T08:00:00Z"
}
```

All public coordinates use decimal half-up rounding to two decimal places.
Public distance filtering and ordering use that same approximate point, so
changing query radii cannot reveal finer stored coordinates. Responses never include
the operation key/digest, requester email, or Supabase Auth subject. Location
rounding does not redact information a user types into title/description/area.

### Nearby browsing and manual selection

```http
GET /requests?latitude=35.12&longitude=-97.65&radius_km=10&limit=20&offset=0
Authorization: Bearer <access-token>
```

| Query parameter | Contract |
|---|---|
| `latitude`, `longitude` | Required finite search center within the coordinate bounds above |
| `radius_km` | Kilometers; greater than 0 and at most 100; default 10 |
| `limit` | Integer 1–100; default 20 |
| `offset` | Integer 0–10000; default 0 |

Use coordinates from the device or from a manually selected map/area center when
location permission is denied. No device permission is required by the backend.
The response is an array of the objects above with an additional `distance_km`
field rounded to one decimal place. An empty array means no matches, not an
error. Increment offset by limit for the next page; stop when a page has fewer
than limit entries. Offset pagination may shift when requests are added/closed.

The database filters **active** requests using great-circle distance to their
public approximate coordinates and an inclusive radius boundary before applying
SQL pagination. Ordering is
distance ascending, creation time descending, then UUID ascending. The query
handles the antimeridian and poles without requiring PostGIS. Rounded distances
are for display; qualification uses the unrounded distance to the approximate
point. A request's exact stored point can lie just outside/inside that boundary,
so the map/list should present this as approximate proximity. Combined
category/urgency/distance filters remain Alpha scope.

### Details, edits, completion, and cancellation

Signed-in active users can view individual request details, including completed
or canceled requests. Only the owner can PATCH. Editable fields are the creation
fields plus `status`; at least one field is required, and null is not accepted.
Latitude and longitude must be updated together.

```json
{"description": "Updated grocery pickup details."}
```

```json
{"status": "completed"}
```

```json
{"status": "canceled"}
```

Only `active -> completed` and `active -> canceled` close a request. An active
status no-op is allowed. Repeating the same closed status alone is a safe retry;
reopening, changing one closed status to another, or editing a closed request
returns 409. The write locks/rechecks the row and commits its snapshot before
returning. Closed requests remain readable by ID and disappear from the active
nearby feed. There is no delete action. Offer/message behavior is separate
backlog work and is not implied by these endpoints.

### Errors and request logging

Request errors preserve a readable `detail` and add a stable `code`:

| Status | Code | Meaning |
|---|---|---|
| 401 | `unauthenticated` | Missing/invalid token; includes `WWW-Authenticate: Bearer` |
| 403 | `forbidden` | Inactive account or nonowner write |
| 404 | `not_found` | Unknown request ID |
| 409 | `conflict` | Reused key with different creation data, closed edit, or invalid transition |
| 422 | `invalid_request` | Missing/invalid body, header, query parameter, or UUID |
| 503 | `service_unavailable` | Auth key service or request storage unavailable |

422 responses include `fields`, containing only each error's `loc` and `type`.
Inputs and private database errors are not reflected. Example:

```json
{
  "detail": "Invalid request data.",
  "code": "invalid_request",
  "fields": [{"loc": ["body", "title"], "type": "missing"}]
}
```

Responses include a server-generated `X-Request-ID`. Protected data has
`Cache-Control: no-store`. Application request logs include ID, method, path,
and status, without query coordinates, bodies, passwords, or tokens. Run Uvicorn
with `--no-access-log` to prevent its default query-string access logging.

### Request schema and migration

`app_private.help_requests` stores UUID `id`, required `requester_id -> users.id`,
title/description/category/urgency, selected coordinates/area, status, UTC
timestamps, idempotency key, and creation hash. Database constraints enforce
required values, normalized text lengths, enums, coordinate ranges, operation
key length, and digest format. A status/location index supports nearby access;
the per-owner operation uniqueness index also covers requester lookup. Deleting
a referenced User is restricted. No Flutter/Data API role receives table access.

The additive revision `cbcaea6d1d8d` follows `de59b6dfa342`. Its downgrade removes
only request schema objects and preserves the User baseline; it deletes request
data and is for disposable verification only. The new revision has been tested
locally; it has **not** been applied to the hosted project. Review the migration
before applying it through the documented migration connection. A separate
runtime database role needs SELECT/INSERT/UPDATE on the new private table.

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
.\.venv\Scripts\python.exe -m ruff check app tests alembic scripts
.\.venv\Scripts\python.exe -m ruff format --check app tests alembic scripts
```

Stop the disposable database:

```powershell
docker compose -p village-outreach-backend-test -f compose.test.yaml down
Remove-Item Env:TEST_DATABASE_URL, Env:ALLOW_TEST_DATABASE_RESET
Remove-Item Env:ENVIRONMENT
```

API tests use `db_session` and override the `get_session` FastAPI dependency.
Request tests use separate signed identities to verify ownership and feed behavior.

For a real HTTP walkthrough of profile/create/retry/browse/edit/close behavior,
with the same disposable database environment configured above, run:

```powershell
.\.venv\Scripts\python.exe -m scripts.verify_sprint2
```

This starts loopback-only API and public-key test servers with ephemeral signing
keys, verifies persisted records for two synthetic identities, and removes only
its own test records on exit. It never uses hosted Supabase Auth or database data.
See [Sprint 2 verification](../docs/sprint-2-backend-verification.md) for results
and the review handoff.

## Review workflow

Work is developed on `feature/backend`. After local testing, submit a PR into
`dev` for teammate review. Test the integrated dev build before the team
reviews promotion to `main`.

References: [Final SDD](https://docs.google.com/document/d/1jHAX5MNiE9HQ4lKZ0HHIHjGlyKtQqxiE/edit),
[Supabase connections](https://supabase.com/docs/guides/database/connecting-to-postgres),
[psycopg prepared statements](https://www.psycopg.org/psycopg3/docs/advanced/prepare.html),
[SQLAlchemy test transactions](https://docs.sqlalchemy.org/en/20/orm/session_transaction.html#joining-a-session-into-an-external-transaction-such-as-for-test-suites).
