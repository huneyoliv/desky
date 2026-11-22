# Pending Changelog

Entries staged here are moved into `CHANGELOG.md` as a new `## [<version>] - <date>`
section when a release is cut, and this file is cleared (see the release checklist
in `CHANGELOG.md`). This file is intentionally gitignored.

## Added

- Planner tasks now offer an explicit subject selector, including **No subject**,
  and resolve subject names from the same timer state used by study sessions.
- Open Planner tasks can start the real timer with their subject. The action sends
  the task id to `/study/start`; acceptance was verified live earlier, while
  persistent task-session association remains unconfirmed and is not claimed.
- Localized the new Planner subject/start/failure controls in all 11 supported languages.

- Timer appearance now includes persisted Aurora and Sunset gradients, local
  PNG/JPEG/WebP images up to 20 MB, and Digital, SF Pro or Pretendard font
  selection. Missing/unreadable images fall back safely; no media is uploaded.
  Video backgrounds are not included (#10).

## Fixed

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
- Added button geometry coverage for all 11 supported languages. All 22
  Timer/Pomodoro labels fit within the fixed 296 px button without clipping.

- The Timer now syncs its clock with the server. `GET /time/` returns the
  timestamp under `t`, but the client only read `timestamp`, so every sync
  silently fell back to the local clock. Both keys are now accepted.

## Known Limitations

- Group creation is not supported: the create contract is unconfirmed (three attempts failed).
- Starting a session from a to-do sends taskId, but no association is observable on the API.
- Recurring tasks: editing affects only the selected occurrence; deleting offers one occurrence or the whole series.
- Nudge reception on desktop is not possible yet (no nudge notification type; the official app uses FCM push).
- Background videos (issue #10) are not implemented.
- Study vs rest breakdown is not available (rest contract unknown).
- Joining challenges is not supported; the Challenges tab is read-only.

## Changed

- The Planner tab formerly labelled Grade Horária is now Calendário, with a new
  `planner_calendar_tab` key translated in all 11 supported languages. The
  internal timetable title remains descriptive and unchanged.
- The Timer/Pomodoro switcher is centred independently of the left/right header
  content, with geometry tests at 1280, 960 and 640 px.

- Updated the API documentation with the live-validated To-Do create/edit/delete
  and start/stop contracts. Group creation remains documented as blocked because
  the available HAR contains no group/todo REST writes and the APK does not expose
  the complete group-creation payload.

Refs #5, #7 and #10. Fixes #8.
