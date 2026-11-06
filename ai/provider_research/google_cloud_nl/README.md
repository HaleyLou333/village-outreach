# Google Cloud Natural Language Research

## Purpose

This document evaluates Google Cloud Natural Language (GCNL) as a potential provider for classification and suggestion features within the Village Outreach platform.

The goal of this research is to determine whether Google Cloud Natural Language can support automated categorization of user requests and provide useful signals for future recommendation and assistance features.

At the current stage of development, the project uses a local mock classifier and preprocessing pipeline. Google Cloud Natural Language is being evaluated as a future provider that could be integrated through the project's classification adapter architecture.

Research Date: 2026-11-05

Status: Research Only (No Live Integration)
---

## Supported Features

Google Cloud Natural Language provides several text analysis capabilities that may be useful within the Village Outreach platform.

### Content Classification

Content Classification assigns predefined categories to submitted text.

Potential uses:

- Categorizing incoming requests
- Supporting recommendation workflows
- Providing a starting point for app-specific category mapping

Example categories include:

- Food & Drink
- Community Services
- Education
- Health
- Shopping

### Sentiment Analysis

Sentiment Analysis measures the emotional tone of submitted text and returns sentiment scores.

Potential uses:

- Identifying potentially urgent requests
- Providing prioritization signals
- Supporting future analytics and reporting

### Entity Analysis

Entity Analysis identifies notable entities within text and classifies them into types.

Examples include:

- Organizations
- Locations
- Events
- Products
- People

Potential uses:

- Extracting community resources mentioned in requests
- Improving future recommendation systems
- Enriching request metadata

---

## Classification Limitations

Google Cloud Natural Language Content Classification uses predefined content categories rather than application-specific categories.

Limitations include:

- Categories are broad and designed for general web content.
- Custom categories cannot be trained or configured.
- Classification results may not directly match Village Outreach request types.
- Additional mapping logic is required to convert provider categories into application categories.
- Some requests may not receive a useful category and may require a fallback response.

Example category mappings:

| Google Category | App Category |
|----------------|-------------|
| Food & Drink | FOOD_ASSISTANCE |
| Law & Government / Social Services | COMMUNITY_SUPPORT |
| Health | HEALTH_SUPPORT |
| Shopping | RESOURCE_REQUEST |

Not all provider categories will have a direct application equivalent. Categories that cannot be mapped should return `NO_SUGGESTION` to prevent inaccurate recommendations.

Because the provider categories are not customizable, Google Cloud Natural Language should be treated as a classification signal rather than a complete replacement for application-specific business rules.

---

## Pricing Summary

Google Cloud Natural Language pricing is based on Unicode character usage.

Key pricing notes:

- Usage is measured in 1,000-character units.
- Character counts include whitespace and markup.
- Requests are rounded up to the nearest 1,000-character unit.
- Pricing varies by feature type.

Common feature pricing:

| Feature | Free Tier | Standard Price |
|----------|------------|---------------|
| Entity Analysis | First 5,000 units/month | $1.00 per 1,000-character unit |
| Sentiment Analysis | First 5,000 units/month | $1.00 per 1,000-character unit |
| Content Classification | First 5,000 units/month | $2.00 per 1,000-character unit |

For prototype and classroom-scale usage, the free tier may be sufficient for testing and evaluation purposes.

Pricing should be reviewed before any production deployment because costs scale with request volume and text length.

---

## Latency and Reliability Notes

As a cloud-hosted service, Google Cloud Natural Language requires network communication between the application and Google Cloud infrastructure.

### Latency Considerations

Advantages:

- No local model hosting is required.
- Processing is handled by managed cloud infrastructure.
- Scales automatically with demand.

Potential Challenges:

- Requests require internet connectivity.
- Response times may vary depending on network conditions.
- Cloud API calls will generally be slower than local function calls.

### Reliability Considerations

Advantages:

- Managed service maintained by Google Cloud.
- Designed for high availability and scalability.
- Reduces operational overhead compared to self-hosted models.

Potential Risks:

