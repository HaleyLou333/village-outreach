from adapter import ClassificationAdapter, ClassificationResult


class MockClassifier(ClassificationAdapter):
    """
    Local baseline classifier.

    Uses simple keyword matching for synthetic test data.
    Future implementations may replace this with
    Google Cloud Natural Language or another provider.
    """

    def classify(self, text: str) -> ClassificationResult:
        text = text.lower()

        if any(word in text for word in [
            "food",
            "grocery",
            "groceries",
            "meal",
            "hungry",
            "pantry",
        ]):
            return ClassificationResult(
                category="FOOD_ASSISTANCE",
                result_source="mock",
                confidence=0.95,
            )

        if any(word in text for word in [
            "ride",
            "transportation",
            "bus",
        ]):
            return ClassificationResult(
                category="TRANSPORTATION",
                result_source="mock",
                confidence=0.95,
            )

        if any(word in text for word in [
            "childcare",
            "babysitter",
            "daycare",
            "child",
        ]):
            return ClassificationResult(
                category="CHILDCARE",
                result_source="mock",
                confidence=0.95,
            )

        if any(word in text for word in [
            "donation",
            "donated",
            "clothes",
            "furniture",
            "couch",
            "table",
            "moving",
        ]):
            return ClassificationResult(
                category="DONATED_ITEMS",
                result_source="mock",
                confidence=0.95,
            )

        if any(word in text for word in [
            "delivery",
            "deliver",
            "bring",
        ]):
            return ClassificationResult(
                category="DELIVERY_HELP",
                result_source="mock",
                confidence=0.95,
            )

        if any(word in text for word in [
            "service",
            "services",
            "resources",
            "community",
            "housing",
            "shelter",
            "utility",
            "utilities",
        ]):
            return ClassificationResult(
                category="LOCAL_SERVICES",
                result_source="mock",
                confidence=0.95,
            )

        return ClassificationResult(
            category="NO_SUGGESTION",
            result_source="mock",
            confidence=0.0,
        )