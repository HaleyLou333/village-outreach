# AI Data Flow

```text
Raw User Input
       |
       v
Privacy Screening
       |
   +---+---+
   |       |
PII Found  Clean Text
   |       |
   v       v
Local      Eligible Text
Review           |
                 v
        Classification
                 |
                 v
         Category Suggestion
```

## Description

1. User submits request text.
2. Privacy screening checks for potential personal information.
3. Requests containing potential PII may require local review.
4. Eligible text may proceed to classification.
5. Classification produces a suggested category.
6. If classification is unavailable or uncertain, local/manual review is used as a fallback.