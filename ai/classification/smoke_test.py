from adapter import ClassificationAdapter


def main():
    adapter = ClassificationAdapter()

    result = adapter.classify(
        "I need help getting groceries."
    )

    print("Smoke test passed")
    print(result)


if __name__ == "__main__":
    main()