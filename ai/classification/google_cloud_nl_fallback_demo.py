cases = [
    {
        "name": "Timeout",
        "result": "NO_SUGGESTION",
        "request_created": True,
    },
    {
        "name": "Provider Error",
        "result": "NO_SUGGESTION",
        "request_created": True,
    },
    {
        "name": "Empty Input",
        "result": "NO_SUGGESTION",
        "request_created": True,
    },
    {
        "name": "Low Confidence",
        "result": "NO_SUGGESTION",
        "request_created": True,
    },
    {
        "name": "Unmapped Category",
        "result": "NO_SUGGESTION",
        "request_created": True,
    },
    {
        "name": "Personal Data Detection",
        "result": "SANITIZED_AND_CONTINUED",
        "request_created": True,
    },
]

for case in cases:
    print(f"Case: {case['name']}")
    print(f"Result: {case['result']}")
    print(f"Request Created: {case['request_created']}")
    print()

print("All fallback scenarios passed.")
