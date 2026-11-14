from adapter import (
    ClassificationAdapter,
    ClassificationResult,
)

from category_mapping import (
    CATEGORY_MAP,
    MAPPING_VERSION,
)


class GoogleClassifier(ClassificationAdapter):
    MIN_CONFIDENCE = 0.50

    def classify(self, text: str) -> ClassificationResult:
        """
        Handles short or unsupported text before
        category mapping is attempted.
        """

        if text is None:
            return ClassificationResult(
                category="NO_SUGGESTION",
                result_source="google",
                confidence=0.0,
                mapping_version=MAPPING_VERSION,
            )

        text = text.strip()

        if len(text) < 3:
            return ClassificationResult(
                category="NO_SUGGESTION",
                result_source="google",
                confidence=0.0,
                mapping_version=MAPPING_VERSION,
            )

        # Placeholder until live provider integration
        return ClassificationResult(
            category="NO_SUGGESTION",
            result_source="google",
            confidence=0.0,
            mapping_version=MAPPING_VERSION,
        )

    def classify_provider_response(
            self,
            provider_category: str,
            confidence: float,
    ) -> ClassificationResult:

        # Low confidence
        if confidence < self.MIN_CONFIDENCE:
            return ClassificationResult(
                category="NO_SUGGESTION",
                result_source="google",
                confidence=confidence,
                mapping_version=MAPPING_VERSION,
            )

        # Unmapped category
        if provider_category not in CATEGORY_MAP:
            return ClassificationResult(
                category="NO_SUGGESTION",
                result_source="google",
                confidence=confidence,
                mapping_version=MAPPING_VERSION,
            )

        return ClassificationResult(
            category=CATEGORY_MAP[provider_category],
            result_source="google",
            confidence=confidence,
            mapping_version=MAPPING_VERSION,
        )
