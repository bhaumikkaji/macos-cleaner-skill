---
name: macos-cleaner
description: Safely reclaim disk space on macOS by analyzing caches, build artifacts, and Docker resources, then deleting only what the user explicitly confirms. Use when disk space is low or when the user asks to clean up their Mac without risking valuable data.
---

# macOS Cleaner

A safety-first disk cleanup skill for macOS. It merges the conservative philosophy of the Claude Code `macos-cleaner` skill with a plain script-based approach. No Mole, no tmux, no background daemons. Every command runs directly through the agent's shell tool.

## Core Principles

These rules are non-negotiable and apply to every cleanup session.

1. **Never auto-delete.** Nothing is removed without explicit, per-object user confirmation. The skill proposes; the user disposes.
2. **Precision deletion only.** Delete by exact path, exact ID, or exact name. Never by broad glob, never by "everything in this directory", never by age alone.
3. **List every object individually.** Before any deletion, show the user a complete, itemized list. No "and 47 other files" summaries.
4. **Value over vanity.** Do not delete useful caches just to inflate the freed-space number. A cache that speeds up a daily workflow is worth more than the gigabytes it occupies. Report honestly, not impressively.

## Workflow

Every cleanup follows this exact sequence. Do not skip or reorder steps.

1. **Analyze (read-only).** Run only read-only commands (`du`, `ls`, `df`, `docker system df`, `docker volume ls`). Collect sizes and paths. Nothing is modified.
2. **Present findings with impact analysis.** Show an itemized report. Every item carries a classification and an "Impact If Deleted" column (see Report Format below).
3. **User confirms.** The user selects which items to delete. Only those items proceed. If the user says "delete everything", stop and re-present the list, because "everything" is not a precise selection.
4. **Execute.** Delete only the confirmed items, one at a time, by exact path or ID.
5. **Verify.** Re-run the read-only analysis and report the actual space reclaimed versus the estimate.

## What NOT to Delete

These are common "cleanup targets" that are actually valuable. Keep them. Deleting them costs more than it saves.

| Item | Why It Is Valuable | Real Cost of Deleting It |
|------|--------------------|--------------------------|
| Xcode DerivedData | Incremental build cache for iOS/macOS projects. | Full rebuilds of every project, often 10-30 minutes each. Space returns within days. |
| npm `_cacache` | Content-addressable cache for every package you have ever installed. | Every `npm install` re-downloads from the network. Slower installs, more bandwidth, no lasting space gain. |
| `~/.cache/uv` | uv's package and wheel cache for Python environments. | Every `uv sync` and `uv pip install` re-fetches wheels. Slower, network-dependent, and the cache refills immediately. |
| Playwright browsers | Downloaded browser binaries used by Playwright tests. | Tests fail until browsers are re-downloaded (hundreds of MB each). Breaks CI and local test runs. |
| iOS DeviceSupport | Symbol files for debugging on specific iOS versions. | Debugging against those iOS versions breaks. Re-downloaded on next device connect anyway. |
| Docker stopped containers | Containers preserve state, config, and are cheap to restart. | Losing a container means losing its filesystem changes and setup. Restarting is not the same as recreating. |
| `~/.cache/huggingface` | Downloaded model weights and tokenizer caches. | Multi-GB model re-downloads, often slow or rate-limited. Breaks offline inference. |
| `~/.cache/modelscope` | Same as above, for ModelScope-hosted models. | Same re-download cost. Models are large and re-fetching is expensive. |
| JetBrains caches | IDE indexes and caches for IntelliJ/WebStorm/PyCharm. | Full project re-indexing on next open, minutes of unresponsiveness per project. |

## What IS Safe to Delete

These are genuinely safe targets. Still present them itemized and confirm each.

| Item | Notes |
|------|-------|
| Trash (`~/.Trash`) | User-visible trash. Confirm the user is done with it. |
| Homebrew old versions | `brew cleanup` removes outdated formula versions. Safe, but show what it will remove first. |
| npm `_npx` | Cached npx packages. Safe to clear; npx re-fetches on demand. |
| Orphaned app remnants | `~/Library/Application Support`, `~/Library/Caches`, `~/Library/Preferences` entries for apps the user has uninstalled. Verify the app is truly gone before deleting. |
| Specific unused Docker volumes | Only volumes the user confirms are unused, by exact name or ID. See Docker rules below. |

## Docker Safety Rules

Docker is where cleanup goes wrong most often. Follow these rules strictly.

1. **NEVER use prune-family commands.** `docker image prune`, `docker volume prune`, `docker system prune`, and `docker container prune` are all forbidden. They delete by policy, not by precision, and can remove data the user still needs.
2. **Exception: `docker builder prune` is safe.** It removes only the build cache, which is always regenerable and never user data.
3. **Delete by exact ID or name only.** Use `docker volume rm <exact-name>` or `docker image rm <exact-id>`. Never a wildcard, never a filter that matches multiple objects.
4. **Per-object confirmation.** Each volume or image is confirmed individually. A batch of ten volumes is ten confirmations, not one.
5. **Database volume red-flag rule.** If a volume name contains `mysql`, `postgres`, `redis`, `mongo`, or `mariadb`, treat it as a database volume. Before any deletion, inspect its contents (`docker run --rm -v <volume>:/data alpine ls /data`) and show the user what is inside. A database volume may hold the only copy of real data.

## Report Format

Every analysis produces a report in this shape. Use a markdown table with these columns.

| Classification | Path / Object | Size | Impact If Deleted |
|----------------|---------------|------|-------------------|

Classification legend:

- 🟢 **Safe** - Regenerable or clearly disposable. Deleting has no lasting consequence.
- 🟡 **Trade-off** - Deletable, but you lose a speed or convenience benefit. Deleting trades space for time.
- 🔴 **Do not delete** - Valuable or irreplaceable. Deleting costs more than it saves.

The "Impact If Deleted" column is mandatory on every row. It states, in plain terms, what the user loses if they delete that item. A row without an impact statement is an incomplete analysis.

Example:

| Classification | Path / Object | Size | Impact If Deleted |
|----------------|---------------|------|-------------------|
| 🟢 | `~/.Trash` | 4.2 GB | Nothing. Files are already user-discarded. |
| 🟡 | `~/Library/Caches/Chrome` | 1.8 GB | Chrome re-downloads assets; slower first loads. |
| 🔴 | `~/Library/Developer/Xcode/DerivedData` | 12 GB | Full rebuild of all Xcode projects, 10-30 min each. |

## Running Commands

Run commands through your normal shell tool. Read-only analysis commands need no TTY. `scripts/mac-cleanup.sh clean` asks for confirmation interactively, so it needs a TTY: in OpenClaw pass `pty: true` to `exec`; in agents without a TTY (Claude Code, Codex), don't run `clean` yourself. Run the single confirmed deletion command for each item instead, or ask the user to run `clean` in their own terminal. No tmux or Mole is required.

## Summary

Analyze read-only, present itemized findings with impact, confirm each object, delete precisely, verify. Never prune, never auto-delete, never trade useful caches for a bigger number.
