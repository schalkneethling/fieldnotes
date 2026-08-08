# Fieldnotes Claude guidance

- Read `AGENTS.md`, `plans/README.md`, the active plan, and `plans/decisions.md` before substantial work.
- Never commit or push directly to `main`. Create or use a `codex/` branch and deliver changes through a pull request.
- **Cost is proportional to the change, not the store.** An operation on one item should not read the whole collection. Ask the storage layer for the aggregate you need. Maintain a running total only when you can write it in the same transaction as the data it describes and reconcile it on a known schedule.
- **Construction is not a predicate.** If you build a value only to discard it, the question you are asking is a predicate and the construction is the cost of not having one. Extract the predicate into a surface both the builder and the caller invoke, so that the number of places the rule is defined stays the same.
