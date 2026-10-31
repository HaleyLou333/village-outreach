# Village Outreach AI Evaluation Dataset

This directory contains synthetic evaluation fixtures used for preprocessing and classification testing.

## Dataset Purpose

The fixtures in this directory are used to:

- Verify preprocessing behavior
- Verify category classification behavior
- Test edge cases
- Provide repeatable evaluation data for future AI development

All examples in this dataset are fictional and created solely for testing purposes.

## Fields Eligible for Future Provider Processing

After privacy screening, the following field may be eligible for provider processing:

- input_text

## Fields Excluded From Provider Processing

The following fields must never be sent to an external provider:

- id
- expected_category
- scenario_tags

## Validation

Run the following command from the repository root:

```bash
python ai/evaluation/validate_fixtures.py
```

Validation checks include:

- Malformed JSON records
- Duplicate fixture IDs
- Missing required fields
- Unsupported category labels

## Privacy Rules

Free-text input may contain personal information such as:

- Names
- Phone numbers
- Email addresses
- Home addresses
- Account identifiers
- Location information

All free-text content must be reviewed through privacy screening before any external provider processing occurs.

No real user records, credentials, secrets, or personal data may be stored in this dataset.

Only synthetic test examples are permitted.