# AGENTS.md

Instructions for an AI agent installing or using this skill for a user.

## Install

1. Confirm the machine is macOS (`uname` prints `Darwin`). The skill is macOS-only.
2. Clone the repo into your skills folder, named `macos-cleaner`:
   - Claude Code: `git clone https://github.com/bhaumikkaji/macos-cleaner-skill.git ~/.claude/skills/macos-cleaner`
   - OpenClaw: `git clone https://github.com/bhaumikkaji/macos-cleaner-skill.git ~/.openclaw/workspace/skills/macos-cleaner`, then reload skills
   - Other agents: clone into the folder your agent loads skills from. If it has none, read `SKILL.md` before any cleanup task and follow it.
3. Check it runs: `bash ~/.claude/skills/macos-cleaner/scripts/mac-cleanup.sh analyze` (adjust the path). It is read-only.
4. Tell the user it's installed and that they can ask "what's taking up disk space?".

## Use

Follow `SKILL.md` exactly: analyze read-only, show an itemized table with an "Impact If Deleted" column, get per-item confirmation, delete by exact path or ID, then re-run analyze to report what was freed.

- Never run Docker prune commands (except `docker builder prune`).
- Never delete anything on the KEEP list in `scripts/mac-cleanup.sh`.
- `mac-cleanup.sh clean` prompts interactively. Only run it if you have a TTY; otherwise run each confirmed deletion yourself, one at a time.

## Files

- `SKILL.md`: the workflow and safety rules
- `scripts/mac-cleanup.sh`: `analyze` (read-only) and `clean` (interactive, safe items only)
- `references/cleanup-targets.md`: what each cleanup target is and what deleting it costs
