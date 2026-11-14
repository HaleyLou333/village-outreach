# Baseline Classification

## Run Baseline

```bash
python ai/classification/run_baseline.py
```

Example Output

```text
Baseline run completed
Processed: 20
No Suggestion: 5
Output: ai/classification/processed_results.jsonl
```

## Run Tests

```bash
python ai/classification/smoke_test.py
```

Example Output

```text
All smoke tests passed.
```

## Architecture

Current implementation:

```text
Fixtures
    ↓
Preprocessing
    ↓
MockClassifier
    ↓
Processed Results
```

The MockClassifier implements the adapter interface and may be replaced in the future by a Google Cloud Natural Language implementation without changing downstream consumers.