# Evaluation Dataset Schema

Each fixture record must contain the following fields:

| Field | Type | Description |
|---------|---------|---------|
| id | string | Unique synthetic example identifier |
| input_text | string | Synthetic help request text |
| expected_category | string | Expected classification result |
| scenario_tags | array[string] | Tags describing the test scenario |

## Example

```json
{
  "id": "ex-001",
  "input_text": "I need help getting groceries this week.",
  "expected_category": "FOOD_ASSISTANCE",
  "scenario_tags": ["food"]
}
```