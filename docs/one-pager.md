# Relay Protocol

**Your AI agents forget everything between sessions. Relay Protocol fixes that.**

---

## The Problem

Every time an AI coding agent starts a new session, it starts cold. It doesn't remember what it built last time, what decisions were made, what's broken, or what's next. The result:

- Work gets repeated because the agent doesn't know it was already done
- Decisions get re-debated because nobody wrote down the "why"
- Files drift out of sync because the agent forgot to update the tracker
- The next agent wastes its first 10 minutes piecing together what happened

This isn't a model problem. It's a process problem. Agents don't have habits.

## The Fix

Relay Protocol gives AI agents a simple, enforceable routine:

**Start** — Mark where the session begins so diffs are accurate.

**Build** — Do the work. The agent gets periodic reminders about what needs updating.

**Hand off** — Before the session can close, the agent must update every planning surface: a handoff doc describing what changed, a tracker showing what's next, and whatever else the workspace defines. A hook blocks session close until this is done.

That's it. The baton gets passed cleanly. The next agent reads the handoff and starts immediately.

## How It Works

Two pieces, both lightweight:

**Global habits** install once on your machine. A rules file teaches agents the session lifecycle. A hook marks the starting point of every session automatically. These travel with you across every project.

**Workspace surfaces** are configured per repo. A single JSON file declares what the agent must update before closing — handoff docs, trackers, state files, whatever your project needs. A shell script reads that config and enforces it. No code changes. No dependencies. Just a config file and two hooks.

The enforcement hook only fires when source files change. If an agent just edits docs or config, it passes through freely. When real code changes, the gate closes until the surfaces are current.

## What You Get

- **Zero lost context** — every session produces a self-contained handoff artifact
- **No drift** — planning surfaces stay in sync because the agent literally can't skip them
- **Cold start in seconds** — the next agent reads the handoff and knows exactly where to pick up
- **Workspace flexibility** — each repo defines its own surfaces; the habits are universal
- **No vendor lock-in** — plain shell scripts and markdown files; works with any AI coding tool that supports hooks

## Who It's For

Anyone running AI coding agents across multiple sessions on the same codebase. Solo developers using Claude Code, Cursor, or Copilot. Teams where multiple agents (or agent + human) take turns on a repo. Projects where continuity matters more than speed.

## One-Line Pitch

> Relay Protocol is the difference between an agent that builds and forgets, and one that builds and passes the baton.

---

*MIT Licensed. https://github.com/williamruiz1/relay-protocol*
