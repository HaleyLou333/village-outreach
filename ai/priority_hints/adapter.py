from dataclasses import dataclass


RULES_VERSION = "v1"

PRIORITY_HINTS_ENABLED = True

@dataclass
class PriorityHintResult:
    hint: str
    result_source: str
    explanation: str
    rules_version: str = RULES_VERSION


class PriorityHintAdapter:
    def suggest(self, text: str) -> PriorityHintResult:
        text = text.strip()
        normalized = text.lower()

        if not PRIORITY_HINTS_ENABLED:
            return PriorityHintResult(
                hint="NO_HINT",
                result_source="disabled",
                explanation="Priority hints are disabled.",
            )

        if len(text) < 20:
            return PriorityHintResult(
                hint="NO_HINT",
                result_source="rules",
                explanation="Input is too short to determine urgency.",
            )

        emergency_terms = (
            "suicide",
            "overdose",
            "heart attack",
            "not breathing",
            "emergency",
        )

        time_sensitive_terms = (
            "eviction",
            "utility cut",
            "utility shut",
            "baby formula",
            "running low on medication",
            "low on medication",
            "last minute childcare",
            "last-minute childcare",
            "low on pet food",
            "out of pet food",
        )

        if any(term in normalized for term in emergency_terms):
            return PriorityHintResult(
                hint="NO_HINT",
                result_source="rules",
                explanation=(
                    "Emergency-related language detected. "
                    "Provide emergency guidance rather than a priority hint."
                ),
            )

        if any(term in normalized for term in time_sensitive_terms):
            return PriorityHintResult(
                hint="TIME_SENSITIVE",
                result_source="rules",
                explanation=(
                    "Request contains reviewed time-sensitive indicators."
                ),
            )

        return PriorityHintResult(
            hint="NO_HINT",
            result_source="mock",
            explanation="Priority hints not configured.",
        )