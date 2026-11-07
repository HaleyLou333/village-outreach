# Google Cloud Natural Language Safety and Fallback Rules

## Purpose

This document defines safety guidelines and fallback behavior for future Google Cloud Natural Language (GCNL) integrations within the Village Outreach platform.

The objective is to ensure that request creation remains functional even when classifications fail, provider responses are unavailable, or categories cannot be mapped to application-defined values.

Safety requirements are also documented to prevent personal information from crossing provider boundaries and to ensure that invalid or unsafe classification results do not affect user requests.

This document uses simulated provider responses only. No external provider calls are required for verification.

---

## Safety Rules

### Personal Data Protection

User-submitted text may contain personal information, including:

- Phone numbers
- Email addresses
- Street addresses
- Apartment numbers
- Location descriptions
- Names of individuals

Before any provider boundary is crossed:

1. Inputs should be screened for potential personal information.
2. Personal information should be removed, masked, or blocked according to project requirements.
3. Classification requests should never intentionally include sensitive user data.
4. Verification examples must use synthetic test data only.

Example:

Input:

```text
My name is Jane Doe and I live at 123 Main Street.
Please help me obtain groceries this week.
```

Screened Input:

```text
[REDACTED_NAME] lives at [REDACTED_ADDRESS].
Please help me obtain groceries this week.
```

### Category Restrictions

The classifier must never create application categories that are not explicitly supported.

Allowed outcomes:

- FOOD_ASSISTANCE
- COMMUNITY_SUPPORT
- HEALTH_SUPPORT
- RESOURCE_REQUEST
- NO_SUGGESTION

Unsupported or irrelevant categories must be mapped to:

```text
NO_SUGGESTION
```

### Provider Usage Requirements

- No user request should be blocked by classification failure.
- Provider responses are advisory only.
- User-created requests remain the source of truth.
- Classification results must not overwrite user-selected categories.
- Provider failures must trigger documented fallback behavior.

---

## Fallback Logic

The application must continue functioning even when classification cannot be completed.

Classification results are optional enhancements and must never prevent request creation.

### Provider Timeout

Condition:

- The provider does not respond within the expected time limit.

Behavior:

- Stop waiting for the provider response.
- Return `NO_SUGGESTION`.
- Allow request creation to continue.
- Preserve any existing user-selected category.
- Record the timeout event for monitoring purposes.

### Provider Error

Condition:

- API error
- Service unavailable
- Authentication failure
- Unexpected provider response

Behavior:

- Return `NO_SUGGESTION`.
- Do not retry during request creation.
- Allow request creation to continue.
- Preserve any existing category selection.

### Low Confidence Results

Condition:

- Returned confidence score falls below the application's minimum confidence threshold.

Behavior:

- Treat the classification as unreliable.
- Return `NO_SUGGESTION`.
- Continue request creation normally.

Example:

```text
Provider Category: Food & Drink
Confidence: 0.22

Result:
NO_SUGGESTION
```

### Unmapped Categories

Condition:

- The provider returns a category that does not map to a supported Village Outreach category.

Example:

```text
Provider Category: Entertainment
```

Behavior:

- Return `NO_SUGGESTION`.
- Do not automatically assign a category.
- Continue request creation normally.

### Empty or Short Input

Condition:

- User submits an empty request.
- Request does not contain enough information for meaningful classification.

Examples:

```text
"help"
"hi"
"?"
```

Behavior:

- Skip classification.
- Return `NO_SUGGESTION`.
- Allow normal request creation workflow.

### Local Default Behavior

When any fallback condition occurs:

1. Do not block request creation.
2. Do not overwrite user-selected categories.
3. Return `NO_SUGGESTION`.
4. Continue processing using local application logic.
5. Record diagnostic information when appropriate.

This ensures the application remains functional regardless of provider availability or classification quality.

---

## Error Handling Flow

