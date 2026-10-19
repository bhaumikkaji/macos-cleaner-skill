# macOS Disk Cleanup Reference

This document catalogs disk cleanup categories for macOS. Each category records what it is, where it lives, and whether it is safe to delete, with reasoning.

The single most important rule: **do not delete anything that is cheap to regenerate but expensive to lose.** Caches and build artifacts are tempting targets because they are large, but the cost of deleting them is paid in time, not disk space. This reference separates the categories that are genuinely safe from the ones that only look safe.

---

## KEEP (Do Not Delete)

These categories are frequently mistaken for junk. They are not. Each one is either actively used, expensive to rebuild, or both.

### Xcode DerivedData

| Field | Value |
|-------|-------|
| What it is | Intermediate build products, module caches, and index data that Xcode produces while compiling. |
| Path | `~/Library/Developer/Xcode/DerivedData` |
| Safe to delete? | No |

**Why it is valuable:** DerivedData is the build cache. Deleting it forces a full clean rebuild of every project, which for large projects can take tens of minutes to hours. The index data also powers code completion and jump-to-definition, so deleting it degrades the editor until the index rebuilds.

**Real cost of deleting:** A full rebuild of a large iOS or macOS project. The space you reclaim is temporary, because the next build regenerates most of it. You are trading disk space for developer time, and the trade is almost never worth it.

**When it is actually safe:** Only when a project is abandoned and will never be built again, or when Xcode itself is misbehaving and a clean rebuild is the fix. Even then, delete per-project subfolders, not the whole directory.

---

### npm `_cacache`

| Field | Value |
|-------|-------|
| What it is | The content-addressable cache npm uses to store downloaded package tarballs. |
| Path | `~/.npm/_cacache` |
| Safe to delete? | No |

**Why it is valuable:** This is what makes `npm install` fast. Every package tarball npm has ever downloaded lives here, keyed by content hash. When you install a package that is already cached, npm skips the network entirely.

**Real cost of deleting:** Every subsequent `npm install` re-downloads every dependency from the registry. On a slow connection or with a large `node_modules`, this is minutes to tens of minutes per project, repeated across every project.

**When it is actually safe:** `npm cache verify` and `npm cache clean --force` exist for a reason, but they are for fixing a corrupted cache, not for reclaiming space. Do not treat this as a cleanup target.

---

### `~/.cache/uv`

| Field | Value |
|-------|-------|
| What it is | The cache directory for `uv`, the Python package and project manager. Holds downloaded wheels, source distributions, and build artifacts. |
| Path | `~/.cache/uv` |
| Safe to delete? | No |

**Why it is valuable:** Same principle as npm `_cacache`. `uv` is fast precisely because it caches wheels and avoids re-downloading. This cache is shared across all virtual environments and projects on the machine.

**Real cost of deleting:** Every `uv sync`, `uv pip install`, and `uv run` re-downloads packages. For a project with heavy dependencies like PyTorch or TensorFlow, that is gigabytes re-fetched from the network.

**When it is actually safe:** `uv cache clean` exists for cache corruption or when you genuinely need the space and accept the re-download cost. It is a deliberate trade, not a routine cleanup.

---

### Playwright Browsers

| Field | Value |
|-------|-------|
| What it is | The actual browser binaries (Chromium, Firefox, WebKit) that Playwright downloads and drives for testing. |
| Path | `~/Library/Caches/ms-playwright` |
| Safe to delete? | No |

**Why it is valuable:** These are not cache files in the usual sense. They are the browsers themselves. Without them, Playwright cannot run a single test. Each browser is hundreds of megabytes to over a gigabyte.

**Real cost of deleting:** Every Playwright test run fails until you re-run `npx playwright install`, which re-downloads the browsers. If you delete only some browsers, tests targeting those browsers fail.

**When it is actually safe:** Only if you have stopped using Playwright entirely. If you still run any Playwright tests, leave this alone.

---

### iOS DeviceSupport

| Field | Value |
|-------|-------|
| What it is | Symbol files and support data Xcode downloads for each iOS version, used to symbolicate crash logs and debug on physical devices. |
| Path | `~/Library/Developer/Xcode/iOS DeviceSupport` |
| Safe to delete? | No |

**Why it is valuable:** These files let Xcode read crash reports and debug on devices running specific iOS versions. Each iOS version has its own folder, and they accumulate as you connect devices on newer OS versions.

**Real cost of deleting:** You lose the ability to symbolicate crash logs from devices on the deleted iOS versions, and Xcode re-downloads the support data the next time you connect a device on that version. The re-download is automatic but slow, and until it completes, debugging on that device is blocked.

