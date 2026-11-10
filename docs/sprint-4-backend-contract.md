# Sprint 4 resources and safety reports

These endpoints use the existing FastAPI bearer authentication. The database
tables live in `app_private`, with access limited to server roles. Apply
Alembic revision `74184430c579` before using the endpoints. If the deployment
uses a separate runtime role, grant it SELECT on resources and SELECT and
INSERT on reports. Give the seed operator INSERT and SELECT on resources.

## Community resources (CCVO-33, CCVO-38, CCVO-71)

- `GET /resources?area=Oklahoma%20City%20Metro&category=library` works
  without device location or Google Maps. Area matching ignores case and
  requires the full stored area name. Category is a lowercase identifier.
- For nearby results, pass both `latitude` and `longitude`. The default
  `radius_km` is 10 and the maximum is 100. Area and category filters can be
  combined with a radius. Nearby results sort by distance, then name and ID.
  Without coordinates, results sort by name and ID.
- `limit` defaults to 20 and accepts 1–100. `offset` defaults to 0 and
  accepts 0–10,000. No matches return an empty array.
- `GET /resources/{id}` returns the same fields as a list item, including
  address, coordinates, phone, website, source URL, and verification date.
  Both routes exclude disabled listings and listings verified more than
  180 days ago. Detail returns 404 for a listing that is unavailable.

The [seed file](../backend/data/okc_metro_resources.json) contains 11 public
libraries in the Oklahoma City metro area. Branch names, addresses, and phone
numbers were checked on November 10, 2026. Each record links to its official
branch page. Coordinates come from address matches and indicate approximate
locations. Test fixtures use synthetic addresses and `example.invalid` URLs.
[Metropolitan Library System](https://www.metrolibrary.org/locations) ·
[U.S. Census Geocoder](https://www.census.gov/programs-surveys/geography/technical-documentation/complete-technical-documentation/census-geocoder.html)

From `backend`, after configuring the intended database and applying the
migration, validate the file or explicitly import it:

```powershell
.\.venv\Scripts\python.exe -m scripts.seed_resources
.\.venv\Scripts\python.exe -m scripts.seed_resources --apply
```

The import uses a stable ID for each source URL. Re-running it skips existing
records, including those a maintainer disabled. For an existing listing, a
maintainer with database write access updates the public fields and verification
date after checking the provider, or sets `is_active=false` to hide the listing.
The nullable `organization_id` is reserved for the organization feature.

## Safety reports (CCVO-34, CCVO-39)

Send `POST /reports` with an `Idempotency-Key` header (8–128 characters,
using letters, digits, dots, underscores, colons, or hyphens) and a JSON body:

```json
{
  "target_type": "request",
  "target_id": "75f10db4-5f91-4df4-8288-c5c0250c4b14",
  "reason": "unsafe_content",
  "description": "Optional description up to 1,000 characters."
}
```

Supported targets are existing help requests and application accounts.
Use `"user"` with the application user ID for an account report. A user
cannot report their own account. The API gets the reporter from the session.
Reasons are `spam`, `harassment`, `unsafe_content`, `fraud`, and `other`.

A new submission returns 201 with its ID and initial status `pending`.
Retrying the same normalized payload with the same key returns the same
receipt with 200. Reusing the key for a different payload returns 409.
Reports are submission-only. Moderation records and any later status changes
stay in the private database.
