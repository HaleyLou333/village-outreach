from preprocessing import normalize_text
from mock_classifier import MockClassifier


def run_tests():
    classifier = MockClassifier()

    # Normalization
    assert normalize_text("  hello   world  ") == "hello world"

    # Empty input
    assert normalize_text("") == ""
    assert normalize_text(None) == ""

    # Supported labels
    food_result = classifier.classify(
        "I need help getting groceries"
    )
    assert food_result.category == "FOOD_ASSISTANCE"

    transport_result = classifier.classify(
        "I need a bus ride"
    )
    assert transport_result.category == "TRANSPORTATION"

    # No suggestion handling
    unknown_result = classifier.classify(
        "penguins are excellent swimmers"
    )
    assert unknown_result.category == "NO_SUGGESTION"

    # Stable output structure
    assert hasattr(food_result, "category")
    assert hasattr(food_result, "result_source")
    assert hasattr(food_result, "confidence")

    print("All smoke tests passed.")


if __name__ == "__main__":
    run_tests()