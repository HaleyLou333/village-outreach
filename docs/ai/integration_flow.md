# AI Integration Flow

## Purpose

This document describes how the Village Outreach backend will integrate with the AI classification layer during development and after Google Cloud Natural Language (NL) is introduced.

The backend should remain independent of any specific AI provider through the use of a classification adapter interface.

---

## Development Phase

During early development, the backend uses the mock classifier implementation.

Benefits include:

- No external cloud dependencies
- Predictable test results
- Faster local development
- No provider usage costs
- Reliable CI/CD execution

Current flow:

```text
Client Request
      |
      v
FastAPI Endpoint
      |
      v
Classification Service
      |
      v
Mock Classifier
      |
      v
Classification Result
      |
      v
API Response
```

---

## Example FastAPI Endpoint Flow

### Request

```http
POST /api/v1/classify
```

Example payload:

```json
{
  "text": "I need transportation to a medical appointment."
}
```

### Backend Flow

1. Receive authenticated request.
2. Validate payload.
3. Perform privacy and eligibility screening.
4. Submit eligible text to the classification service.
5. Classification service selects configured provider.
6. Provider returns a `ClassificationResult`.
7. API returns category suggestion to the client.

Example response:

```json
{
  "category": "TRANSPORTATION",
  "confidence": 0.95,
  "result_source": "mock"
}
```

---

## Classification Service Design

The backend should communicate only with the classification service abstraction.

Example:

```text
FastAPI Endpoint
      |
      v
Classification Service
      |
      +--> Mock Classifier
      |
      +--> Google Cloud NL Provider
```

Endpoints should never directly call a provider implementation.

This design allows providers to be replaced without modifying API contracts.

---

## Future Google Cloud NL Integration

Future production deployments may replace the mock classifier with a Google Cloud Natural Language provider.

Expected environment configuration:

```text
GOOGLE_CLOUD_PROJECT_ID
GOOGLE_CLOUD_LOCATION
GOOGLE_APPLICATION_CREDENTIALS
```

Credentials must remain:

- Backend-only
- Securely stored
- Excluded from version control

---

## Swapping Mock → Google Cloud NL

The transition should require configuration changes only.

Current:

```text
Classification Service
        |
        v
Mock Classifier
```

Future:

```text
Classification Service
        |
        v
Google Cloud NL Provider
```

Expected migration steps:

1. Implement Google Cloud provider adapter.
2. Validate provider response mapping.
3. Configure cloud credentials.
4. Update provider selection configuration.
5. Execute integration testing.
6. Deploy to backend environments.

No API contract changes should be required.

---

## Error Handling and Fallback Rules

If Google Cloud NL:

- Times out
- Returns an error
- Returns invalid data
- Becomes unavailable

The backend should:

1. Log the failure.
2. Return `NO_SUGGESTION`.
3. Preserve application functionality.
4. Continue request processing where possible.

The AI system is optional and must never prevent users from creating requests or accessing resources.

---

## Provider Independence

The backend architecture should support future provider replacement.

Potential future providers include:

- Google Cloud Natural Language
- Azure AI Language
- AWS Comprehend
- Custom machine learning models

Provider-specific logic should remain isolated behind the classification adapter interface.

This approach reduces coupling and minimizes future migration effort.