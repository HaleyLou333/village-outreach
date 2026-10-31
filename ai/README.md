# Village Outreach AI Module

## Environment

Python Version: 3.14

## Setup

Clone the repository and install dependencies.

```bash
pip install -r requirements.txt
```

## Module Structure

```text
ai/
├── classification/
├── recommendations/
└── evaluation/
```

## Classification Contract

Input:

```python
text: str
```

Output:

```python
ClassificationResult(
    category: str,
    result_source: str,
    confidence: float
)
```

Supported Categories:

- FOOD_ASSISTANCE
- TRANSPORTATION
- CHILDCARE
- DONATED_ITEMS
- DELIVERY_HELP
- LOCAL_SERVICES
- NO_SUGGESTION

## Smoke Test

Run:

```bash
python ai/classification/smoke_test.py
```

Expected Result:

```text
Smoke test passed
ClassificationResult(category='NO_SUGGESTION', result_source='mock', confidence=0.0)
```

## Future Provider Integration

Future AI integrations may use Google Cloud Natural Language.

Example environment variables:

```text
GOOGLE_CLOUD_PROJECT_ID
GOOGLE_CLOUD_LOCATION
GOOGLE_APPLICATION_CREDENTIALS
```

Provider credentials must:

- Never be stored in Flutter
- Never be committed to version control
- Be loaded from secure environment configuration

## Future Backend Integration

Future backend workflow:

1. User submits request text.
2. Backend performs eligible-text/privacy screening.
3. Backend calls AI adapter.
4. Adapter returns category suggestion.
5. Backend returns result to mobile application.

## Timeout and Fallback Behavior

If the provider is unavailable, times out, or returns no usable result:

- Return NO_SUGGESTION
- Use local/manual review workflow
- Core application functionality must continue operating

The AI system is optional and must never block request creation or resource discovery.

## CCVO-57 Integration Notes

Future backend integration should expose an authenticated API
endpoint that receives eligible help-request text and returns
category suggestions from the AI adapter.

The endpoint contract should remain independent of the
underlying provider implementation.

## CCVO-59 Provider Notes

Future Google Cloud Natural Language integration should:

- Use backend-only credentials
- Perform eligible-text screening before submission
- Respect request timeout limits
- Return NO_SUGGESTION when classification is unavailable
- Support future replacement with another provider