```text
User Submits Request
          |
          v
Screen Input For Personal Data
          |
          v
Personal Data Detected?
     /           \
   Yes           No
    |             |
Redact        Continue
Sensitive        |
Data             v
          Send To Classifier
                  |
                  v
         Provider Response?
            /        \
          No         Yes
          |            |
          v            v
    NO_SUGGESTION   Confidence
                     Check
                        |
                        v
              Confidence Valid?
                  /        \
                No         Yes
                |            |
                v            v
          NO_SUGGESTION   Category Mapping
                               |
                               v
                      Category Mapped?
                         /        \
                       No         Yes
                       |            |
                       v            v
                NO_SUGGESTION   App Category
                       \          /
                        \        /
                         v      v
                 Continue Request Creation
```

### Flow Description

1. User submits a request.
2. Input is screened for personal information.
3. Personal information is removed or masked before any provider boundary.
4. Classification is attempted.
5. Timeout, provider errors, low-confidence results, or unmapped categories return `NO_SUGGESTION`.
6. Request creation continues regardless of classification outcome.
7. User-selected categories are preserved.

---

## Demonstration Cases

The following cases use simulated provider responses only. No external provider calls are required.

### Timeout

Scenario:

The provider does not return a response within the allowed time window.

Expected Result:

- Return `NO_SUGGESTION`
- Allow request creation
- Preserve user-selected category
- Record timeout event

Outcome:

```text
NO_SUGGESTION
Request Created
```

### Provider Error

Scenario:

The provider returns an error or is unavailable.

Expected Result:

- Return `NO_SUGGESTION`
- Allow request creation
- Preserve existing category values

Outcome:

```text
NO_SUGGESTION
Request Created
```

### Empty Input

Scenario:

```text
""
```

Expected Result:

- Skip classification
- Return `NO_SUGGESTION`
- Allow request creation

Outcome:

```text
NO_SUGGESTION
Request Created
```

### Low Confidence Category

Scenario:

```text
Provider Category: Food & Drink
Confidence: 0.22
```

Expected Result:

- Classification considered unreliable
- Return `NO_SUGGESTION`

Outcome:

```text
NO_SUGGESTION
Request Created
```

### Unmapped Category

Scenario:

```text
Provider Category: Entertainment
```

Expected Result:

- Category cannot be mapped
- Return `NO_SUGGESTION`

Outcome:

```text
NO_SUGGESTION
Request Created
```

### Personal Data Detection

Scenario:

```text
My name is Jane Doe.
My phone number is 555-123-4567.
I live at 123 Main Street.
I need help getting groceries.
```

Expected Result:

- Detect personal information
- Remove or mask personal details
- Continue classification using sanitized text

Sanitized Example:

```text
[REDACTED_NAME]
[REDACTED_PHONE]
[REDACTED_ADDRESS]
I need help getting groceries.
```

Outcome:

```text
Sensitive Data Removed
Classification Continued
Request Created
```

### Required Safety Outcome

For all scenarios:

- Request creation continues.
- User-selected categories are preserved.
- Classification failures never block application functionality.
- Fallback result is `NO_SUGGESTION`.

---

## Verification

### Command

```bash
python ai/classification/google_cloud_nl_fallback_demo.py
```

### Expected Output

```text
Case: Timeout
Result: NO_SUGGESTION
Request Created: True

Case: Provider Error
Result: NO_SUGGESTION
Request Created: True

Case: Empty Input
Result: NO_SUGGESTION
Request Created: True

Case: Low Confidence
Result: NO_SUGGESTION
Request Created: True

Case: Unmapped Category
Result: NO_SUGGESTION
Request Created: True

Case: Personal Data Detection
Result: SANITIZED_AND_CONTINUED
Request Created: True

All fallback scenarios passed.
```

The demonstration uses simulated provider responses only and makes no external API calls. All fallback scenarios return the documented safe behavior while allowing request creation to continue.

---

## Team Review

Reviewer: Haley

Status: All passed

Date: 11/6/26 10:35AM