**When it is actually safe:** Only for iOS versions you will never debug against again, and even then the re-download is automatic, so the space savings are temporary.

---

### Docker Stopped Containers

| Field | Value |
|-------|-------|
| What it is | Containers that have exited but have not been removed. They retain their writable layer and configuration. |
| Path | Managed by Docker, not a filesystem path you touch directly. |
| Safe to delete? | No, not blindly |

**Why it is valuable:** A stopped container is not dead. It may hold state in its writable layer, be configured to restart, or be a template you will `docker start` again. The container's name, ports, volumes, and environment are all preserved while it is stopped.

**Real cost of deleting:** `docker rm` on a stopped container destroys its writable layer and configuration permanently. If that container held data outside a mounted volume, that data is gone. If it was a service you intended to restart, you must recreate it from scratch.

**When it is actually safe:** Only when you have confirmed the container is truly abandoned, its data lives in named volumes (not the writable layer), and you have no intention of restarting it. Delete by exact container ID or name, one at a time, with confirmation.

---

### `~/.cache/huggingface`

| Field | Value |
|-------|-------|
| What it is | The cache for the Hugging Face ecosystem. Holds downloaded models, tokenizers, datasets, and their metadata. |
| Path | `~/.cache/huggingface` |
| Safe to delete? | No |

**Why it is valuable:** Large language models are enormous. A single model can be tens of gigabytes. This cache is what lets you load a model you have already downloaded without re-fetching it from the Hub. For local inference and fine-tuning workflows, this cache is the difference between instant startup and a multi-gigabyte download.

**Real cost of deleting:** Every model and dataset re-downloads on next use. For a researcher or developer working with several models, this can be hundreds of gigabytes re-fetched. Some models are also gated or version-pinned, and re-downloading may not reproduce the exact same files.

**When it is actually safe:** Only for specific models or datasets you are certain you will never use again. Delete by subfolder, never the whole directory.

---

### `~/.cache/modelscope`

| Field | Value |
|-------|-------|
| What it is | The cache for ModelScope, the Alibaba-hosted model and dataset platform. Functionally equivalent to the Hugging Face cache. |
| Path | `~/.cache/modelscope` |
| Safe to delete? | No |

**Why it is valuable:** Identical reasoning to Hugging Face. Downloaded models and datasets live here, and deleting them forces re-downloads measured in gigabytes.

**Real cost of deleting:** Re-download of every cached model and dataset on next use. Same gating and version-pinning concerns as Hugging Face.

**When it is actually safe:** Only for specific models you will never use again, deleted by subfolder.

---

### JetBrains Caches

| Field | Value |
|-------|-------|
| What it is | Indexes, caches, and local history that JetBrains IDEs (IntelliJ, PyCharm, WebStorm, etc.) build for each project. |
| Path | `~/Library/Caches/JetBrains` |
| Safe to delete? | No |

**Why it is valuable:** The index is what powers code completion, navigation, refactoring, and search. Local history is a built-in safety net that lets you recover unsaved or overwritten changes without a VCS. Both are expensive to rebuild and, in the case of local history, irreplaceable.

**Real cost of deleting:** Every project re-indexes on next open, which for large codebases takes minutes and makes the IDE sluggish until it finishes. Local history is lost permanently, which can mean losing work that was never committed.

**When it is actually safe:** JetBrains provides "Invalidate Caches" as a troubleshooting step for a corrupted index. That is a targeted, IDE-driven operation, not a manual deletion of the directory. Do not delete this folder by hand.

---

## SAFE TO DELETE

These categories are genuinely safe to clean. They are either already-trash, regenerated automatically, or orphaned remnants of things that no longer exist.

### Trash

| Field | Value |
|-------|-------|
| What it is | Files the user has moved to the Trash but not yet emptied. |
| Path | `~/.Trash` |
| Safe to delete? | Yes |

**Reasoning:** Everything in the Trash was already explicitly deleted by the user. Emptying it is the final, intended step. The only caution is that emptying is irreversible, so confirm the user has not put something in the Trash they meant to keep. This is the single safest and most honest cleanup target on the list.

---

### Homebrew Old Versions

| Field | Value |
|-------|-------|
| What it is | Outdated formula versions, old downloads, and orphaned dependencies that Homebrew retains after upgrades. |
| Path | Managed by Homebrew, cleaned via `brew cleanup`. |
| Safe to delete? | Yes |

**Reasoning:** `brew cleanup` removes only versions that are no longer the current installed version, plus stale lock files and downloads. Homebrew itself decides what is safe to remove, so this is a well-scoped, self-guarding operation. It does not touch the currently installed versions of anything.

