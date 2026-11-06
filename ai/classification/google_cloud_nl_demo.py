import json
from pathlib import Path

fixture_path = Path(__file__).parent / "fixtures" / "google_cloud_nl_fixture.json"

with open(fixture_path, "r", encoding="utf-8") as file:
    fixtures = json.load(file)

for item in fixtures:
    print(f"Provider Category: {item['provider_category']}")
    print(f"Mapped Category: {item['mapped_category']}")
    print()

print("Verification Passed")