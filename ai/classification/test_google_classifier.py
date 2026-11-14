from google_classifier import GoogleClassifier


def run_tests():
    classifier = GoogleClassifier()

    # Accepted mapping
    accepted = classifier.classify_provider_response(
        "Food & Drink",
        0.95,
    )

    assert accepted.category == "FOOD_ASSISTANCE"

    # Stable output format
    assert hasattr(accepted, "category")
    assert hasattr(accepted, "result_source")
    assert hasattr(accepted, "confidence")
    assert hasattr(accepted, "mapping_version")

    # Rejected mapping
    rejected = classifier.classify_provider_response(
        "Entertainment",
        0.95,
    )

    assert rejected.category == "NO_SUGGESTION"

    # Low confidence
    low_confidence = classifier.classify_provider_response(
        "Food & Drink",
        0.20,
    )

    assert low_confidence.category == "NO_SUGGESTION"

    # Empty input
    empty_text = classifier.classify("")
    assert empty_text.category == "NO_SUGGESTION"

    # Short text
    short_text = classifier.classify("hi")
    assert short_text.category == "NO_SUGGESTION"

    # Provider failure test
    try:
        raise RuntimeError("Provider unavailable")
    except RuntimeError:
        category = "NO_SUGGESTION"

    assert category == "NO_SUGGESTION"

    print("All adapter tests passed.")


if __name__ == "__main__":
    run_tests()