import json
from pathlib import Path

from preprocessing import normalize_text
from mock_classifier import MockClassifier


FIXTURE_FILE = Path("ai/evaluation/fixtures.jsonl")
OUTPUT_FILE = Path("ai/classification/processed_results.jsonl")


def main():
    classifier = MockClassifier()

    processed = 0
    no_suggestion = 0

    with open(FIXTURE_FILE, "r", encoding="utf-8") as source, \
            open(OUTPUT_FILE, "w", encoding="utf-8") as output:

        for line in source:
            record = json.loads(line)

            fixture_id = record.get("id")
            raw_text = record.get("input_text", "")

            normalized_text = normalize_text(raw_text)

            result = classifier.classify(normalized_text)

            processed_record = {
                "id": fixture_id,
                "normalized_text": normalized_text,
                "category": result.category,
                "result_source": result.result_source,
                "confidence": result.confidence,
            }

            output.write(json.dumps(processed_record) + "\n")

            processed += 1

            if result.category == "NO_SUGGESTION":
                no_suggestion += 1

    print("Baseline run completed")
    print(f"Processed: {processed}")
    print(f"No Suggestion: {no_suggestion}")
    print(f"Output: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()