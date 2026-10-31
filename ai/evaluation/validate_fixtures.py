import json
from pathlib import Path

VALID_LABELS = {
    "FOOD_ASSISTANCE",
    "TRANSPORTATION",
    "CHILDCARE",
    "DONATED_ITEMS",
    "DELIVERY_HELP",
    "LOCAL_SERVICES",
    "NO_SUGGESTION",
}

REQUIRED_FIELDS = {
    "id",
    "input_text",
    "expected_category",
    "scenario_tags",
}


def main():
    fixture_file = Path("ai/evaluation/fixtures.jsonl")

    ids = set()
    errors = []

    with open(fixture_file, "r", encoding="utf-8") as file:
        for line_number, line in enumerate(file, start=1):
            line = line.strip()

            if not line:
                continue

            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                errors.append(
                    f"Line {line_number}: malformed JSON"
                )
                continue

            missing_fields = REQUIRED_FIELDS - record.keys()

            if missing_fields:
                errors.append(
                    f"Line {line_number}: missing fields {missing_fields}"
                )

            record_id = record.get("id")

            if record_id in ids:
                errors.append(
                    f"Duplicate ID: {record_id}"
                )
            else:
                ids.add(record_id)

            label = record.get("expected_category")

            if label not in VALID_LABELS:
                errors.append(
                    f"Unsupported label: {label}"
                )

    if errors:
        print("VALIDATION FAILED")
        print("-----------------")

        for error in errors:
            print(error)

        raise SystemExit(1)

    print("VALIDATION PASSED")
    print(f"Validated {len(ids)} fixtures successfully.")


if __name__ == "__main__":
    main()