# Jira and GitHub Integration Workflow

## Purpose

Village Outreach uses Jira as the primary task backlog and project management system.

GitHub Issues are not created for every Jira task. Instead, development work is tracked through Jira work items linked to GitHub branches, commits, pull requests, and reviews.

---

## CCVO Key Convention

Jira work item identifiers should be referenced in development artifacts whenever possible.

Examples:

### Branch Names

```text
feature/ccvo-53-provider-research
feature/ccvo-55-safety-rules
feature/ccvo-58-baseline-classifier
```

### Commit Messages

```text
CCVO-53 Add Google Cloud NL provider research

CCVO-55 Add safety rules and fallback documentation

CCVO-58 Complete baseline preprocessing and mock classifier
```

### Pull Request Titles

```text
CCVO-53 Research Google Cloud Natural Language provider capabilities

CCVO-55 Define safety and fallback rules

CCVO-58 Build baseline preprocessing and mock classifier
```

---

## Pull Request Requirements

Every pull request should include:

- Jira work item ID
- Summary of changes
- Testing performed
- Reviewer name
- Verification commands when applicable

Example:

```md
## Jira Task

CCVO-58

## Summary

Implemented baseline preprocessing pipeline and local mock classifier.

## Testing

python ai/classification/run_baseline.py

python ai/classification/smoke_test.py

## Reviewer

Eric
```

---

## Completion Evidence

Evidence of task completion may include:

- Linked GitHub branch
- Commit history
- Pull request
- Review comments
- Verification output
- Demonstration screenshots

Work items should not be marked complete until required deliverables have been implemented and reviewed.

---

## Example Linkage

Example:

Jira Issue:

```text
CCVO-58
```

Branch:

```text
feature/ai
```

Pull Request:

```text
Sprint 3 AI: CCVO-53, CCVO-55, and CCVO-58
```

Review Status:

```text
Pending Review
```

This demonstrates linkage between the Jira work item, GitHub branch, pull request, and review process without marking unfinished work as completed.