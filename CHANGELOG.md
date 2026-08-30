# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## Versioning & Release Convention

### Version Number Schema

This project uses **Semantic Versioning** (`MAJOR.MINOR.PATCH`):

| Segment | When to increment | Example |
|---------|-------------------|---------|
| `MAJOR` | Breaking changes or complete architectural overhaul | `2.0.0` |
| `MINOR` | New backward-compatible features or significant UX additions | `1.1.0` |
| `PATCH` | Bug fixes, small improvements, removals, or dependency updates | `1.0.6` |

> During the initial rollout phase (`1.0.x`), `PATCH` increments are also used for feature additions
> that do not break existing functionality, reflecting rapid iteration on the v1 baseline.

### Git Tag & Release Workflow

Releases are distributed as multiplatform installers (Windows `.exe`, macOS `.dmg`, Linux `.deb` / `.tar.gz`)
via the GitHub Actions pipeline defined in `.github/workflows/release.yml`.

**The CI/CD pipeline is tag-driven.** It activates exclusively on `push` events targeting tags
that match the pattern `v*.*.*`. Tags are **not** created automatically by any workflow step —
they must be created manually before the release push.

#### Required steps to publish a new version

```bash
# 1. Ensure all commits for the release are on the target branch.
# 2. Create an annotated tag pointing to the release commit.
git tag -a v<MAJOR>.<MINOR>.<PATCH> <commit-sha> -m "Release v<MAJOR>.<MINOR>.<PATCH>"

# 3. Push the tag to origin. This is what triggers the release pipeline.
git push origin v<MAJOR>.<MINOR>.<PATCH>
```

> **Important:** Pushing commits without a corresponding tag will **not** trigger the release
> pipeline. Only the tag push initiates the build matrix (Windows, macOS, Linux) and the
> subsequent GitHub Release publication.

#### Tag naming convention

Tags must follow the pattern `v<MAJOR>.<MINOR>.<PATCH>` exactly (e.g., `v1.0.6`).
Tags deviating from this pattern (e.g., `1.0.6` without the `v` prefix) will not match
the workflow trigger and will be silently ignored by the pipeline.

### ⚠️ Mandatory Version Synchronization Checklist
Before creating and pushing any release tag, the version string and build number **MUST** be updated and synchronized in the following exact locations:
1. `pubspec.yaml`:
   ```yaml
   version: <MAJOR>.<MINOR>.<PATCH>+<BUILD_NUMBER>
   ```
   And `msix_config.msix_version`: `<MAJOR>.<MINOR>.<PATCH>.0`
2. `lib/core/constants/app_constants.dart`:
   ```dart
   static const String appVersion = '<MAJOR>.<MINOR>.<PATCH>';
   static const int buildNumber = <BUILD_NUMBER>;
   ```
3. `windows/installer/desky_setup.iss`:
   ```iss
   #define MyAppVersion "<MAJOR>.<MINOR>.<PATCH>"
   ```
4. `CHANGELOG.md`:
   - Move all entries from `pending_changelog.md` into a new `## [<MAJOR>.<MINOR>.<PATCH>] - YYYY-MM-DD` section and clear `pending_changelog.md`.

---


## [1.0.0] - 2026-08-30

### Added
- **Focus & Study Timer Engine**:
  - Real-time study stopwatch with standard mode and Pomodoro Technique support.
  - Automatic day boundary rollover adhering to user-configured reset hours.
  - Multi-session local buffering and offline study queue with auto-retry synchronization.
  - Floating Mini-Player and Strict Focus mode for distraction-free desktop sessions.
- **Subject & Task Management**:
  - Full CRUD operations for study subjects with custom RGB color pickers, reordering, and archiving.
  - Planner with Daily To-Do lists and D-Day exam countdown calculation.
  - Weekly Timetable scheduler with drag-and-drop block placement.
- **Community & Social Groups**:
  - Live Study group tracking with real-time status indicators (studying, resting, idle).
  - Categorized group discovery, search, join requests, member management, and group notices.
  - Group chat with reaction support and member interaction (wake/nudge alerts).
  - Global, category, and regional ranking leaderboards with podium visualizer.
- **Dynamic Avatar System**:
  - High-definition Studicon avatar rendering with dynamic poses mapped to focus duration and study status.
  - Avatar store with category browsing, preview, and equipment management ("My Avatares").
- **SmartBook PDF Reader & Flashcards**:
  - Integrated PDF reader with bookmarking, page memory, and fullscreen reading mode.
  - Spaced repetition flashcard system with 3D card flip animation, review ratings, and deck builder.
- **Insights, Analytics & Media**:
  - Monthly study calendar, hourly heatmaps, and study distribution charts.
  - Timelapse recording engine with variable playback speed gallery.
- **In-App Notification Center**:
  - Notification inbox with temporal grouping ("Today", "This week", "Earlier") and unread badges.
  - Persistent local deletion filter and batch "mark all as read" synchronization.
- **Multiplatform Packaging & Distribution**:
  - Native x64 installers and packages for Windows (Inno Setup `.exe` and Microsoft Store `.msix`), macOS (`.dmg`), and Linux (`.deb`, `.tar.gz`).
  - Automated CI/CD release pipeline on GitHub Actions with multiplatform artifact verification.
  - Multi-language localization support across English, Portuguese, Spanish, Korean, Japanese, and Chinese.

### Fixed
- **Rest Time Isolation**: Prevented break/pause intervals from being credited to subject study durations by synchronizing completed focus slices immediately on pause.
- **Notification Deletion Persistence**: Stored dismissed and cleared notification IDs in local persistent storage (`SharedPreferences`) to prevent deleted notices from reappearing upon feed reload.
- **Language & Typography**: Resolved duplicate translation fallback keys and normalized language selection queries across regional endpoints.
