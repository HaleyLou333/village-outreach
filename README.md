# Village Outreach
A smart cities mutual-aid mobile application designed to help neighbors request support, offer assistance, and discover nearby community resources.
This README summarizes the project architecture, team roles, development workflow, and milestone scope as defined in the Software Design Document.

The app brings neighborhood requests and community resources into one place so people can find local support and see where they can help.

## Project Status

**Pre-alpha / in development — November 1, 2026.** The repository contains a Flutter UI prototype, a FastAPI backend, and synthetic AI evaluation fixtures. It is not yet a complete, connected mutual-aid service or a public app-store release.

- **Flutter:** Branded home screen with sample requests. Sign-in, request submission, navigation, maps, and backend integration are not connected in this prototype.
- **Backend:** Health endpoint, PostgreSQL migrations, Supabase token verification, and profile/help-request APIs are integrated into `dev`. A connected mobile walkthrough remains pending.
- **AI:** Synthetic fixtures, a fixture validator, and a documented privacy/classification flow. Live classification and provider integration remain planned work.
- **Deployment:** Running the UI does not start or connect the backend. Local API code does not mean the hosted database or service has been updated.

See [Alpha Features](#alpha-features), [Installation](#installation), and [Development Setup](#development-setup) for scope and setup.

---

## Team Members & Roles
| Team Member | Primary Role | Email |
|-------------|--------------|-------|
| **Haley Eason** | Project Lead / AI | haeason@student.fullsail.edu |
| **Matthew Bakken** | Frontend / UI-UX | matt96bakken@gmail.com |
| **Eric Joel Reyes Rivera** | Backend Developer | Ejreyesrivera@gmail.com |

These teammates maintain the project in their assigned areas. Pull requests receive teammate review before integration.

---

## Project Purpose
Village Outreach is a community support platform that enables users to:

- Post help requests
- Offer assistance
- Communicate safely
- Discover nearby resources
- Coordinate mutual aid within their neighborhood

---

## Goals & Non-Goals

### **Goals**
- Make local help easier to find and organize
- Provide safe communication between requester and helper
- Support community resource discovery

### **Non-Goals**
- Emergency response or crisis intervention
- Peer-to-peer payments
- Direct client-side database access
- AI-dependent workflows
- Background checks

---

## Technologies & System Architecture

Village Outreach uses a mobile-first architecture:

### **Frontend**
- Flutter mobile app
- Android-first prototype
- UI built with Nunito, Inter, and Raleway
- Soft forest green, pale orange, + off-white brand palette

### **Backend**
- FastAPI (Python)
- Business logic, authentication checks, and data access
- Planned AI integration endpoints
- SQLAlchemy and psycopg for database access; Alembic for migrations
- Pytest and Ruff for backend verification

### **Database**
- PostgreSQL (Supabase or hosted PostgreSQL)
- Implemented backend models: User and HelpRequest
- Planned additional entities: Offer, Message, Resource, Report, Organization

### **Authentication**
- Supabase Auth
- Backend validates signed access tokens; Flutter sign-in integration remains pending

### **Maps Provider**
- Google Maps (planned integration)

### **AI Provider**
- Google Cloud Natural Language (planned; provider/model choice remains with Haley)
- The current repository does not call a live AI provider

Dependency versions are maintained in [backend requirements](backend/requirements.txt), [backend constraints](backend/constraints.txt), and [Flutter pubspec](frontend/pubspec.yaml).

---

## Core Features (MVP)

### **Minimum Viable Product**
The following describes the intended product, not a list of completed features:

- Account creation & sign-in
- Create help requests (category, description, urgency, location)
- Browse nearby requests
- Offer help
- Resource map
- Messaging
- Safety reporting
- Database persistence for all core entities

## Alpha Features

For the course's end-of-month alpha milestone, the target is a connected Android flow for creating and finding neighborhood help requests, with AI-assisted category suggestions. These are development targets; the current implementation limits are listed under [Project Status](#project-status).

- Create an account and sign in through Supabase Auth.
- View and update the signed-in user's display name.
- Create a help request with a title, description, category, urgency, and selected location.
- Browse nearby active requests and view request details.
- Edit, complete, or cancel a request as its owner.
- **AI-assisted request classification:** Suggest a category from the request text after privacy screening. Evaluate classification against the synthetic fixtures, let the user confirm or change the category, and keep manual selection available when no reliable suggestion is available.

Alpha includes integrating and evaluating the category-suggestion workflow. Google Cloud Natural Language is the proposed provider, subject to confirming that the selected model supports the project's categories. Existing fixtures and the data-flow document support this work but do not constitute a working classifier.

The roadmap also includes notifications, combined filters, organizations, photos, and multilingual support. These remain additional targets after the core request flow and AI integration; they are not currently available features.

---

## User Experience Overview

Village Outreach priorities:

- Warm, calm, community-focused UI
- Clear navigation
- Accessibility (readable text, simple flows)
- Fast posting and simple communication

Primary screens include:
- Sign In / Account
- Home / Nearby Requests
- Create Request
- Request Details
- Resource Map
- Messages
- Profile / Safety

---

### Entity Relationship Model (ERD)

**Entities:**
- User
- HelpRequest
- Offer
- Message
- Resource
- Report
- Organization

---

## Backend API Surface

API groups implemented on `dev`:

- **Health** - backend status
- **Users** - profile read/update
- **Requests** - create/list/read/update

Planned API groups:

- **Offers** - create/review
- **Messages** - send/load conversations
- **Resources** - list/filter
- **Reports** - create safety reports
- **AI** - category/resource suggestions

---

## Ethics, Privacy & Security

### User data and location privacy

The backend stores an application profile linked to the verified Supabase identity: email, display name, role, account status, and timestamps. Help requests store a title, description, category, urgency, selected coordinates/area, owner reference, status, and timestamps. Nearby searches use the location supplied by the caller; a manually selected area can be used instead of device location.

Request responses round coordinates to two decimal places, and nearby filtering uses that same approximate point. This reduces location precision but does not make a request anonymous. Signed-in active users can read request details, including closed requests. Users should avoid putting addresses, phone numbers, medical details, or other sensitive information in request text; location rounding does not remove those details.

Application tables live in the private `app_private` schema and are accessed through the backend. That schema must remain outside Supabase's exposed Data API schemas, with no table access for Flutter's API roles. Data retention, deletion requests, and moderation procedures still need to be finalized before public use. Completing or canceling a request changes its status; it does not delete the stored record.

### Authentication and credentials

- Supabase Auth handles account credentials. Application profile tables do not store passwords or password hashes.
- Protected backend routes verify access-token signatures, issuer, audience, expiry, and authenticated identity. Account status and request ownership control access and edits.
- Database URLs, passwords, service-role keys, and provider secrets belong only in private backend configuration. Never put them in Flutter assets, source files, screenshots, logs, or Git commits.
- Use the committed `.env.example` as a template; local `.env` files are ignored by Git. Use separate development and production credentials and rotate any secret that is exposed.
- Use HTTPS for deployed API traffic and encrypted hosted database connections. The local HTTP commands below bind only to this computer.
- Application logs omit request bodies, tokens, and query coordinates. Start Uvicorn with `--no-access-log` as shown below to avoid its default query-string logging.

Offline token verification does not immediately revoke an already issued token after sign-out. The backend checks application account status, but session revocation and expiry behavior still need to be considered in release testing.

### AI and third-party services

Request text can reveal personal information even when it contains no account ID. The planned AI flow screens text before external processing and keeps potentially sensitive text in local/manual review. This is a design requirement, not a completed privacy filter. The current AI evaluation dataset contains synthetic examples only.

Before enabling a provider, review what it receives, its retention practices, usage costs, and failure behavior. Do not send raw profiles, precise coordinates, credentials, or unreviewed request text. Maps integrations also need clear permission handling and a manual-location alternative. Keep provider secrets on the backend; restrict any required client map key to its intended application and APIs.

AI can misclassify requests or perform unevenly across languages and writing styles. Category suggestions must remain editable, with manual fallback when the provider is unavailable or uncertain. Sentiment must not decide who deserves help or determine emergency priority. The app does not provide emergency response, verify helpers through background checks, or guarantee that posted resources are accurate. Reporting and moderation remain planned safeguards, not completed protections.

See the [AI data flow](docs/ai/data-flow.md) and [evaluation privacy rules](ai/evaluation/README.md).

---

## Installation

There is no published installer or app-store release documented in this repository yet. To try the current UI prototype, use an Android emulator or a development device and follow the [Flutter setup](#flutter-prototype) below, or ask the frontend maintainer for a trusted development APK.

For a team-provided debug APK:

1. Use an Android development device or emulator. With Android SDK platform tools installed, connect the device with USB debugging enabled and confirm it appears in `adb devices`.
2. Install the APK with `adb install -r path/to/app-debug.apk`, replacing the path with the file supplied by the team.
3. Open **Village Outreach** to view the branded home screen and sample nearby requests.

The sample cards are demonstration data. The current prototype does not submit requests, sign users in, or connect them to real neighbors. Do not enter real personal information for a prototype demonstration.

---

## Development Setup

### Prerequisites

- Git and a terminal. Commands below use PowerShell.
- Python 3.13 for the backend.
- Flutter with Dart compatible with `sdk: ^3.13.5` in `frontend/pubspec.yaml`. The local setup used for this README has Flutter 3.47.7 and Dart 3.13.5.
- Android Studio, Android SDK, and a configured emulator or USB-debugging device for Android builds. The Android project targets Java 17 bytecode; use a JDK compatible with its Gradle configuration and check `flutter doctor`.
- A separate development PostgreSQL/Supabase project for persistent API use. Docker Desktop is needed only for the disposable database test workflow.

### Get the code

```powershell
git clone https://github.com/HaleyLou333/village-outreach.git
Set-Location village-outreach
git switch dev
```

`dev` is the integration branch and includes the Sprint 2 profile/request APIs documented here.

### Flutter prototype

From the repository root:

```powershell
Set-Location frontend
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
```

Replace `<device-id>` with the Android emulator/device ID printed by `flutter devices`. Resolve Android SDK/license issues reported by `flutter doctor` before building. No backend credentials are needed for the static home screen.

To create a development APK from `frontend`:

```powershell
flutter build apk --debug
```

The APK is written to `frontend/build/app/outputs/flutter-apk/app-debug.apk`. Debug builds are for development and review; release signing and app-store distribution remain separate work. See [Flutter build modes](https://docs.flutter.dev/testing/build-modes).

### Backend initial build and startup

In a separate terminal, start from the repository root:

```powershell
Set-Location backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r tests/requirements.txt
.\.venv\Scripts\python.exe -m pip check
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --no-access-log
```

Python runs the API directly; there is no separate compilation step. Open `http://127.0.0.1:8000/health` and expect `{"status":"ok"}`. Interactive endpoint documentation is at `http://127.0.0.1:8000/docs`. Startup and health do not require database credentials and do not run migrations.

For authenticated database-backed requests, stop the API and create private configuration from `backend` if `.env` does not already exist:

```powershell
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
```

Edit `.env` locally with the isolated development project's values:

| Variable | Purpose |
|---|---|
| `ENVIRONMENT` | `development` |
| `SUPABASE_URL` | HTTPS origin of the same Supabase project used for sign-in |
| `DATABASE_URL` | Server-only runtime PostgreSQL connection |
| `MIGRATION_DATABASE_URL` | Separate direct/session connection for Alembic; do not use the transaction pooler |

Use `postgresql+psycopg://` URLs with `sslmode=require` for hosted connections. The current token verifier accepts ES256/RS256 tokens and uses public signing keys; it does not need a service-role key or JWT signing secret. See [Supabase signing keys](https://supabase.com/docs/guides/auth/signing-keys) and the [backend configuration guide](backend/README.md).

Review migrations before applying them to the intended development database. From `backend`:

```powershell
.\.venv\Scripts\python.exe -m app.database.check
.\.venv\Scripts\python.exe -m alembic upgrade head --sql
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m alembic current
```

Restart the API afterward. Protected routes require a valid Supabase session access token in `Authorization: Bearer <access-token>`. Flutter sign-in and API integration are still pending, so the static UI cannot exercise this flow yet. The backend guide includes endpoint examples and runtime-role permissions.

### Verification

From `backend`, run checks that do not require a database:

```powershell
.\.venv\Scripts\python.exe -m pytest -q -m 'not database'
.\.venv\Scripts\python.exe -m ruff check app tests alembic scripts
```

For database/migration tests, follow the [disposable PostgreSQL test setup](backend/README.md#run-the-full-test-suite--ccvo-30). Those tests reset schema objects and must use the dedicated local test database, never a shared or production database.

From the repository root, validate the synthetic AI fixtures:

```powershell
python ai/evaluation/validate_fixtures.py
```

This validates fixture structure and labels; it does not measure a working classifier's accuracy. See [Sprint 2 backend verification](docs/sprint-2-backend-verification.md) for the API review handoff.

### Development tools

- Git/GitHub
- VS Code
- Android Studio and Flutter SDK
- Python / FastAPI
- PostgreSQL and Supabase Dashboard
- Figma (UI/UX)

---

## Branching & Workflow

### **Branch Types**
- `main` — stable milestone builds  
- `dev` — integrated development
- `feature/<name>` — individual features  
- `release/<milestone>` — optional stabilization  
- `hotfix/<name>` — urgent fixes

### **Pull Request Rules**
- Test locally before review  
- No credentials committed  
- Clear commit messages  
- Reviewer approval required

---

## Testing Plan

| Area | Focus | Owner |
|------|--------|--------|
| Backend/API | Validation, permissions, DB behavior | Eric / Haley |
| Frontend | Navigation, forms, layout | Matt |
| AI | Output quality, fallback behavior | Haley |
| End-to-end | Full user flows | Whole team |
| Outside testing | Scenario-based testing | Whole team |

---

## Repository Structure

The repo separates:

- [`frontend/`](frontend/) — Flutter app, assets, and widget tests
- [`backend/`](backend/) — FastAPI, models, migrations, API tests, and configuration template
- [`ai/`](ai/) — synthetic evaluation fixtures and planned classification work
- [`docs/`](docs/) — design documentation, AI data flow, and verification notes

---

## AI Model Integration

- Proposed provider: Google Cloud Natural Language; final provider/model selection belongs to Haley.
- Alpha goal: category prediction from privacy-screened request text, evaluated against the synthetic category fixtures.
- Later exploration: sentiment cues and lightweight resource recommendations, subject to privacy and fairness review.
- Privacy screening and a live classifier are not implemented yet. No live provider call is present in the current code.
- Suggestions are intended to be optional for users, editable, and non-blocking. Manual category selection remains available if AI cannot provide a suggestion.

---

## Open Team Decisions

| Decision | Owner |
|----------|--------|
| Flutter/Android versions/Map provider | Matt |
| Python/FastAPI/PostgreSQL versions | Eric |
| AI provider/model | Haley |

---

## Roadmap
- **Alpha:** Connected sign-in/profile/request flow, nearby browsing, owner updates, and evaluated AI category suggestions with manual fallback. Additional targets: notifications, combined filters, organizations, photos, and multilingual support.
- **Beta:** Broader AI/resource suggestions, accessibility improvements, reputation indicators, and resource guides.
- **Version 2.0:** Donations, background checks, municipal partnerships

## Known Issues

- The Flutter home screen uses static sample requests and placeholder interactions.
- The current Flutter widget suite has a failing home-screen assertion: `Ride to Appointment` is not found before the test scrolls. `flutter analyze` passes, but the widget suite needs follow-up.
- Profile/request APIs are integrated into `dev` but still need a connected mobile walkthrough.
- The hosted help-request migration is not confirmed applied; check the target database before integration testing.
- Live AI classification, privacy screening, maps, offers, messaging, and reporting are not implemented in this checkout.
- Retention/deletion policy, moderation procedures, release signing, and public distribution remain unfinished.

## License

Village Outreach is licensed under the [MIT License](LICENSE). Copyright (c) 2026 Village Outreach contributors. Third-party dependencies and bundled assets retain their own license terms.

## Support

For setup questions, contact the maintainer responsible for the affected area in [Team Members & Roles](#team-members--roles). Report reproducible, non-sensitive bugs through [GitHub Issues](https://github.com/HaleyLou333/village-outreach/issues). Do not include credentials, real request text, or private user/location data in public reports.
