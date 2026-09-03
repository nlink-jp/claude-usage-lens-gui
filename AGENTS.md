# AGENTS.md — claude-usage-lens-gui

## What this is

A macOS menu-bar app (SwiftUI, `MenuBarExtra`, `LSUIElement`) that shows today's
Claude usage cost and expands into charts. A thin front-end over the
`claude-usage-lens` CLI — the CLI owns parsing/pricing/aggregation; this app only
invokes it (`--json`) and renders. macOS 14+.

## Build & test

```sh
make run        # swift run (debug)
make build      # swift build -c release
make build-app  # signed .app (embeds the CLI from $CLI_BIN into Resources)
make package    # build-app + notarize + staple + zip
make verify-release  # gate: .notarized marker + stapler validate (run before upload)
make test       # swift test
```

## Structure

```
Sources/ClaudeUsageLens/
  Entry.swift       @main; single-instance guard, then ClaudeUsageLensApp.main()
  SingleInstance.swift singleInstanceDecision() — startup duplicate-
                    instance guard (pure; pids in, decision out)
  App.swift         MenuBarExtra live label (tinted by weekly state) +
                    Window("analysis") + Window("settings")
  UsageModel.swift  ObservableObject; timer → ingest + summary; loadAnalysis();
                    weekly-budget compute + notifications
  CLIRunner.swift   locate + run the CLI, decode JSON
  Models.swift      Codable Summary / Row (match the CLI's report JSON)
  MenuBarMode.swift menu-bar display mode (price/tokens/both/weekly)
  WeeklyLimit.swift pure lastReset/state/forecast helpers +
                    LimitBasis/LimitState/WeeklyStatus/WeeklyForecast
  Settings.swift    UserDefaults keys/defaults + WeeklySettings snapshot
  LoginItem.swift   SMAppService wrapper for launch-at-login (pure state mapping)
  NotificationAuth.swift  pure denied? rules for the notification permission + pane URL
  AppVersion.swift  the build's version for display (pure fallback rule)
  PopoverView.swift today's cost + tokens + last-30 + weekly bar
  AnalysisView.swift Swift Charts: period total + daily / model / project
  SettingsView.swift weekly-budget Form (shown in the settings Window)
Info.plist          LSUIElement=true (menu-bar agent, no dock icon)
scripts/            codesign-darwin-app.sh, notarize-darwin-app.sh, make-icns.sh
assets/             AppIcon-1024.png (→ AppIcon.icns at build)
```

## Gotchas / conventions

- **CLI is the data source.** Don't reimplement parsing/pricing in Swift — call
  the CLI. `Models.swift` must track the CLI's `--json` field names (snake_case
  via CodingKeys). If the CLI's report JSON changes, update these.