**Command:** `brew cleanup` (optionally `brew cleanup -s` to also scrub the cache of old downloads).

---

### npm `_npx`

| Field | Value |
|-------|-------|
| What it is | The cache of packages that `npx` has downloaded to run one-off commands. |
| Path | `~/.npm/_npx` |
| Safe to delete? | Yes |

**Reasoning:** `_npx` holds packages fetched for ephemeral `npx` invocations. These are not project dependencies and are re-downloaded automatically the next time the same `npx` command runs. Deleting it costs nothing but a re-download on next use, and it is not shared with `npm install` (that is `_cacache`, which you keep).

---

### Orphaned App Remnants

| Field | Value |
|-------|-------|
| What it is | Preference files, caches, and support data left behind by applications that have been uninstalled. |
| Path | `~/Library/Application Support`, `~/Library/Preferences`, `~/Library/Caches` |
| Safe to delete? | Yes, with identification |

**Reasoning:** When an app is uninstalled, macOS does not remove its per-user data. These remnants are dead weight. The key is identifying them correctly: match the folder or plist name to an app that is no longer installed. Do not delete anything whose owning app is still present, and do not guess.

**Method:** For each candidate folder or plist, confirm the bundle identifier or app name matches an app that is gone. Delete only those. This is a per-item operation, not a bulk sweep.

---

### Specific Unused Docker Volumes

| Field | Value |
|-------|-------|
| What it is | Named volumes that are no longer attached to any container and hold no data you need. |
| Path | Managed by Docker, not a filesystem path. |
| Safe to delete? | Yes, per-project confirmation only |

**Reasoning:** A named volume is safe to delete only when you have confirmed it is not mounted by any container and does not hold data you care about. This requires per-project confirmation. Never delete a volume because it "looks unused"; verify it is actually detached and inspect its contents if there is any doubt.

**Method:** `docker volume ls` to list, `docker volume inspect <name>` to check mounts, and `docker volume rm <name>` to delete by exact name, one at a time.

---

## Docker Safety Rules

Docker is the highest-risk cleanup surface on this list because deletion is irreversible and the data is often a database. These rules are mandatory.

### Never Use Prune-Family Commands

The following commands are forbidden because they delete broadly and irreversibly, with no per-object confirmation:

- `docker image prune`
- `docker volume prune`
- `docker system prune`
- `docker container prune`

**Exception:** `docker builder prune` is safe. It removes only the build cache, which is regenerated automatically and holds no user data.

### Delete by Exact ID or Name Only

Every deletion must target a specific object by its exact ID or name, and each object requires its own confirmation. No wildcards, no filters that match multiple objects, no "clean up everything unused."

### Database Volume Red-Flag Rule

If a volume name contains any of the following, it is a red flag and its contents **must** be inspected before deletion:

- `mysql`
- `postgres`
- `postgresql`
- `redis`
- `mongo`
- `mongodb`
- `mariadb`

These names indicate the volume likely holds a database. Deleting a database volume destroys data that may be irreplaceable. Before deleting any such volume, inspect its contents (for example, by mounting it in a temporary container and listing the files) and confirm with the user that the data is not needed.

---

## Summary

| Category | Path / Command | Verdict |
|----------|----------------|---------|
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | Keep |
| npm `_cacache` | `~/.npm/_cacache` | Keep |
| uv cache | `~/.cache/uv` | Keep |
| Playwright browsers | `~/Library/Caches/ms-playwright` | Keep |
| iOS DeviceSupport | `~/Library/Developer/Xcode/iOS DeviceSupport` | Keep |
| Docker stopped containers | Docker-managed | Keep (per-object only) |
| Hugging Face cache | `~/.cache/huggingface` | Keep |
| ModelScope cache | `~/.cache/modelscope` | Keep |
| JetBrains caches | `~/Library/Caches/JetBrains` | Keep |
| Trash | `~/.Trash` | Safe to delete |
| Homebrew old versions | `brew cleanup` | Safe to delete |
| npm `_npx` | `~/.npm/_npx` | Safe to delete |
| Orphaned app remnants | `~/Library/Application Support`, `~/Library/Preferences`, `~/Library/Caches` | Safe to delete (identified) |
| Unused Docker volumes | Docker-managed | Safe to delete (per-project confirmation) |

The pattern is consistent: caches and build artifacts are keepers because they are cheap to regenerate but expensive to lose, while trash and orphaned remnants are the real cleanup targets. Docker is the exception that demands the most care, because its deletions are irreversible and often touch databases.
