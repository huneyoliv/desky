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

## [Unreleased]

### Added

- Planner tasks now offer an explicit subject selector, including **No subject**,
  and resolve subject names from the same timer state used by study sessions.
- Open Planner tasks can start the real timer with their subject. The action sends
  the task id to `/study/start`; acceptance was verified live earlier, while
  persistent task-session association remains unconfirmed and is not claimed.
- Localized the new Planner subject/start/failure controls in the 11 languages exercised by the timer layout test.

- Local MP4/WebM video backgrounds up to 50 MiB, with mute, loop, an injectable
  lifecycle-safe media backend and independent static-image fallback. Selected
  media is copied into app-owned storage, with bounded replacement cleanup and
  no upload. Windows CI includes a real MP4 decode smoke test; Linux packaging
  declares the required system mpv dependency (#10).
- Timer appearance now includes persisted Aurora and Sunset gradients, local
  PNG/JPEG/WebP images up to 20 MB, and Digital, SF Pro or Pretendard font
  selection. Missing/unreadable images fall back safely; no media is uploaded.
  Video backgrounds are not included (#10).

- Study Timeline (Refs #11) adds day navigation, chronological sessions, subject
  names, durations, daily totals, and clearly derived gaps between sessions.
  It reuses the existing manual study flow with an initial date and save result.

- Light and adaptive theme support (Refs #12) adds two light palettes, an
  operating-system System mode with persisted light/dark preferences, and
  theme-token migrations for controls, dialogs, charts and narrow layouts.

- Selected PR #9 contributions add English fallbacks while preserving Portuguese,
  bounded avatar/chat/sticker image decoding, persistent custom group ordering,
  opt-in Classic zoom shortcuts, and a member statistics/Nudge sheet.
- Windows can restore the previous monitor and position, and an opt-in OBS
  overlay mode sends minimize requests behind other windows. Prerelease CI no
  longer attempts to upload an MSIX package that was intentionally not built.

### Fixed

- The app no longer exits silently when the single-instance channel cannot be
  created. `startOrForward` used to return `null` both when a payload had been
  forwarded to the running instance and when the lock could not be acquired at
  all, and `main` treated every `null` as the first case. With a read-only or
  redirected `%APPDATA%` the process died with no window and no message. The
  result now distinguishes `primary`, `forwarded` and `degraded`; only a real
  forward exits, and a degraded start still opens the window.

- Planner D-Day creation and deletion now use the live-verified contracts:
  `POST /user/d-day/create` requires `title` **and** `date` (not `targetDate`),
  and `POST /user/d-day/delete` requires a JSON body with `id`. The previous
  payloads were rejected by the server with HTTP 500. Both actions now surface a
  localized failure message instead of failing silently.

- Timetable block creation now uses the live-verified compact body
  `{ttid,t,lw,st,et,scid,sd,ed,c}` and parses the `rs` response. The colour `c`
  was the final missing field. A disposable block was created, reread through
  `sb` and deleted, leaving no probe data. Loading now prefers actual detail
  blocks over container summaries.

- Deleting a To-Do item now sends the required JSON body (`{"id": ...}`) to
  `DELETE /study/study-plan/rest`. The previous query-only request was rejected
  and left the item on the server. Rejected deletions show an error.
- Editing a task without a subject no longer risks silently associating one, and
  an existing subject missing from the loaded list is preserved safely.
- Planner task creation, editing and deletion now check the repository result.
  Refused writes show a localized error and reload the server state, including
  after an optimistic local edit or removal. Recurring editing remains limited
  to the selected occurrence. Deletion offers either that occurrence (default)
  or the whole series after a fresh `target:"all"` live proof and cleanup.
- Text searches in Study Group discovery now propagate the selected country
  instead of silently falling back to the repository's default country.
- The Timer start button now has a fixed width in both Timer and Pomodoro modes.
  `minimumSize` still allowed the longer Pomodoro label to widen it; a new
  regression test measures both labels, subject changes and the timer geometry.

- Window resizing now allows down to 640×480, so Desky can occupy half of a
  1920×1080 display. The previous 1024×700 minimum blocked that layout. The
  Timer was also exercised at 960×540 and 640×480 without layout overflow (#10).
  Static gradient/image backgrounds and timer-font selection are included;
  video backgrounds remain excluded from this change.

- Renaming a group now sends `title` to `/group/info/edit`. The previous `t`
  field returned `s:true` without changing the name; `title` was verified live
  by editing and restoring it. Recurring To-Do deletion was also verified live:
  one occurrence could be removed alone and `target:"all"` removed the remaining
  series, with no probe items left.

- Added NOTICE.md plus Pretendard/E1234 OFL and Material Icons Apache 2.0
  license files, and declared Pretendard correctly in the font manifest.
- Added button geometry coverage for the 11-language timer layout matrix. All 22
  Timer/Pomodoro labels fit within the fixed 296 px button without clipping.

- The Timer now syncs its clock with the server. `GET /time/` returns the
  timestamp under `t`, but the client only read `timestamp`, so every sync
  silently fell back to the local clock. Both keys are now accepted.

- PR #9 Nudge requests now use the verified snake_case body with sender name.
  Invalid stored window sizes are normalized before placement so the restored
  default window cannot be positioned off screen.

- Light palettes now keep profile, group chat, leader panel, selectors and shared text styles on palette-aware colors, with rendered WCAG AA assertions in both light themes (#12 R1, #5 R13).
- Planner task writes now roll back rejected toggles, distinguish load failure from an empty day, offer retry, keep create/edit dialogs open with inline errors and expose a dismissible write-error banner. Explicit `/study/start` refusal no longer starts the timer or navigates (#7).
- Derived statistics now load current and previous periods, reload with range changes, fetch all three months of a quarter, show loading instead of false zeroes and exclude zero-duration subjects from the pie (#5 R27, R28, R30, R20, R22).
- Stats comparison labels and quarter month names now follow the selected locale, including the 11-language test matrix (#5 R18).
- Group chat permission changes are saved with failure reporting, messages show full date and time, and ranking scope persists across screens (#5 R4, R7, R9).
- Study-day boundaries now use the selected country's start hour when available and fixed GMT offset, with the manual reset preference preserved. Timer, Planner, Calendar and Timeline share the effective rule (#10 R4).
- Timer reconciliation now applies that same effective country offset and reset hour when choosing the `/logs/day` query date. Fixed-instant regression tests cover GMT+5:30 immediately before and at both 05:00 and midnight resets, with the device in a different timezone (#10).
- Pause/resume now remains strictly stop/start: no unverified separate rest record is written to the Planner task route. No new rest button is required by the original app; Timeline gaps remain derived (#11).
- System theme selection now repaints even when the effective palette is identical, and the full-shell timer layout fits 640×480 without the previous 28 px overflow (#12, #10).
- Crash-log writers now retry bounded Windows lock contention instead of dropping entries. Native pipe/worker tests use reliable readiness and no repeated pub resolution (#23, #24).

### Known Limitations

- Full Classic navigation, mini player, offline sync, Discord IPC hardening and
  crash logging are not included in the selected PR #9 integration. OBS focus/
  z-order and real OS behavior still require manual native verification.

- Group creation remains unsupported: the supplied Firestore HAR contains only `userbooks`, and the APK exposes candidates but no successful create response, group id, full call order or cleanup contract (#5).
- Starting a session from a to-do sends taskId, but no association is observable on the API.
- Recurring tasks: editing affects only the selected occurrence; deleting offers one occurrence or the whole series.
- Nudge reception on desktop is not possible yet (no nudge notification type; the official app uses FCM push).
- Local MP4/WebM video backgrounds are implemented, but macOS/Linux playback, security-scoped file behavior, reduced-motion preference and long memory/GPU soak remain unvalidated. HEVC/AV1/4K and mobile are not claimed (#10).
- Study vs rest breakdown is not available (rest contract unknown).
- Study vs rest data is not available from the API; gaps are derived from session times.
- A Windows release was observed repainting from AMOLED Lilás to Lilás Diurno when
  the real OS `AppsUseLightTheme` setting changed from 0 to 1 with System mode
  selected; the app stayed open and the native frame also repainted. Complete visual
  inspection of every affected screen in both light palettes remains incomplete.
  WCAG/widget assertions are not being treated as substitutes for that inspection.
- Joining challenges is not supported; the Challenges tab is read-only.

- Group member time zones are unavailable from the API, so per-member reset remains unimplemented (#5 R24).
- Break periods cannot be recorded with the current rest contract; timeline gaps are derived only (#11 R3).
- Starting study from a completed task is intentionally disabled with a tooltip (#7 D23).
- The live Sri Lanka server day assignment, mobile parity and the persistent To-Do/session association still require external confirmation; local tests and `s:true` do not prove those behaviors (#7, #10).
- Win+Arrow gestures changed the monitor and window bounds, but exact half-screen placement was not established. Primary-monitor half-screen, drag-to-edge and multi-DPI behavior remain unvalidated. The Desky window was kept on the secondary display during the final gesture checks as requested.
- Mobile parity was not exercised.

### Changed

- The Planner tab formerly labelled Grade Horária is now Calendário, with a new
  `planner_calendar_tab` key translated in the 11-language test matrix. The
  internal timetable title remains descriptive and unchanged.
- The Timer/Pomodoro switcher is centred independently of the left/right header
  content, with geometry tests at 1280, 960 and 640 px.

- Updated the API documentation with the live-validated To-Do create/edit/delete
  and start/stop contracts. Group creation remains documented as blocked because
  the available HAR contains no group/todo REST writes and the APK does not expose
  the complete group-creation payload.

- Removed the unreachable standalone To-Do screen after porting behavior coverage to Planner, including successful toggles and the completed counter.
- Language documentation now distinguishes **7 selectable UI languages**, **11 languages in the timer test matrix**, and **28 locale JSON files** as separate layers.

Refs #5, #7 and #10. Fixes #8.
Refs #11 and #12.

---

## [1.2.1] - 2026-11-19

### Fixed

- **The Timer Layout Moved With the Subject and the Mode**: The screen is used as a window-capture
  overlay, so a crop set once must keep working. The header bar was a `Container` without a width
  inside a centred `Column`: it shrank to its content and was centred, so a longer subject name
  pushed the whole bar sideways. It now spans the window, the subject chip truncates instead of
  widening the bar, and the total-time field has a fixed width with tabular figures so `0s`
  becoming `1h 23m` no longer nudges the mode switcher. Switching to Pomodoro inserted a banner
  that pushed the timer block down; the slot is now reserved in both modes and only its content
  toggles. The line under the clock (subject name or the paused chip) moved the digits when it
  changed height; it now sits in a fixed-height slot. The clock keeps `hh:mm:ss` with tabular
  figures, and the start button has a fixed minimum width so `INICIAR` and `INICIAR FOCO` occupy
  the same box.

### Changed

- **API Matrix Rewritten With the Verified Contracts**: `docs/api_matrix.md` now records what was
  actually validated: the planner's `/study/study-plan/*` contract that backs To-Do, the routes
  that answer errors (`/study/task/make`, `/rest/record`, `/study/study-plan/rest`), the mission
  routes that do not exist at all, and the daily-history limit that could not be verified.

## [1.2.0] - 2026-11-18

### Added

- **Opt-In Beta Channel**: Update checks only ever saw finished releases, because
  GitHub's `/releases/latest` excludes pre-releases by design. A **Join the beta** setting
  now exists in the study preferences: when it is on, the check reads the release list
  instead, drops drafts, accepts pre-releases and picks the highest by SemVer. The toggle
  starts enabled only when the running build is itself a pre-release, so a stable install is
  never opted in silently, and it is hidden in the Microsoft Store build, where the updater
  is already suppressed and a downloaded installer would bypass managed updates. Flipping it
  re-checks immediately.

- **Per-Subject Study Series with Period Navigation (Refs Issue #4)**: The statistics
  tab showed a fixed current-week bar chart that could not be navigated and did not
  break time down by subject. It is now a stacked series (one bar per day, one segment
  per subject, top five subjects plus "Outros") with week and month navigation,
  including past periods, backed by a new `fetchSubjectDailyMs` aggregation.
- **Visible Link to the Project Repository (Fixes Issue #5)**: Settings had no way to
  reach the repository from inside the app, since the only "View on GitHub" entry lived
  in the update dialog. A help/legal entry now opens `AppConstants.githubRepo`.
- **Window Size and Maximized State Persist Across Sessions**: The app
  always reopened at 1280x800, so anyone who resized or maximized the window had to redo it
  every launch. The size and the maximized state are now saved while the window is resized
  (debounced, so a drag does not write on every frame) and on exit, and restored on the next
  start. On restore the stored size is clamped to the usable area of the current monitor, so
  moving to a smaller screen or a lower resolution cannot push the app-drawn title bar
  off-screen, and an absent or corrupted stored value falls back to the default instead of
  breaking startup. The maximized state is never stored as the restore size.
- **PDF Reader Moved to Its Own Tab and Opens Files from the OS (Fixes Issue #5)**: The
  reader was reachable only through a small icon inside Flashcards. It now has its own
  sidebar entry while Flashcards keeps its tab, and the app can open a PDF handed to it by
  the system: the first file argument is validated (missing path, directory, or non-PDF are
  reported instead of silently ignored), a second launched instance forwards the path to the
  running window and exits, and on macOS the Finder open event is forwarded from the
  AppDelegate because Launch Services never passes a path in argv. Associations are optional
  and non-invasive: the Windows installer adds an unchecked "associate PDF files" task that
  registers only an OpenWithProgids entry (the user's default program is never changed), the
  Linux desktop entries declare `MimeType=application/pdf` with `%f`, and the MSIX manifest
  declares `windows.fileTypeAssociation`.
- **Statistics Now Shows Comparisons, Records, Cumulative Time and a Quarterly Calendar
  (Refs Issue #4)**: The tab had a subject series, a pie, the 24h map and a monthly calendar,
  but nothing answered "am I improving?" or "what is my best week?". Four cards were added,
  all derived from `dt` + `sm` (plus `sb` for the subject breakdown) so none of them depends on
  data the API does not provide: today/week/month against the previous equivalent period (with
  growth shown only when there is a previous base), best day/week/month plus the number of days
  with study, cumulative time per subject keeping the four largest and folding the rest into
  "Outros", and a quarterly heat calendar with quarter navigation. Each card has a clear empty
  state, since a fresh account may have no history at all to compare.

### Known Limitations (1.2.0)

- **Window persistence only considers the primary monitor**: the restored size is clamped to
  the usable area of the primary display (`getPrimaryDisplay`), not of the display the window
  was on, and the window position is not saved. Closing the app on a secondary monitor makes
  the window reopen centred on the primary one. Accepted as-is; no implementation planned.
- **Joining challenges is not supported**: the join/cancel contract of the official app is
  unconfirmed (no challenge was available on the test account), so the Challenges tab is
  read-only and the element schema of `/mission/challenges` is unverified.
- **MS Store wide tile keeps transparent edges**: the `msix` package generates
  `Wide310x150Logo` with transparency and offers no option for it, so a pinned wide tile still
  shows the system accent colour at the sides. Fixing it would require patching
  `AppxManifest.xml` in CI; not planned.
- **Taskbar icon is a solid square in the MSIX build**: the unplated taskbar assets are now
  opaque too, so packaged installs show a solid tile instead of the rounded silhouette.
  Non-MSIX installs keep the `.ico`.
- **Nudge reception on desktop is not possible yet**: the API has no nudge notification type
  (the official app uses FCM push), so a nudge sent to a Desky user is not received. Pending
  the push investigation.
- **Statistics history limit is unverified**: the official catalog claims three years of
  history, but the test account only has ten days of records (oldest 2026-04-19), so the limit
  could not be tested and no client-side cap was added. Recorded as unverified; no action.
- **24h map day rule is partly confirmed**: the API serialises `st` in UTC and groups days by
  the user's local day (`dt` matched the local day in 17/17 sessions, the UTC day in 12/17), so
  the hour is taken from `st` converted to the device timezone. If the device timezone differs
  from the account's, the hours shift. The data cannot tell whether the server uses calendar
  days or a 05:00 study-day reset, so sessions between 00:00 and 04:59 may not match the
  official app's daily sums.
- **PDF file association is not offered in the MS Store build**: the `msix` package cannot
  declare that the app must not become the default handler, so the association was left out.
- **Study vs rest breakdown is not available**: the rest route contract of the phone app is
  unknown (`/rest/record` expects `{tag}` in the WearOS path; `/study/study-plan/rest` has no
  recoverable body) and the account has no rest data.
- **The To-Do section cannot be built yet**: `GET /logs/calendar/todos` works and returns
  `{s, ts, gl}`, but the creation route `/study/task/make` answers a Django 500 page to every
  method and payload tried (13 combinations), so nothing can be created, and with no to-do in
  the account across four years the element schema of `ts` was never observed. Blocked on the
  server, not on the client.
- **Cam study photos cannot be sent**: the reader side works (`/cam/{date}/{userId}`), but no
  route in the official binary links cam study to an upload, and `/study/cam-ms` returns
  `{s: true}` even for an empty body, so it validates nothing and cannot be the photo route.
  Closing this needs a capture of the official app during a real cam submission.
- **PDF file associations are unverified on installed builds**: the Windows installer task, the
  MSIX file type association, the Linux `MimeType` entry and the macOS open-file event were
  checked in code and manifests only, not on installed packages (the MSIX association was read
  back from a generated `AppxManifest.xml`, and the macOS Swift was never compiled). What *is*
  covered by automated tests is the command-line argument handling and the sidebar entry.

### Technical Debt

- **`screen_retriever` pinned to 0.1.9**: it is a direct dependency since window persistence,
  but `window_manager 0.3.9` requires `^0.1.9`, which blocks upgrading to 0.3.x/0.4.x.
  Upgrading `window_manager` to `>=0.4` releases a newer `screen_retriever` and should be done
  as its own item (larger upgrade, with a regression check on the window behaviour).
- **`dio` advisory (CVE-2021-31402 / GHSA-9324-jv53-9cc8)**: reported by the dependency audit,
  but it only affects `< 5.0.0`; the installed version is 5.11.0. No action.
- **`/study/start` and `/study/stop` send extra fields**: compared with the official WearOS path
  they add `subject_id`, `startedAt`, `study_ms` and `taskId`; the server tolerates them. Audit
  before changing.

### Changed

- **Releases Can Be Pre-Releases (Fixes Issue #5)**: The release workflow published
  everything as a normal release and always promoted it to "latest", so a `-beta` tag would
  have been offered to every stable user through `/releases/latest`. A tag containing a
  hyphen is now published with the pre-release flag and without becoming latest, the
  Microsoft Store submission and the MSIX package are skipped for it (the Store accepts only
  stable versions and the MSIX version has no room for a suffix), the `.deb` package uses
  `~` instead of `-` so a pre-release sorts before the final, the Arch `pkgver` is finally
  derived from the tag instead of being frozen at 1.1.5, and the changelog extractor reads
  the `[Unreleased]` section for a pre-release while failing the job when a stable tag has
  no section at all.

- **Missions Are Read-Only Until the Contract Is Known**: The challenges
  tab offered an "Available"/"My challenges" tab split plus join and check-in buttons, but
  `/mission/challenge/my`, `/mission/challenge/join` and `/mission/challenge/cancel` answer
  404 on the live API and appear in none of the 20 mission routes the official app calls,
  and the check-in button only showed a success message without calling anything. Those
  actions and the second tab are gone; the tab lists `GET /mission/challenges` (which returns
  the list in `rs`) as read-only, with an empty state that says so. `ChallengeModel` was left
  untouched: no real challenge element was ever observed, and `flameBet`/`entryFee`/
  `threshold` do not exist in the official binary, so the element schema stays unconfirmed.
- **Settings Cleanup and Visible Version**: The "Open Source Licenses"
  entry was removed from Settings. The repository link moved up into its place and the
  Desky version and build number are now shown directly underneath it, replacing the
  duplicated version line that lived in the About box.
- **Portuguese Text Fixes**: 41 entries in the Portuguese dictionary were
  double-encoded, so words such as "Versão", "Notificação", "Configurações", "Título" and
  the 🚀 emoji rendered as broken characters (for example "VersÃ£o") in labels, hints and
  dialogs. The affected strings were repaired in `pt.json` and `en.json`.

### Fixed

- **A Pre-Release Never Reached the Beta User (Fixes Issue #5)**: The update check
  compared only the first three numbers of a version and discarded everything after the
  first hyphen, so `1.2.0-beta.1` and `1.2.0` looked identical. Anyone who installed a
  pre-release would never be offered `beta.2` and never be offered the final either — they
  were stuck for good. Versions are now compared with full SemVer 2.0.0 precedence, so
  `1.2.0-beta.1 < 1.2.0-beta.2 < 1.2.0-rc.1 < 1.2.0`, numeric identifiers compare as
  numbers (`beta.9 < beta.10`), build metadata is ignored, and because the check is a
  strict "greater than", a downgrade is never offered.

- **MS Store Tile Showed a Blue Square Around the App Icon**: The `msix` package emits
  `BackgroundColor="transparent"` in `AppxManifest.xml` and generates every tile asset from
  `logo_path` keeping its transparency. Because the Desky logo is a rounded square with
  transparent corners, Windows painted the system accent colour behind it, so the Start menu,
  the apps list and the Store listing showed a blue block around the icon. The MSIX now uses
  a full-bleed opaque version of the same artwork (plate colour extended into the corners), so
  the square tiles, the Store logo and the taskbar icon render as one solid tile regardless of
  the accent colour. The transparent original is still used for `.ico`, macOS and Linux.
  Verified by inspecting the generated PNG assets; not yet confirmed on an installed package.
- **Notifications Against the Real API**: Receiving worked, but every
  write path used routes that do not exist. Verified against the live API: marking a
  notification as read posted to `/notice/read` (404) instead of the real
  `/user/read-notice` (key `noticeID`), so read state never persisted and the unread badge
  came back on the next poll. The unread-count fallback `/notice/unread_count` is also 404,
  and the `/notice/list` fallback is the announcements board (title/body/images/reactions),
  not notifications, so it was removed. There is no bulk read route, so marking all now
  posts once per unread notice, and deletion is local-only because the API exposes no delete
  route for user notifications. The UI also compared `type` against `'shake'` and
  `'warning'`, but the API sends uppercase codes (`GROUP_WARNING`, `GROUP_JOIN_APPROVED`,
  ...) and has no shake type at all, so icons and colours now follow a normalised kind. The
  empty "Sem detalhes" placeholder was dropped: the API fills only `i1`.
- **Empty Band Around the Planner Panel**: The planner's left panel has a
  fixed width, and the surrounding Row did not stretch its children, so the panel was
  centred vertically and left a 101 px empty band above the D-Days and another one beside
  the to-do list. The row now stretches its children, so the panel fills the tab height.
  A layout test pins the panel's top and height to the tab's.
- **Subject Dialog Did Not Refresh and Rows Had a Dead Zone (Fixes Issue #5)**: A newly
  created subject only appeared after reopening the dialog because the list was a
  snapshot taken when it opened; the row also only reacted to taps on the colour dot
  and the title, so tapping the empty area did nothing. The dialog now appends the
  created subject, validates empty and duplicate titles, surfaces submission errors, and
  the whole row is a single tap target.
- **Muted Text Failed WCAG AA in Every Theme (Fixes Issue #5)**: The low-emphasis text
  token reached as low as 1.74:1 (Cyberpunk Neon) and 1.81:1 (Sunset Amber), and four of
  the seven palettes stayed under 3:1. `textMuted` was recomputed per theme so every
  surface reaches at least 4.6:1, the theme-blind `AppColors.textMuted` constant was
  replaced by the `context.appTextMuted` token across nine files, the 0.8 alpha on the
  login legal disclaimer was dropped (2.90:1 when blended) and `AppTextStyles.labelSmall`
  now takes its colour from the active theme. A dedicated WCAG test guards the palette.
- **Subject Names Ignored the Active Theme**: Subject names were painted
  with fixed colours (pure white in the selection dialog and the management list, and the
  subject accent colour in the badge under the clock), unlike ranking rows and every other
  label. They now follow the theme text colour, while the colour dot, border and caret keep
  the subject accent colour.
- **Group Settings Could Never Save and Always Reported Success (Fixes Issue #5)**: All six
  `/group/setting/*` routes answer 404 on the live API, and the panel still reported success
  when all five calls failed. Verified against the live API that `POST /group/info/edit` is
  keyed by `id` (not `groupID`, which answers 500) and is a partial update accepting
  `t, cid, gt, mc, nt, pw, il, ic`; the settings now route through that endpoint and the
  panel reports success only when every attempted update succeeded, naming the fields that
  failed otherwise.
- **Group Discovery Always Searched Brazil (Fixes Issue #5)**: `/group/list-new-2` honours
  `country_id`, but the explore call never sent one, so the repository defaulted to 23 and
  every user browsed the Brazilian board. The selected country is now sent and the list
  reloads when the region changes; an empty region names the region searched and offers an
  explicit action to view another one instead of silently widening the query.
- **Group Chat Could Not Send and Hid Timestamps (Fixes Issue #5)**: The client posted a
  guessed payload (`nickname`, `userID`, `category`, `createdAt`, `updatedAt`) while the live
  API accepts `{group_id, message}` and derives the sender from the token, and the optimistic
  bubble stayed on screen when the call failed, so a rejected message looked delivered. The
  payload now matches the verified schema, a failed send removes the bubble and reports the
  error, each message renders its `ts` timestamp, and `did` (a device id) is no longer read
  as a studicon id.
- **Nudge Reported Success Even When Refused (Refs Issue #5)**: `shakeMember` answers `false`
  on failure instead of throwing, but the screen showed a success message on both branches,
  the error branch even using the success colour. The sent message now appears only when the
  API accepted the nudge. Reception on desktop is **still not possible**: the API exposes no
  nudge notification type at all (the official app delivers nudges over FCM push, and the
  notification list schema has no shake/nudge code), so the 30-second notification poll cannot
  receive one. This stays pending the push investigation.
- **Presence Calendar Could Not Go Back a Month (Fixes Issue #5)**: The calendar always
  rendered the current month, kept no month state and built every cell from "today". It now
  takes an explicit month plus a change callback, derives the grid and the today highlight
  from the displayed month, adds previous/next controls, and loads the displayed month on
  demand through the new `fetchDailyStudyMs`.
- **Statistics Pie Collapsed Into a Single Slice (Fixes Issue #5)**: The pie read `sb` from
  each day object, but the subject only exists on the sessions nested inside `ls`, so an
  entire month became one "Geral" slice. Time is now aggregated per session, falling back to
  the day total only when the day carries no session detail. The "Região" scope also sent no
  country, so rankings always used the hardcoded Brazilian id.
- **The 24h Map Was a Hardcoded Placeholder (Refs Issue #4)**: The heatmap was painted from
  a fixed day (`2026-08-11` plus a generated pattern) and never showed the user's data.
  Sessions carry `st` (ISO start) and `sm` (duration), so a new `fetchHourlyStudyMinutes`
  places minutes on the hours actually studied across the requested range. Sessions that cross
  midnight continue into the next calendar day's row instead of losing the remainder, and a
  session is placed on the API's `dt` day with the hour taken from `st` in the local timezone.

## [1.1.7] - 2026-11-01

### Fixed
- **Localized Messages Everywhere**: User-facing messages produced outside the widget tree (authentication errors, OAuth failures, group actions, notification timestamps, store and timer messages) were still hardcoded in Portuguese. They now resolve through a `trMsg` helper backed by the loaded translation, the language selector lists language names in the active language, and relative timestamps follow the locale. The new entries ship in the seven supported languages (PT, EN, ES, KO, JA, zh-CN, zh-TW).

## [1.1.6] - 2026-11-01

### Fixed
- **Planner To-Do Dates Aligned with the Mobile App**: To-Dos were queried against a UTC calendar day and created at `00:00Z`, so tasks appeared on a different date than in the YPT mobile app; the planner also re-applied the reset hour to the selected date, which always queried the previous day. Queries now use the country study-day window (`[05:00 local, +24h)` against the fixed country GMT offset from the registry), creation writes the study-day start instant, updates keep the original time of day, and the selected calendar date is no longer shifted.
- **Timer Session Resync with YPT**: The running session lived only in memory, so a crash, update or forced exit left Desky reporting "Inactive" while the phone kept counting. The session is now persisted, restored on launch, reconciled with YPT's daily log on launch, every minute and when the window is resumed, and cleared on stop/logout. Daily logs also receive the selected country timezone and language instead of a hardcoded `America/Sao_Paulo`/`pt`.
- **Localization Fallback Leaking Portuguese**: Non-Portuguese locales no longer fall back to Portuguese dictionary text (English is the neutral fallback) and a failed translation asset load now falls back to `en.json`; twelve keys used by the UI but missing from every dictionary were added across the seven supported languages.

## [1.1.5] - 2026-10-29

### Added
- **New Theme Presets (Sakura Pastel & Nordic Frost)**: Added two fresh hand-crafted palettes expanding Desky's customization options in response to community feedback on Issue #2:
  - **Sakura Pastel**: Soft rose pinks, lavender accents, and elegant dark cherry slate tones.
  - **Nordic Frost**: Clean Arctic ice mint, frosty cyan, and slate deep ocean tones.
  - Updated theme selection dialog and all localized dictionary keys across 11 supported languages.

### Fixed
- **Settings Theme Selector De-duplication**: Removed redundant "Aparência & Tema" entry from inside the `StudyPreferencesDialog` modal, ensuring the main Settings/Profile list tile serves as the single, clean source of truth for appearance customization (Fixes Issue #2).

## [1.1.4] - 2026-10-27

### Fixed
- **Timer State & Visual Persistence Across Tab Switching**: Resolved bug where navigating from the Timer tab (`/home`) to other tabs (such as 'Groups' or 'Timetable' / 'Planner') visually reset the timer display to `00:00:00` and reverted the control button to "INICIAR" while leaving the study session running on the backend (Fixes Issue #3):
  - **Decoupled Riverpod Dependencies**: Removed `ref.watch(authStateProvider).user` from `timerNotifierProvider` which previously triggered provider invalidation and cancellation of the study ticker whenever `refreshUserGroups()` was called in `GroupsScreen`. Replaced with `ref.read` and dynamic listeners (`ref.listen`) for studicon avatar updates and logout lifecycle handling without disposing active sessions.
  - **Wall-Clock Elapsed Time Calculation**: Replaced naive incremental tick arithmetic with wall-clock time difference (`DateTime.now().difference(sessionStartAt)`), eliminating timer drift and ensuring millisecond-accurate elapsed time even when navigation or window backgrounding delays ticker execution.
  - **Subject Data Fetching Safeguards**: Prevented background `loadSubjects()` queries from overriding in-progress session time and active subjects while the timer is running.
  - **Deduplicated Subject Repository Providers**: Consolidated `subjectRepositoryProvider` declarations in `timetable_screen.dart` and `timer_notifier.dart` into a single canonical definition in `subject_repository.dart`.
  - **Automated Test Coverage**: Added comprehensive unit and widget tests in `test/unit/timer_tab_switch_persistence_test.dart` verifying state persistence across authentication state changes, wall-clock time accuracy, settings updates, and screen tab switching.

## [1.1.3] - 2026-10-27

### Fixed
- **Complete End-to-End Theme Propagation Across All Screens**: Systematically eliminated all remaining hardcoded static color tokens (#121624, #0A0D14, #A78BFA) across the entire application, propagating dynamic theme tokens (context.appBackground, context.appSurface, context.appCard, context.appBorder, context.appPrimary, context.appTextPrimary, context.appTextSecondary, context.appTextMuted) to ensure 100% visual consistency with user-selected themes (AMOLED Lilac, Midnight Navy, Cyberpunk Neon, Forest Emerald, Sunset Amber) (Fixes Issue #2):
  - **Ranks & Analytics**: Updated Ranks period selector pills, member cards background, weekly study bar charts (BarChartGroupData rods using context.appPrimary), and subject distribution pie chart to dynamically reflect selected theme colors.
  - **Flashcards & Study**: Replaced dark containers, purple action buttons (+ Add flashcards, + Deck), and modal inputs with dynamic theme tokens.
  - **Store & Avatars**: Replaced static black backgrounds and purple equipped avatar indicator borders with context.appPrimary and context.appCard.
  - **Timelapse Gallery & Player**: Migrated gallery grid cards, header, and timelapse video player dialog to dynamic surface colors and adaptive text tokens.
  - **Challenges & Missions**: Updated mission tab indicators, challenge cards, goal badges, and join dialogs to dynamic primary and card colors.
  - **Profile & Settings**: Propagated dynamic theme tokens to Profile stats summary cards ("Total time today", "Subjects", "My groups") and settings navigation tiles.
  - **Planner & Timetable**: Harmonized timetable grid, D-Day counter badge, selected date highlight, to-do list items, progress card, and add buttons with active theme palette.
  - **Groups & Exploration**: Updated group search inputs, category selection pills, group detail leader panels, and "Join group" action buttons to dynamic theme colors.
  - **Shared UI & Authentication**: Updated sidebar notification bell, notification panel dialog, notification center screen, subject chips, login screen, and registration flow to seamlessly inherit dynamic theme colors.

## [1.1.2] - 2026-10-25

### Fixed
- **Multi-language Group Room & UI Fallbacks**: Resolved untranslated text strings falling back to Portuguese in English and non-Portuguese locales by adding over 120 multilingual entries across 10 languages (EN, ES, KO, JA, ZH-CN, ZH-TW, FR, DE, IT, RU) and harmonizing dictionary keys in `assets/translations/en.json`, `assets/translations/pt.json`, and `_coreFallbackTranslations` (Fixes Issue #2).
- **Group Room Leaderboard & Period Rankings**: Fixed 404 error on group rankings by querying the authenticated API endpoint `/logs/group/member/ranks` directly with zero-padded date formatting, supporting `pv` studicon identifier and `tm`/`totalMs` time metrics in `GroupMemberModel` and `RankEntryModel`, and displaying active rankings for day, week, and month periods (Fixes Issue #2).
- **Group Room Accumulated Study Hours**: Added aggregate room study time calculation and display in the group detail room header (`today_total`) and dynamically updated period total time (`today_total`, `weekly_total`, `monthly_total`) with localized labels in the group rankings tab (Fixes Issue #2).
- **In-App Visual Theme Customizer Dynamic Propagation**: Overhauled theme system to dynamically propagate active theme palette colors (`palette.background`, `palette.surface`, `palette.card`, `palette.border`, `palette.primary`, `palette.textPrimary`, `palette.textSecondary`, `palette.textMuted`, and `palette.heatmapL1..L4`) across all UI shells, sidebar navigation, timer screen, groups screen, planner, global ranks, heatmap grid, study calendar, and user profile (Fixes Issue #2).

## [1.1.1] - 2026-10-23

### Added
- **In-App Visual Theme Customizer**: Built-in visual theme picker (`DeskyThemePalette`) with 5 hand-crafted palettes (AMOLED Lilac, Midnight Navy, Cyberpunk Neon, Forest Emerald, Sunset Amber), dynamic runtime palette switching with Riverpod (`ThemeNotifier`), persistent theme preference (`settingsRepository`), and accessible via both the Profile screen header and the Study Preferences modal.
- **Arch Linux & CachyOS Native Package Support**: Added PKGBUILD packaging recipe (`linux/archpkg/PKGBUILD`), automated local packaging script (`scripts/build_archpkg.sh`), and GitHub Actions CI workflow to build and publish `Desky-Linux-x64.pkg.tar.zst` on every release.
- **Group Room & Theme Translations**: Added comprehensive fallback translations for all group room states and tabs (`today_study_time`, `focus_rate`, `group_ranking`, `studying_now`, `total_members`, `today_total`, `weekly_total`, `monthly_total`, `all_time_total`, `no_study_records`, `room_type`, `auto_accept`, `public_room`, `private_room`, `theme`, `amoled_lilac`, `midnight_navy`, `cyberpunk_neon`, `forest_emerald`, `sunset_amber`) across 11 languages (PT, EN, ES, KO, JA, ZH-CN, ZH-TW, FR, DE, IT, RU).

### Fixed
- **Group Ranking YPT API Period Date Format**: Fixed HTTP 400 bad request in group rankings (`fetchGroupRanks`) by sending unpadded period start dates (`YYYY-M-D`) expected by the YPT API instead of unformatted or zero-padded dates, with an optional `referenceDate` parameter for deterministic testing.
- **Live Study Room Active Members Ordering**: Group room members tab now sorts active members descending by accumulated study time (`studyMs`) for consistent leaderboard display.
- **Group Detail Screen Header Fallback**: Fixed header member count subtitle fallback when translations are loading or missing.
- **Resting & Goal Translation Aliases**: Decoupled `resting` from `study_rest_label` and removed duplicate `goal_statistics_text_total_time` from `goal` to prevent incorrect status text overlaps.
- **Linux Clang 19+ CMake Compatibility**: Suppressed `-Wdeprecated-literal-operator` in `linux/CMakeLists.txt` to prevent legacy header warnings in third-party plugins (such as `flutter_secure_storage`) from triggering `-Werror` build failures on modern compilers.

### Changed
- **Multi-language Documentation**: Updated `README.md`, `README.pt-BR.md`, and `README.zh-CN.md` with Arch Linux / CachyOS installation instructions (`pacman -U`) and theme customizer highlights.

## [1.0.10] - 2026-10-11

### Fixed
- **Ranks and Profile Screen Translations**: Added missing fallback mappings and aliases in `AppTranslation` for `stats` ("Stats & 24h Map"), `subject_distribution` ("Subject Distribution"), `no_status_msg` ("No status message."), `device` ("Device"), `no_data`, and `no_ranks` across all supported languages.

### Changed
- **Authentication Modernization**: Removed legacy QR auth service, dialog, and dependency in favor of direct credential and OAuth flows.
- **Landing Page & Documentation**: Integrated dynamic GitHub releases download counter, added Simplified Chinese README, and refined landing page hero elements.

## [1.0.9] - 2026-10-11

### Fixed
- **Rank Repository Date Test Determinism**: Fixed CI test failure in `RankRepository Tests fetchGlobalRanks URL does NOT contain zero-padded date` caused by non-deterministic `DateTime.now()` naturally matching two-digit months and days (e.g., October 11th). Added optional `referenceDate` parameter to `RankRepository.fetchGlobalRanks` and made the unit test fully deterministic.
- **Complete Multilingual UI Localization**: Localized previously hardcoded UI strings across all 28 supported locales in `assets/translations/` and `AppTranslation` fallbacks (notification panel headers/empty states, time reset labels in country dialog, timelapse frame counters, initial subject fallback, and offline synchronization status messages).

## [1.0.8] - 2026-09-20

### Added
- **Microsoft Store Automated Deployment & Localized Release Notes**: Automated MSIX packaging, upload, metadata localization, and certification submission to Microsoft Store via MSStore CLI and GitHub Actions (`microsoft/microsoft-store-apppublisher@v1.4`), with automatic multilingual translation of release notes across all store locales.
- **Release Assets Separation**: Configured the CI/CD pipeline to deploy the MSIX package directly to the Microsoft Store without publishing the raw `.msix` file on public GitHub Releases, reserving GitHub Releases strictly for direct standalone installer bundles.

### Fixed
- **Windows 10 DWM Black Border**: Resolved the 8-pixel black border artifact around the desktop window on Windows 10 by making `windowOptions.backgroundColor` transparent on Windows (`Platform.isMacOS ? AppColors.background : Colors.transparent`) and re-enabling `windowManager.setAsFrameless()` on Windows to eliminate DWM non-client frame insets.

## [1.0.7] - 2026-09-07

### Fixed
- **MSIX OAuth Credential Erasure**: Configured `build_windows: false` in `pubspec.yaml` (`msix_config`) and passed `--build-windows false` to `dart run msix:create --store` in `.github/workflows/release.yml`. By default, `msix:create` re-invoked `flutter build windows` without compilation flags, overwriting the release binary and stripping out `--dart-define` credentials (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `DISCORD_CLIENT_ID`). Skipping the redundant build step preserves the credentials compiled into the release binaries for Microsoft Store certification.
- **Strict Environment Credential Enforcement**: Cleared hardcoded fallback client identifiers in `EnvConfig` (`defaultGoogleClientId = ''` and `defaultDiscordClientId = ''`), guaranteeing that credentials are strictly loaded from local `.env` files in development or via compile-time `--dart-define` arguments injected by GitHub Actions secrets in release builds.
- **Discord RPC Connection Guard**: Added defensive check to bypass Discord named pipe / socket connection attempts when `_clientId` is empty.
- **YPT API Device Model Contract**: Restored `defaultDeviceModel` constant to align with YPT backend device model requirements.

## [1.0.6] - 2026-09-07

### Fixed
- **macOS Ad-hoc Codesign SIGKILL Crash**: Removed restricted `keychain-access-groups` entitlement from `Release.entitlements` and `DebugProfile.entitlements`. This entitlement required an Apple Developer Program provisioning profile; under CI/CD ad-hoc code signing (`codesign -s -`), macOS kernel AMFI killed the application on launch with `EXC_CRASH (SIGKILL (Code Signature Invalid))` / `Termination Reason: CODESIGNING 1`. `flutter_secure_storage` safely operates in its isolated App Sandbox keychain without this entitlement.
- **macOS Graphics Glitches & Black Screen**: Disabled Flutter Impeller rendering backend on macOS via `FLTEnableImpeller = false` in `macos/Runner/Info.plist`, preventing GPU Metal framebuffer corruption, blank screens, and diagonal artifacts on macOS Monterey and older Intel/Apple Silicon GPUs.
- **Desktop Window Background Solidification**: Changed desktop `windowOptions.backgroundColor` from transparent to solid dark `AppColors.background`, eliminating window server compositor flicker and blank screens on startup.
- **Historical Subject Sync (YPT Delta Sync & sbu nullification)**: Fixed subject synchronization in `SubjectRepository.fetchSubjectsData()` to query `/user/v2/reload/info` with `sbu: null` in the `cd` (cache dates) payload, ensuring the full historical subjects catalogue is returned rather than only today's modified subjects.
- **Immediate Post-Login Subject Caching**: Updated `AuthRepository` to immediately extract and persist `data['ss']` returned by the social login endpoint (`/user/social/sign-up-jwt`) and email login into `SharedPreferences`, ensuring subjects appear instantly post-login.
- **Resilient Offline Subject Fallback**: Added persistent caching of subjects in `SharedPreferences`, ensuring subjects are never cleared if the network request fails or returns an empty list.
- **macOS Keychain Entitlement**: Added `keychain-access-groups` to `Release.entitlements` and `DebugProfile.entitlements` to guarantee secure token storage via `flutter_secure_storage` under macOS App Sandbox.
- **Static Analysis Exclusions**: Added `openypt/**` to `analysis_options.yaml` exclude list to prevent analyzer hangs on decompiled mobile sources.
- **macOS App Sandbox Entitlements**: Added `com.apple.security.network.client`, `com.apple.security.network.server`, `com.apple.security.files.user-selected.read-write`, and `com.apple.security.files.downloads.read-write` to `Release.entitlements` and `DebugProfile.entitlements`, fixing the `SocketException: Operation not permitted (errno = 1)` during Google OAuth login and ensuring PDF/file access.
- **Window Controls Duplication (macOS & Linux)**:
  - Hidden custom titlebar buttons (minimize, maximize, close) on macOS, honoring native window traffic light buttons at the top left.
  - Disabled `GtkHeaderBar` in `linux/runner/my_application.cc` (`use_header_bar = FALSE`), eliminating double title bars and button duplication on Linux GNOME desktop.
- **Study Session Exit & Cleanup**:
  - Guaranteed that active, paused, or unsynced study sessions are gracefully ended and synced via `TimerNotifier.stopStudy()` before app shutdown.
  - Added POSIX signal handlers (`SIGTERM` and `SIGINT`) on macOS and Linux to ensure clean termination with `exit(0)`.
- **Dynamic Platform & Device Detection**: Resolved dynamic OS detection for Windows, macOS, and Linux in profile settings and API payloads, eliminating hardcoded Windows desktop identifiers across different operating systems.
- **Internationalization (i18n)**: Added comprehensive multi-language translations (11 languages: pt, en, es, ko, ja, zh-cn, zh-tw, fr, de, it, ru) for all OAuth errors, socket errors, and window control tooltips.

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