- Service disruptions could temporarily prevent classifications.
- API quota or billing issues may block requests.
- Changes to provider-supported categories could affect mapping behavior.

### Recommended Fallback Strategy

1. Submit text to the provider.
2. Validate the returned category and confidence score.
3. Map the provider category to an application category.
4. If no valid mapping exists, return `NO_SUGGESTION`.
5. If the provider is unavailable, use the local mock classifier during development and testing.

This approach helps ensure application functionality continues even when the external provider cannot return a usable result.

---

## Applicability to Village Outreach

Google Cloud Natural Language appears to be a reasonable candidate for providing general classification signals within the Village Outreach platform.

Potential strengths include:

- Managed cloud-based infrastructure requiring no model hosting.
- Built-in content classification capabilities.
- Additional sentiment and entity analysis features that may support future enhancements.
- Simple integration through the planned classifier adapter interface.

However, the platform's request categories are more specific than the provider's predefined content categories.

Examples include:

- Food assistance requests
- Transportation requests
- Community support requests
- Resource requests

Because Google Cloud Natural Language does not support custom category training, provider results would need to be mapped to application-specific categories before being used by the system.

As a result, Google Cloud Natural Language is best viewed as a supporting classification provider rather than a complete classification solution. Application-level mapping rules and fallback behavior remain necessary to ensure consistent results.

For early development and testing, the existing local mock classifier provides a reliable substitute that allows classification workflows to be developed without requiring access to live cloud services.

---

## Simulated Mapping Proof of Concept

The following examples demonstrate how simulated Google Cloud Natural Language classification responses could be mapped to Village Outreach application categories.

These examples are synthetic fixtures created for evaluation purposes only and do not represent live provider responses.

### Example Provider Responses

| Provider Category | Confidence | App Category |
|------------------|------------|--------------|
| Food & Drink | 0.92 | FOOD_ASSISTANCE |
| Law & Government / Social Services | 0.89 | COMMUNITY_SUPPORT |
| Health | 0.85 | HEALTH_SUPPORT |
| Shopping | 0.78 | RESOURCE_REQUEST |
| Unknown Category | 0.12 | NO_SUGGESTION |

### Category Mapping

Example mapping rules:

| Provider Category | Application Category |
|------------------|---------------------|
| Food & Drink | FOOD_ASSISTANCE |
| Law & Government / Social Services | COMMUNITY_SUPPORT |
| Health | HEALTH_SUPPORT |
| Shopping | RESOURCE_REQUEST |

The application is responsible for translating provider-specific categories into categories recognized by Village Outreach.

### Unsupported Categories

Some provider categories may not correspond to a valid application category.

Examples:

- Entertainment
- Sports
- Arts & Culture

Unsupported categories should not generate recommendations without additional application-specific logic.

### No Suggestion Behavior

The system should return `NO_SUGGESTION` when:

- No provider category is returned.
- Confidence scores fall below an acceptable threshold.
- The provider category cannot be mapped to an application category.
- The provider service is unavailable and no valid fallback result exists.

This behavior helps prevent inaccurate classifications and misleading recommendations.

---

## Verification

### Command

```bash
python ai/classification/google_cloud_nl_demo.py
```

### Expected Output

```text
Provider Category: Food & Drink
Mapped Category: FOOD_ASSISTANCE

Provider Category: Law & Government / Social Services
Mapped Category: COMMUNITY_SUPPORT

Provider Category: Health
Mapped Category: HEALTH_SUPPORT

Provider Category: Shopping
Mapped Category: RESOURCE_REQUEST

Provider Category: Unknown Category
Mapped Category: NO_SUGGESTION

Verification Passed
```

The verification uses simulated provider responses and validates that category mappings behave as expected.

---

## Sources

1. Google Cloud Natural Language Documentation
   Accessed: 2026-11-05

2. Google Cloud Natural Language Pricing
   Accessed: 2026-11-05

Research notes derived from official Google Cloud documentation and pricing references used to evaluate provider suitability for Village Outreach.