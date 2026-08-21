# Stacked pull requests

Use this guide when a task asks for a **stacked pull request** or when a substantial change naturally divides into dependent, independently reviewable layers.

GitHub defines a stack as two or more pull requests in one repository. The bottom pull request targets the trunk branch (`main` for Fieldnotes), and each pull request above it targets the branch immediately below it. GitHub's overview and current public-preview behavior are documented in [Stacked pull requests](https://docs.github.com/en/pull-requests/how-tos/stacked-pull-requests).

## When to use a stack

Use a stack when later work genuinely depends on an earlier foundation, such as:

- a persistence boundary followed by integration tests and then UI flows;
- a model or migration followed by repository behavior and presentation;
- test infrastructure followed by the critical flows that use it.

Do not stack unrelated changes merely to publish them together. Give independent work separate pull requests against `main`.

## Branch and pull-request shape

Build from bottom to top:

```text
main
└── codex/foundation          → PR 1, base: main
    └── codex/integration     → PR 2, base: codex/foundation
        └── codex/ui-flows    → PR 3, base: codex/integration
```

Every layer must:

1. Have one focused purpose and remain reviewable against the branch below it.
2. Include the implementation and proportionate tests for that layer.
3. State its base branch, dependencies, validation, and full stack order in the pull-request description.
4. Use a `codex/` branch and a draft pull request unless the user explicitly requests otherwise.
5. Keep executable work linked to its GitHub issue and leave durable decisions in `plans/decisions.md`.

## Creating a stack

Prefer GitHub's official `gh stack` extension:

```sh
gh stack init --base main codex/foundation
# edit, validate, and commit the bottom layer
gh stack add codex/integration
# edit, validate, and commit the next layer; repeat as needed
gh stack submit
```

If the extension is unavailable, create the same branch chain with Git and set each pull request's base to the branch immediately below it. Native GitHub stacks require all branches to live in the same repository.

## Reviewing and updating

- Review from the bottom upward so each dependency is understood before its consumers.
- Put a requested change on the branch that owns the affected code, not automatically on the top branch.
- After changing a lower layer, run `gh stack rebase` and `gh stack push` so every higher layer receives the update safely.
- Revalidate the changed layer and all affected layers above it.
- Never force-push with an unqualified `--force`; the stack tooling uses the safer `--force-with-lease` behavior when rebasing.

## Merging

Merge from the bottom upward. GitHub can merge a contiguous portion of the stack, but the lowest unmerged pull request must always be included. After a lower layer merges, GitHub rebases and retargets the next layer onto `main`.

Before merging a layer, verify that it and all layers below it have passing checks and resolved review findings. The stack is complete only when every layer has merged and `main` passes the release-gate checks.
