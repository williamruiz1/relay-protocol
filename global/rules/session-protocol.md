# Session Protocol — Universal Habits

> These habits apply to every workspace. Workspace-specific surfaces, paths, and conventions live in `<workspace>/.claude/rules/`.

## Session Lifecycle

Every agent session follows this loop:

```
Start → Read context → Confirm assignment → Build → Verify → Hand off
```

### 1. Start: Establish a baseline

A global `SessionStart` hook writes the current HEAD SHA to `.claude/.hook-session-start`. This marks where the session began so diffs are accurate — no prior session's unpushed commits get mis-attributed.

### 2. Read context before acting

Read the workspace's command center (`CLAUDE.md` or equivalent) and any "Next Session" assignment block before writing code. Context is in the planning surfaces, not in conversation memory.

### 3. Hand off at session end

Every session that modifies source files must produce a **handoff artifact** — a self-contained narrative document describing what changed, what decisions were made, what works, what doesn't, and what's next.

Rules for handoff artifacts:
- **Self-contained** — no "see previous session" references. The next agent starts cold.
- **Stored as a file** — typically `docs/handoffs/<workstream-id>.md` or equivalent.
- **Structured** — use the handoff template (see `global/rules/handoff-template.md` in this repo, or `~/.claude/rules/handoff-template.md` once installed).

### 4. Update planning surfaces

If the workspace defines planning surfaces (via `.claude/protocol-config.json` or workspace-specific rules), update them before closing. The session is not done until close artifacts exist.

Common surfaces (workspace-specific — not all are required):
- **Handoff doc** — the narrative artifact
- **Workstream tracker** — what's in flight, what's next
- **State inventory** — machine-readable counts, known issues
- **Session history** — thin index of sessions (one-liner per entry, not narratives)
- **Roadmap** — feature tree or visual plan (only if the workspace has one)

### 5. Never rely on conversation memory for continuity

Everything an agent needs to pick up where you left off should be in files. Plans, decisions, blockers, next steps — persist them to planning surfaces, not to memory or conversation context.
