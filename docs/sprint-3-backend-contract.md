# Sprint 3 offers and private messaging

Implements CCVO-10, CCVO-11, CCVO-36, CCVO-32 and CCVO-37. All endpoints require
the existing Supabase bearer access token and active application profile. Actor
IDs are application `/users/me` UUIDs, not Supabase Auth subject UUIDs.

## API contract for Flutter

| Method | Path | Success | Purpose |
|---|---|---|---|
| POST | `/offers` | 201; exact retry 200 | Offer to help an active, unassigned request |
| GET | `/requests/{request_id}/offers` | 200 array | Owner sees all; helpers see only their own |
| POST | `/offers/{offer_id}/accept` | 200 | Owner accepts one pending offer |
| POST | `/messages` | 201; exact retry 200 | Send to the other conversation participant |
| GET | `/requests/{request_id}/messages` | 200 array | Requester/accepted helper read private history |

POST creation routes require `Idempotency-Key` matching
`^[A-Za-z0-9._:-]{8,128}$`; reuse the same key and normalized body on uncertain
retries. A new offer or message requires a new key. Keys are scoped to helper
for offers and sender for messages, across all requests. Reusing a key for
different data returns 409. A different key cannot create a second pending offer
from the same helper on the same request. Exact retries return the existing
record (including its current offer status), even after closure, without a new
write. Authorization is still checked before a retry is returned.

### Create an offer

```http
POST /offers
Authorization: Bearer <access-token>
Content-Type: application/json
Idempotency-Key: offer-operation-001
```

```json
{"request_id":"00000000-0000-0000-0000-000000000001","message":"I can help with pickup."}
```

Response fields: `id`, `request_id`, `helper_id`, `message`, `status`, `created_at`.
IDs are UUID strings and creation time is UTC ISO 8601. New offers have status
`pending`; persisted status values are `pending`, `accepted`, `declined`,
`withdrawn`. This sprint exposes creation and acceptance, not a withdrawal API.

`message` is a required strict string of 1–4000 characters after trimming Python
Unicode whitespace. Blank, null, nonstring, NUL and surrogate text is invalid.
Unknown fields (including `helper_id`, `status`, timestamps) reject the whole body.
Self-offers return 403; unknown requests 404; closed or already assigned requests
409. Database foreign keys restrict deletion of referenced requests and users.

### Review and accept offers

GET offer lists sort `created_at ASC, id ASC`. Both list routes accept `limit`
1–100 (default 20) and `offset` 0–10000 (default 0); empty results return `[]`.
Unrelated users receive an empty offer list and cannot see private offer text.
Unknown request IDs return 404.

Acceptance has no required body or operation key. Only the request owner may
accept. The active request row is locked and rechecked; the selected pending
offer becomes accepted and all other pending offers become declined in one
transaction. Accepting that same accepted offer again returns 200 while the
request is active. Declined/withdrawn offers, competing accepted helpers and
closed requests return 409. Unknown offers return 404; nonowners return 403.

Acceptance enables the conversation. It does not complete the request, reopen a
closed request, expose exact coordinates, or send notifications.

### Send and read messages

```http
POST /messages
Authorization: Bearer <access-token>
Content-Type: application/json
Idempotency-Key: message-operation-001
```

```json
{"request_id":"00000000-0000-0000-0000-000000000001","receiver_id":"00000000-0000-0000-0000-000000000002","body":"I can arrive at noon."}
```

Response fields: `id`, `request_id`, `sender_id`, `receiver_id`, `body`,
`created_at`. The backend derives the sender from authentication. `body` uses
the same 1–4000 trimmed-character rules as an offer message. Extra fields such
as `sender_id` are rejected. The receiver must be the other participant: either
the owner or the single accepted helper. Sending to yourself, another helper,
or another user returns 403. Pending helpers and unrelated users cannot read or
send messages, even if they know a request UUID. Before acceptance the requester
also receives 403 because no private conversation exists yet.

GET history orders `created_at ASC, id ASC`. Participants must page with offset
to reach later messages; timestamps with identical values are ordered by UUID.
There is no real-time subscription or read receipt in this API. Messages are
immutable through these endpoints.

After completion/cancellation, the original owner and accepted helper retain
read access; new sends return 409. An exact authorized retry returns the original
message with 200. The accepted-offer record is retained to preserve participants.

### Errors, transport and privacy

Error JSON follows existing request conventions: `detail`, stable `code`, and
for 422 an array of `fields` containing only `loc` and `type`. Codes are
`unauthenticated` (401), `forbidden` (403), `not_found` (404), `conflict` (409),
`invalid_request` (422), and `service_unavailable` (503). Existing inactive-user
and token-verification rules apply. Storage failures roll back and return a
generic 503 without database details. Protected responses include
`Cache-Control: no-store` and `X-Request-ID`; logs exclude message bodies,
tokens, query coordinates and database diagnostics. Run Uvicorn with
`--no-access-log`, as documented for Sprint 2.

## Database and migrations

`0410fbf8ced8` adds private offers after `cbcaea6d1d8d`.
`1b906b3ac8e0` adds private messages after the offer revision.
Both are additive and reversible; no existing revision was rewritten.

Offer partial unique indexes enforce one pending offer per helper/request and
one accepted offer per request. Creation key uniqueness is per helper. Message
keys are unique per sender, sender/receiver must differ, and all participant
and request IDs have required foreign keys. Request/time/UUID indexes support
ordered pagination. API writes lock the same request row as request closure;
database uniqueness remains a second line of enforcement.
Creation timestamps use insertion-time `clock_timestamp()` after acquiring that
lock, so an older delayed transaction cannot backdate a newly sent message or
offer ahead of records already retrieved by the client.

Tables remain in `app_private`; PUBLIC, `anon`, and `authenticated` privileges
are explicitly revoked. Keep that schema outside Supabase's exposed Data API.
A separate backend runtime role needs schema USAGE and SELECT/INSERT/UPDATE on
offers and SELECT/INSERT on messages. The migration owner already has its own
rights. No frontend credentials or elevated keys belong in the client.

Review generated SQL using the existing migration connection before any shared
upgrade. Hosted migrations are not part of this local review handoff. Downgrades
delete new data and are only appropriate for the disposable verification database.

## Verification

Use the disposable Docker PostgreSQL setup and the three opt-in environment
variables from `backend/README.md`. From `backend`, run:

```powershell
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\python.exe -m ruff check app tests alembic scripts
.\.venv\Scripts\python.exe -m ruff format --check app tests alembic scripts
.\.venv\Scripts\python.exe -m scripts.verify_sprint2
.\.venv\Scripts\python.exe -m scripts.verify_sprint3
```

The Sprint 3 script runs real loopback HTTP with disposable asymmetric signing
keys and four synthetic identities. It verifies stored offers/messages, private
access, retries, acceptance, pagination and closure, then deletes only its records.
It does not establish hosted Supabase login or Flutter/Android integration.

Concurrency tests use independent committed PostgreSQL sessions to race competing
acceptance, identical acceptance, duplicate creations and request closure. The
suite also verifies rollback, schema constraints, metadata equality, private
privileges and downgrade/reapply of both new revisions.

Database design references: [PostgreSQL partial unique indexes](https://www.postgresql.org/docs/current/indexes-partial.html)
and [row locks](https://www.postgresql.org/docs/current/explicit-locking.html).