- **Finding the CLI** (`CLIRunner.findBinary` → pure, tested `resolveBinary`):
  bundled Resources first (signed/notarized = trust anchor), then `/usr/local/bin`,
  `/opt/homebrew/bin`. The `$CLAUDE_USAGE_LENS_BIN` override and the local dev path
  are `#if DEBUG`-only, so a release build can't be redirected by the env var
  (issue #1). Keep `make build-app` bundling the CLI so the `.app` is self-contained.
- **Live menu-bar label**: the App holds `UsageModel` as `@StateObject`, so a
  `@Published` change re-evaluates the `MenuBarExtra` label. The refresh timer is
  started once from `makeModel()`.
- **CLI work off the main thread**: `UsageModel` runs the CLI on a serial
  background queue and hops `@Published` writes back to main.
- **Error surfacing**: a CLI failure becomes a friendly summary via the pure
  `CLIError.summarize` (crash / permission / missing path / first stderr line);
  `UsageModel` exposes `lastError` (summary) + `lastErrorDetail` (raw), and the
  popover shows the summary with the raw output as smaller, selectable detail.
- **Unpriced badge (CLI ≥ 0.7.0 contract)**: `report --summary --json` carries
  `unpriced_records` / `unpriced_models` — Claude Code rows that hold tokens at
  $0 (a model the CLI's table didn't know at ingest, or a table updated since
  without `reprice`). `UsageModel.unpricedUsage` derives the badge from the
  **last-30-days** summary, not today's, so an update that bundles a newer table
  still surfaces the rows the old build wrote. Surfaces: `⚠︎` appended to the
  menu label (`menuLabel`), an orange section in the popover naming count +
  model, and a **Reprice** button (`CLIRunner.reprice()` then refresh).
  `repricePhase` (idle / running / done / failed(reason)) drives the hint via
  `unpricedHint(phase:)` — every phase has a line, because a Bool could not say
  "running" or "failed" and a silent second wait reads as a dead button. A
  failed reprice shows the CLI's reason **in the box**, not via `lastError`
  (the popover's error branch only renders when there is no summary at all).
  The button is disabled only while running: a finished attempt may be
  retried (reprice is idempotent, and the user may have priced the model in
  the CLI config), and the phase resets to idle when the badge clears (new
  episode). What survives a reprice is a model this build's CLI doesn't know
  either. Both fields are optional in `Summary` so a pre-0.7.0 CLI on PATH
  still decodes — which is also why `make verify-release` refuses a bundled
  CLI whose `--version` is not a clean `vX.Y.Z`: a stale CLI would remove this
  feature silently. Text rules are pure and tested (`UnpricedTests`). This
  exists because the CLI's ingest-time warning goes to stderr with exit 0,
  which the app never showed — Opus 5 (v0.1.9) and Fable 5.1 (v0.3.0) both
  sat at $0 silently before it.
- **Weekly monitor**: settings live in UserDefaults (`Settings.swift` keys +
  `WeeklySettings` snapshot; `SettingsView` binds the same keys via @AppStorage).
  `UsageModel` caches the raw weekly usage (cost + in+out tokens) so limit / basis
  / threshold changes rebuild the status **instantly with no CLI call**
  (`applyWeeklySettings`); only reset day/time re-queries (`refreshWeekly`, using
  the CLI's datetime `--since`). Notifications fire only from the periodic refresh
  on an upward severity crossing, gated by the "Show notifications" setting — never
  while tuning settings.
- **Weekly percents are a derived pair**: `usedPercentDisplay` /
  `remainingPercentDisplay` on `WeeklyStatus`, not two independent roundings —
  they're printed side by side and must sum to 100. Over budget the used side
  keeps counting past 100 and the remainder pins at 0, matching `remaining`.
- **Pace forecast** (`WeeklyLimit.forecast`, pure + tested): linear
  extrapolation of the window's usage to its end, plus the instant the limit is
  hit when that lands before the reset. Its `state` is scored against a fixed
  100% critical line (not the user's critical threshold) so "will exceed" always
  reads red, and `reliable` is false inside the first 5% of the window — the UI
  names that state instead of showing a number built from one session.
  `buildWeeklyStatus` attaches it, so views stay dumb; `UsageModel.forecastLabel`
  / `forecastIcon` render it and are unit-tested as pure functions.
- **Calibration (CLI ADR-0001)**: `fetchWeeklyUsage` first asks
  `CLIRunner.limits()`; when the CLI holds a usable calibration the derived caps
  (both bases) and the **official reset cadence** ride along in the cached
  `WeeklyUsage`, and `buildWeeklyStatus` prefers the calibrated cap over the
  assumed budget (`WeeklyStatus.calibrated` drives the popover badge and the
  Settings "Active cap" row). `calibrated: false` from the CLI ⇒ the settings
  window/budget fallback — absence is a state, not an error. Settings →
  Calibration shells out to `calibrate add`; feedback lands in
  `calibrationMessage`. `limits --json` decodes with `.iso8601` dates — the
  Go CLI emits whole-second RFC3339; keep both sides in lockstep.
- **Settings/analysis windows, not the Settings scene**: a menu-bar (LSUIElement)
  app can't reliably focus the `Settings` scene / `SettingsLink`, so both open as
  plain `Window`s via `openWindow(id:)` + `NSApp.activate(ignoringOtherApps:)`.
- **Notification clicks launch by bundle ID — enforce a single instance.**
  Clicking a banner makes notificationd open the app via LaunchServices,
  which resolves `jp.nlink.claude-usage-lens-gui` among *all* registered
  copies (`dist/` dev builds, release-verification extractions,
  `/Applications`) and may start a different copy than the running one →
  two menu bar items, double polling. Guarded at two layers:
  `LSMultipleInstancesProhibited` (Info.plist, stops LaunchServices
  launches) and a startup check in `Entry.main`
  (`singleInstanceDecision`, pure + tested) that exits with a stderr note
  (covers direct exec / `open -n`). Side effect: to run a `dist/` build,
  quit the installed instance first — a second copy now refuses to start.
- **Version on screen**: `make build-app` substitutes `git describe` into
  Info.plist's `CFBundleShortVersionString`, and the popover footer prints it
  **verbatim** (`AppVersion`, selectable). There is no `--version` here, so this
  is the only way a bug report can name its build; "dev" means an unbundled run
  or an unsubstituted placeholder. Keep the display rule pure + tested.
- **Signing**: `--deep` signs the bundled CLI too. Pure SwiftUI/AppKit needs no
  entitlements (Hardened Runtime alone). Notarize + staple the `.app`.
- **Native, not Wails**: deliberate deviation from the CLI's RFP — a menu-bar
  app is cleaner native. macOS-only; a cross-platform GUI would be a separate
  Wails project.

- **Launch at login (`LoginItem.swift`)**: `SMAppService.mainApp` is the source of
  truth — no persisted flag; the toggle mirrors `LoginItem.current` on appear and
  after every change. `.notFound` (never registered) maps to `notEnabled`, never to
  a disabled control (the only way to register is the switch). Every call is read
  back (`verifyMessage`) and any disagreement is shown beside the toggle with an
  "Open Login Items" button. Registration needs a real `.app`; `swift run` says so.
- **Notification denial is stated, not swallowed (`NotificationAuth.swift`)**:
  `requestNotificationAuth` publishes `notificationsDenied` from the
  `granted`/`error` result (and logs a refusal to stderr); `SettingsView` shows
  an orange line + "Open Settings" (Notifications pane) under the toggle while
  it is ON and denied. `refreshNotificationStatus` re-reads the status without
  prompting on appear and on `didBecomeActive`, so the line clears after the
  user flips the switch in System Settings. Only `.denied` counts —
  `.notDetermined` is "not asked yet", never a denial.

## Design reference

- The CLI: https://github.com/nlink-jp/claude-usage-lens
