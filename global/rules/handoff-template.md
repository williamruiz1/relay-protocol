# Handoff Template

> Use this structured format for handoff logs. Each handoff must be self-contained — never reference previous handoffs for context.

```markdown
# Session [N]: [Title]

## Session Summary
Intent: [1-2 sentences describing what this session set out to accomplish]
Status: [complete | partial | blocked]

## Files Modified
- `path/to/file1` — [what changed]
- `path/to/file2` — [what changed]

## Decisions Made
1. [Decision and rationale]
2. [Decision and rationale]

## Current State
### What works
- [Feature/endpoint/component that is functional]

### What doesn't
- [Known issue or incomplete item]

## Next Steps
1. [Specific, actionable task with file paths]
2. [Specific, actionable task with file paths]
3. [Any blockers or dependencies to resolve]
```

## Guidelines

- **File paths must be repo-relative** (e.g., `src/routes/foo.ts`, `apps/api/src/db/migrations/149-foo.sql`)
- **Decisions section** captures non-obvious choices so future sessions don't re-debate them
- **Current State** must distinguish working vs broken — no ambiguity
- **Next Steps** should be specific enough that a new agent can start immediately
