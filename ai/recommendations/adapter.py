from dataclasses import dataclass


@dataclass
class RecommendationResult:
    recommendation_type: str
    result_source: str
    confidence: float = 0.0


class RecommendationAdapter:
    def recommend(self, text: str) -> RecommendationResult:
        return RecommendationResult(
            recommendation_type="NO_SUGGESTION",
            result_source="mock",
            confidence=0.0,
        )