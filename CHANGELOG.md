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

## [1.0.3] - 2026-09-04

### Fixed
- **Discord Rich Presence Connection & IPC Handshake**: Resolved Windows named pipe handshake timeouts by sanitizing the client ID string, ensuring robust packet framing, and adding defensive fallback handling.
- **Discord Rich Presence Activity & State**:
  - Disabled presence publishing when the user is logged out or idle (removed the "No Desky" placeholder).
  - Fixed study timer synchronization on Discord by providing timestamps in Unix epoch milliseconds instead of seconds, eliminating the 0:00 counter freeze.
  - Added localized "Paused" status (`"Em pausa"`, `"Paused"`, `"En pausa"`, `"일시정지"`, `"一時停止中"`, `"暂停中"`) with frozen study timer during breaks, preserving the current subject name.
  - Continuously resumes the study timer from the exact accumulated elapsed time upon unpausing.
- **Study Timer Pausing & Accumulated Time**: Fixed `TimerNotifier.pauseStudy()` resetting `sessionElapsedMs` to zero; introduced differential session tracking (`lastSyncedSessionElapsedMs`) so the study timer freezes on screen during breaks and smoothly resumes without resetting or duplicating server sync.
- **Purchased & Custom Avatar Persistence**:
  - Fixed an issue where equipping purchased YPT studicons would revert to the default avatar (`-1`) upon initial login or after logging out and back in.
  - Implemented `UserModel.extractStudiconId` to strictly validate positive IDs (`> 0`) and prioritize custom studicon fields (`csd`) over negative fallback indicators (`ssd: -1`).
  - Added user-indexed local preference caching in `AuthRepository` (`keyUserEquippedStudiconId_<id>`), ensuring paid studicons remain equipped across app sessions.
- **Process Exit & Window Close Handling**:
  - Configured `windowManager.setPreventClose(true)` and `WidgetsBindingObserver.didRequestAppExit` to intercept the custom title bar 'X' button, OS close commands, and system shutdown signals.
  - Automatically stops active study sessions with a 3-second defensive network timeout, enqueuing sessions to the offline sync queue (`OfflineSyncRepository`) if the network is unavailable or slow.
  - Flushes accumulated break duration on exit and cleanly releases Discord RPC IPC connections (`clearPresence()` and `dispose()`) before terminating the application process via `windowManager.destroy()`.

## [1.0.2] - 2026-09-04

### Added
- **Google Sign-Up Confirmation Modal**: Added pre-check for account existence (`POST /user/exist-username`) and a confirmation dialog when no account is linked to the Google profile, preventing automatic creation of unconfigured accounts and guiding the user to complete their profile (nickname, study category, and country).
- **OAuth Callback Localhost Page Theme & i18n**: Redesigned OAuth loopback completion page (`http://127.0.0.1`) with Desky AMOLED Dark theme, vibrant lilac accents, glassmorphic card, and automatic browser language detection (`Accept-Language` + `navigator.languages` supporting PT, EN, ES, KO, JA, ZH).

### Fixed
- **Immediate Nickname Display on Sign-Up**: Fixed an issue where the nickname chosen during social or email registration did not appear immediately after account creation, requiring a logout and login cycle to show up.
- **Account Deletion Confirmation Word**: Simplified confirmation keyword in the account deletion dialog to typing "delete" instead of the full localized phrase ("Excluir Minha Conta").

## [1.0.1] - 2026-09-04

### Added
- **Google Sign-Up Flow (Cadastro via Google)**:
  - Implemented complete account creation flow using Google authentication when an account does not yet exist on the YPT platform.
  - Introduced `SocialSignUpRequiredException` for detection of unregistered social accounts from backend responses (error code `111` / absence of JWT).
  - Automatically redirects new Google users to the profile completion step in `SignUpScreen`, pre-filling email and name while omitting password requirements.
  - Streamlined UI showing connected Google account badge, nickname selection, country and study category pickers, and localized "Concluir Cadastro" CTA.
  - Added localized strings and aliases across all 7 supported languages (pt, en, es, ko, ja, zh-CN, zh-TW) in `AppTranslation`.

- **Discord Rich Presence (RPC)**:
  - Added native Discord Rich Presence integration enabled by default, showcasing real-time study status on the desktop.
  - **Dynamic Large Image Poses**: Automatically updates the avatar image based on today's accumulated study duration (`todayTotalMs`) using YPT CDN avatar poses (`normal1`, `sweat1-3`, `smoke1-2`, `ignite1-2`, `fire1`, `explosion1`), or user custom avatar when equipped.
  - **Status & Details**: Displays current activity localized in the user's selected language (e.g., `"Estudando: Matéria"`, `"Studying: Subject"`, `"공부 중: 과목"`), study session start timestamp, and accumulated time today tooltip.
  - **Desky Branding & Small Icon**: Small image badge featuring the Desky logo directly from public repository assets with `"Desky"` tooltip and clean status line.
  - **Settings Preference**: Added a toggle in `StudyPreferencesDialog` to enable or disable Discord Rich Presence at any time, persisted via `SettingsRepository`.
  - **Fail-safe Non-blocking IPC**: Utilizes `PeekNamedPipe` and microtask scheduling to guarantee immediate window display and zero UI blocking on Windows, macOS, and Linux.

### Fixed
- **Timer & Subject Daily Study Time**:
  - Corrected `SubjectRepository._parseSplashData` to accurately compute daily study durations strictly from today's daily log (`data['dl']['ls']` / `data['dl']['ss']`).
  - Fixed a fallback issue where subjects with no study records today were erroneously displaying the weekly/all-time accumulated total (`data['ss'][i]['sm']`).
  - Ensured subjects without study logs today default to `0 ms` (`0m`) and `todayTotalMs` remains accurate.

- **Ranking User Position Badge**:
  - Updated the user rank badge label in `RanksScreen` from the generic `"Rankings #XXX"` to `"Minha Posição: #XXX"` (`My Rank: #XXX` in English).
  - Added the dedicated `my_position` and `my_rank` localization keys and aliases across all supported languages in `AppTranslation`.

## [1.0.0] - 2026-08-30

### Added
- **Design System & Visual Redesign**:
  - True AMOLED black background (`#000000`) with Material Design 3 geometry and surface elevations.
  - Vibrant Lilac brand primary (`#A78BFA`) and hourglass accent (`#4A7FB5`) extracted from new logo.
  - Apple SF Pro typography (`SF-Pro-Text` & `SF-Pro-Display`) with `AppleEmoji` fallback support.
  - Lavender study heatmap progression (`heatmapL1` - `heatmapL4`).
  - Streamlined title bar without brand clutter.
  - Removed 43 legacy unused icon assets to reduce package footprint.
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
