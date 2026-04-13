# Relay Protocol

Session discipline for AI coding agents. Ensures clean handoffs between sessions so no context is lost, no surfaces are forgotten, and the next agent can start cold.

## The Problem

AI agents lose context between sessions. Conversation memory compacts, gets truncated, or simply isn't available to the next agent. Work gets lost. Decisions get re-debated. Surfaces drift out of sync.

## The Solution

Relay Protocol gives agents a repeatable session lifecycle:

```
Start → Read context → Build → Verify → Hand off
```

Every session that modifies source files must update **planning surfaces** (handoff docs, trackers, state files) before closing. A Stop hook enforces this — the agent can't finish until the baton is passed cleanly.

## Architecture

The system has two layers:

### Global — Universal Habits

Installed once per machine. Teaches agents *how* to work regardless of workspace.

```
~/.claude/
├── rules/
│   ├── session-protocol.md     # Session lifecycle (start → handoff)
│   └── handoff-template.md     # Structured handoff format
├── hooks/
│   └── session-start-marker.sh # Marks HEAD SHA as session baseline
└── settings.json               # Hook registrations
```

### Workspace — Scoped Surfaces

Copied per workspace. Defines *what* to update in each specific repo.

```
<workspace>/.claude/
├── hooks/
│   ├── verify-session-discipline.sh  # Stop hook — blocks until surfaces updated
│   └── protocol-reminder.sh          # Reminds agent about surfaces on each prompt
├── protocol-config.json              # Declarative surface definitions
└── settings.json                     # Hook registrations
```

## Quick Start

### 1. Install global layer

```bash
# Copy rules
mkdir -p ~/.claude/rules
cp global/rules/*.md ~/.claude/rules/

# Copy hooks
mkdir -p ~/.claude/hooks
cp global/hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/.claude/hooks/session-start-marker.sh\"",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Add to `~/.claude/CLAUDE.md`:

```markdown
## Session Protocol

Every agent session follows a start → build → handoff loop.
See `~/.claude/rules/session-protocol.md` for the full protocol.
```

### 2. Adopt in a workspace

```bash
cd <your-workspace>
mkdir -p .claude/hooks docs/handoffs

# Copy hooks and config
cp <relay-protocol>/workspace/hooks/*.sh .claude/hooks/
cp <relay-protocol>/workspace/protocol-config.json.example .claude/protocol-config.json
chmod +x .claude/hooks/*.sh
```

Edit `.claude/protocol-config.json` — define your surfaces:

```json
{
  "surfaces": [
    {
      "name": "handoff",
      "label": "Handoff log",
      "path": "docs/handoffs/",
      "match": "prefix"
    },
    {
      "name": "tracker",
      "label": "Workstream tracker",
      "path": ".claude/TRACKER.md",
      "match": "exact"
    }
  ],
  "sourcePatterns": ["^(src/|lib/|app/)"],
  "sourceExclusions": []
}
```

Merge hook registrations into `.claude/settings.json` (see `workspace/settings.json.example`).

### 3. Add to .gitignore

```gitignore
# Relay Protocol ephemeral state
.claude/.hook-session-start
```

## Configuration

### `protocol-config.json`

| Field | Type | Description |
|-------|------|-------------|
| `surfaces` | array | Planning surfaces the Stop hook enforces |
| `sourcePatterns` | string[] | Regex patterns identifying source files (vs docs/config) |
| `sourceExclusions` | string[] | Literal paths to exclude from source detection |

### Surface definition

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Identifier (used internally) |
| `label` | string | Human-readable name (shown in hook output) |
| `path` | string | File path for `exact` or `prefix` match |
| `paths` | string[] | Multiple paths for `anyOf` match |
| `match` | string | `exact`, `prefix`, or `anyOf` |

### Match types

- **`exact`** — the file at `path` must appear in the changed set
- **`prefix`** — any file under the `path` prefix satisfies the check (e.g., `docs/handoffs/`)
- **`anyOf`** — any one of the `paths` appearing in the changed set satisfies the check

## How it works

1. **SessionStart** (global hook) — writes HEAD SHA to `.claude/.hook-session-start`
2. **UserPromptSubmit** (workspace hook) — if `git status` shows changes, reminds the agent to update surfaces
3. **Stop** (workspace hook) — diffs against baseline, checks if source files changed, verifies all surfaces were updated. Blocks (`exit 2`) if any are missing.

The Stop hook only enforces when **source files** changed (matched by `sourcePatterns`). Doc-only or config-only sessions pass freely.

## Extending

- **Schema validation**: Add `"validateSchema": true` and `"schemaPath": "..."` to a surface entry (requires a custom Zod parser module in your workspace)
- **Exemptions**: For surfaces that aren't always relevant, create a `.claude/session-config.json` with exemption flags and teach your hook to read them
- **More surfaces**: Add entries to `protocol-config.json` — the hook reads them dynamically

## Design Principles

- **Habits are universal; state is scoped.** The session lifecycle applies everywhere. What surfaces to update is workspace-specific.
- **Files over memory.** Never rely on conversation context for continuity. Persist everything to planning surfaces.
- **Self-contained handoffs.** Each handoff must be readable without any prior context. The next agent starts cold.
- **Enforcement, not trust.** The Stop hook blocks session close — agents can't skip surfaces by forgetting.

## License

MIT
