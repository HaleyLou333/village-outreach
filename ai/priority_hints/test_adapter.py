import adapter
from adapter import PriorityHintAdapter


def run_tests():
    priority_adapter = PriorityHintAdapter()

    # Short / ambiguous input
    result = priority_adapter.suggest("help")

    assert result.hint == "NO_HINT"
    assert result.result_source == "rules"
    assert result.rules_version == "v1"

    # Emergency wording
    emergency = priority_adapter.suggest(
        "My neighbor is having a heart attack and is not breathing."
    )

    assert emergency.hint == "NO_HINT"
    assert "Emergency-related language detected" in emergency.explanation

    # Time-sensitive wording
    time_sensitive = priority_adapter.suggest(
        "I received an eviction notice and need help paying rent."
    )

    assert time_sensitive.hint == "TIME_SENSITIVE"
    assert time_sensitive.result_source == "rules"

    # Misleading negative sentiment should not determine urgency
    sentiment_only = priority_adapter.suggest(
        "Everything is terrible and I hate my situation right now."
    )

    assert sentiment_only.hint == "NO_HINT"

    # Disabled-feature fallback
    adapter.PRIORITY_HINTS_ENABLED = False

    disabled = adapter.PriorityHintAdapter().suggest(
        "I received an eviction notice and need help."
    )

    assert disabled.hint == "NO_HINT"
    assert disabled.result_source == "disabled"

    adapter.PRIORITY_HINTS_ENABLED = True

    print("All priority hint tests passed.")


if __name__ == "__main__":
    run_tests()