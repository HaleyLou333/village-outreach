import re


def normalize_text(text: str) -> str:
    """
    Normalize user-provided text for local classification.

    Rules:
    - Handle None safely
    - Trim leading/trailing whitespace
    - Collapse repeated whitespace into a single space
    - Return an empty string deterministically
    """

    if text is None:
        return ""

    text = text.strip()

    if not text:
        return ""

    return re.sub(r"\s+", " ", text)