from dataclasses import dataclass


@dataclass
class ClassificationResult:
    category: str
    result_source: str
    confidence: float = 0.0


class ClassificationAdapter:
    def classify(self, text: str) -> ClassificationResult:
        """
        Placeholder adapter contract.

        Future implementations may:
        - Use local rules
        - Use Google Cloud Natural Language
        - Use another approved provider

        Returns a ClassificationResult.
        """
        return ClassificationResult(
            category="NO_SUGGESTION",
            result_source="mock",
            confidence=0.0,
        )