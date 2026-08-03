# Fieldnotes plans

This directory is the durable project-planning home for Fieldnotes. It exists so product context, decisions, and execution order survive individual Codex tasks and conversations.

## Sources of truth

- [TestFlight self-trial plan](testflight-self-trial.md) describes the active outcome, sequence, release gates, and handoff context.
- [Decision log](decisions.md) records accepted, provisional, and open product or technical decisions.
- [TestFlight readiness](../docs/testflight-readiness.md) is the enduring release-readiness checklist.
- [GitHub Issues](https://github.com/schalkneethling/fieldnotes/issues) are authoritative for individual work-item status, priority, and completion.

## Tracking rules

1. Put executable work in a GitHub issue and link it from the active plan or its parent epic.
2. Record decisions that affect product behavior, architecture, privacy, compatibility, or scope in `decisions.md`.
3. Update the active plan when sequencing, release gates, trial hardware, or scope changes.
4. Keep issue completion in GitHub instead of duplicating checkbox state in multiple Markdown files.
5. Include plan and decision updates in the same change as the implementation when practical.
6. End substantial work with a short handoff note in the relevant issue: what changed, what was verified, and what remains.

## Starting a new Codex task

Ask the task to read, in order:

1. `plans/README.md`
2. `plans/testflight-self-trial.md`
3. `plans/decisions.md`
4. The GitHub issue being worked on

That is the minimum context needed to resume without relying on chat history.
