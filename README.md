# macos-cleaner

A safety-first macOS disk cleanup skill for AI agents (Claude Code, OpenClaw and others). It analyzes disk usage read-only, presents itemized findings with impact analysis, and deletes only what you explicitly confirm, one object at a time.

## What it is

This skill merges the conservative philosophy of the Claude Code `macos-cleaner` skill (from [daymade/claude-code-skills](https://github.com/daymade/claude-code-skills)) with a plain script-based approach. No Mole, no tmux, no background daemons, no new dependencies. Every command runs through your agent's normal shell tool.

## Why it exists

Most disk cleaners optimize for the biggest number. This one optimizes for not breaking your machine. The core idea is "value over vanity": a cache that speeds up your daily workflow is worth more than the gigabytes it occupies. The skill actively warns against deleting useful caches just to inflate the freed-space figure.

## What it does

- **Analyze (read-only)** — scans caches, build artifacts, large files, and Docker resources without modifying anything.
- **Present findings** — every item is listed individually with a classification (🟢 safe / 🟡 trade-off / 🔴 do not delete) and an "Impact If Deleted" column.
- **Confirm per object** — nothing is deleted without explicit, per-object confirmation.
- **Execute precisely** — deletes by exact path or ID, never by broad glob or prune command.
- **Verify** — re-runs analysis to report actual space reclaimed.

## Safety rules (non-negotiable)

- Never auto-delete. The skill proposes; you dispose.
- Never use Docker prune-family commands (`image prune`, `volume prune`, `system prune`, `container prune`). The only exception is `docker builder prune`, which removes only regenerable build cache.
- Database volumes (names containing `mysql`, `postgres`, `redis`, `mongo`, `mariadb`) require content inspection before any deletion.
- Never delete useful caches just to show a bigger number.

## What it deliberately keeps

Xcode DerivedData, npm `_cacache`, `~/.cache/uv`, Playwright browsers, iOS DeviceSupport, Docker stopped containers, HuggingFace/ModelScope model caches, and JetBrains caches. These are common "cleanup targets" that are actually valuable. See `SKILL.md` for the full rationale.

## Requirements

- macOS with bash (built in)
- Optional: Homebrew, npm, pip and Docker. The script skips any that aren't installed.

## Install

The skill is the whole repo: `SKILL.md` at the root plus `scripts/` and `references/`. Clone it into your agent's skills folder.

**Claude Code**

```bash
git clone https://github.com/bhaumikkaji/macos-cleaner-skill.git ~/.claude/skills/macos-cleaner
```

**OpenClaw**

```bash
git clone https://github.com/bhaumikkaji/macos-cleaner-skill.git ~/.openclaw/workspace/skills/macos-cleaner
```

Then restart OpenClaw (or reload skills).

**Any other agent** that reads `SKILL.md` files: clone it into that agent's skills folder. For agents without skill support, point them at `AGENTS.md`.

Once installed, ask your agent something like "what's taking up disk space?" or "clean up my Mac".

## Files

- `SKILL.md` — the skill instructions and workflow
- `scripts/mac-cleanup.sh` — the analyze/clean script (read-only by default)
- `references/cleanup-targets.md` — detailed reference of each cleanup category
- `AGENTS.md` — install and usage steps for agents

## Usage

```bash
# Read-only analysis (safe, never deletes)
bash scripts/mac-cleanup.sh analyze

# Interactive cleanup (safe items only, prompts before deleting)
bash scripts/mac-cleanup.sh clean
```

You can run the script on its own without an agent. `analyze` never changes anything. `clean` only offers three safe items (Trash, old Homebrew versions, the npm `_npx` cache) and asks before each one.

## License

MIT. See `LICENSE`.
