# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.3.2] - 2026-09-03

### Fixed

- **A notification denial was invisible.** When macOS has notifications
  turned off for the app (declined, or the first prompt dismissed by quitting),
  the "Show notifications" toggle stayed ON with nothing ever arriving and no
  hint why. The permission result is now kept, the settings window writes
  "Notifications are turned off for this app in System Settings." under the
  toggle with an **Open Settings** button to the Notifications pane, and the
  line clears on its own once the switch is flipped there. The refusal is
  also logged to stderr. (#3)

## [0.3.1] - 2026-09-03

### Added

- **Launch at login** toggle in Settings (General). SMAppService is the source
  of truth: the switch mirrors its status, a change is read back and any
  disagreement (approval pending, not registered, bare binary) is written
  next to the switch with a button to System Settings › Login Items.

## [0.3.0] - 2026-09-02

### Fixed

- **Claude Fable 5.1 usage showed as $0**, understating today's cost, the
  weekly budget, the charts and the analysis totals — the same failure as Opus
  5 in v0.1.9: the bundled CLI's rate table predated the model, and an unpriced
  model is costed as free. Fable 5.1 is now Claude Code's default model, so the
  undercount grew with every turn.

  Bundles `claude-usage-lens` **v0.7.0**, which prices Fable 5.1 (and Mythos
  5.1) — including its cheaper cache reads, 0.025× rather than the usual 0.1×,
  which is most of a Fable session's cost — and corrects Sonnet 5 to the $2 /
  $10 that is now its standard price.

  **After updating, click Reprice in the popover** (or run the bundled CLI's
  `reprice`) to correct the rows already in your store; until then they keep
  their $0 and the badge below says so.

### Added

- **Unpriced usage is flagged instead of silently counted as $0.** The CLI
  now reports how many stored Claude Code turns carry tokens at $0 (a model its
  rates don't know, or a rate update not yet applied to history), and the app
  shows it: a `⚠︎` after the menu-bar figure, and an orange section in the
  popover naming the count and the model over the last 30 days, with a
  **Reprice** button that applies the bundled CLI's current rates to stored
  history and refreshes. The attempt's own state lives in the same box —
  running, or failed with the CLI's reason — and if turns remain unpriced
  after a reprice the hint changes to "update the app (or price the model in
  the CLI config) and reprice again": that is a model this build's CLI cannot
  price either. The button is disabled only while a reprice is in flight.
  Previously the only signal was a stderr warning at ingest time, which the
  app never surfaced.
- **`make verify-release` checks the bundled CLI** reports a clean release
  version (`vX.Y.Z`), so a stale or dirty CLI build cannot ship inside the
  `.app` — with the new fields optional, a stale CLI would have removed this
  very feature silently.

## [0.2.2] - 2026-08-25

### Fixed

- Clicking a notification banner could start a second instance (two menu
  bar items, double polling): notificationd opens the app via
  LaunchServices by bundle identifier, and with more than one registered
  copy of the .app (dev build in `dist/`, `/Applications`) it may launch
  a different copy than the running one. The app is now single-instance
  at two layers: `LSMultipleInstancesProhibited` in Info.plist stops
  LaunchServices launches, and a startup guard exits with a stderr note
  when another instance is already running (covers direct binary exec
  and `open -n`)

## [0.2.1] - 2026-08-18

### Added

- **Percent alongside every weekly figure.** The menu bar's weekly-remaining
  mode now reads `$116 · 58%` instead of a bare `$116` — an amount alone says
  nothing about how much of the week it buys. The popover's weekly line gives
  both sides of the split in amount and percent (`68% used · $1,200.00 left
  (32%)`), and Settings → Current gains a **Remaining** row. The two percents
  are derived as a pair, so they always sum to 100 rather than rounding to 99.
- **Budget-overrun forecast.** The popover projects where the week lands at the
  pace so far — `On pace for $5,200.00 (137%) — budget gone Sat 14:26` — by
  spreading the window's usage over its elapsed slice and extrapolating to the
  reset. The line carries the *projection's* own severity (critical at ≥100% of
  the limit, warning at your warning threshold), so a week that is still within
  its thresholds but heading over the limit is flagged before the usage bar
  turns. Within the first 5% of a window the extrapolation is noise, and it says
  `Too early this week to project a pace` rather than printing a wild number.
  Also shown in Settings → Current as **At this pace**.
- **The running build's version**, in the popover footer (selectable). A
  menu-bar app has no `--version` to run, so there was previously no way to tell
  which build was running.

Bundled CLI unchanged — the weekly additions are computed from data the app
already had.

## [0.2.0] - 2026-08-08

### Added

- **Weekly budget calibrated to the real limit** (with CLI v0.6.0, its
  ADR-0001). Claude's actual quota can't be read from logs and the private
  OAuth usage endpoint is deliberately not used; instead, Settings gains a
  **Calibration** section: run `/usage` in Claude Code, enter the official
  weekly percentage and its reset time, and the app derives the real effective
  cap via the CLI (`calibrate add` / `limits --json`).
  - While calibrated, the weekly bar carries a green **calibrated** badge, the
    cap follows the official reset cadence, and Settings shows the active cap
    with its age. Warning/critical thresholds and notifications work unchanged
    on top.
  - With no (usable) calibration the monitor falls back to your assumed budget,
    now badged **assumed** — behaviour otherwise identical to v0.1.x.
  - Re-calibrate whenever the official percentage drifts from the app's
    estimate, and after plan/promotion changes.

Bundles `claude-usage-lens` **v0.6.0**.

## [0.1.9] - 2026-07-26

### Fixed

- **Claude Opus 5 usage showed as $0**, understating every figure in the app —
  today's cost, the weekly budget, the charts, and the analysis totals. The cause
  was in the bundled CLI, whose rate table predated the model: an unpriced model
  is costed as free by design, so Opus 5 turns contributed nothing. Because the
  app ingests on a timer, it was also *adding* $0 rows to the shared store every
  minute.

  Bundles `claude-usage-lens` **v0.5.0**, which prices Opus 5 (and fast mode)
  correctly and adds a `reprice` command.

  **After updating, run `claude-usage-lens reprice` once** to correct the records
  already in your store — the app's numbers come from that store, and existing
  rows keep their original (zero) cost until repriced. The bundled binary is at
  `/Applications/ClaudeUsageLens.app/Contents/Resources/claude-usage-lens`.

App behaviour is otherwise unchanged.

## [0.1.8] - 2026-07-12

### Changed

- **Release archive renamed** to `claude-usage-lens-gui-<version>-darwin-arm64.zip`
  (was `ClaudeUsageLens-<version>-macos-arm64.zip`), per `nlink-jp/.github`
  CONVENTIONS.md §Release Archive Standard. The `.app` inside is still
  `ClaudeUsageLens.app`.
- Bundles `claude-usage-lens` **v0.4.0**.

Packaging-only release; no change to the app's behaviour.

## [0.1.7] - 2026-07-09

### Fixed
- The weekly-budget value (and today's numbers) could freeze — e.g. stuck at `$0`
  after a reset — because macOS **App Nap** throttled the background menu-bar app's
  refresh timer. The app now opts out of App Nap so the 60s timer keeps firing (the
  menu-bar colour and weekly value stay live; system sleep is still allowed), and
  the popover **refreshes whenever it's opened**.

## [0.1.6] - 2026-07-06

Bundles `claude-usage-lens` **v0.3.1** (datetime `--since`).

### Added
- **Weekly budget monitor.** Set your own weekly budget (Claude's real weekly
  limit isn't readable), by **Cost ($)** or **Tokens (in+out)**, with a
  configurable **reset weekday/time** (local) and **two-tier** warning/critical
  thresholds. As you approach it:
  - the menu-bar number turns **orange (warning) / red (critical)**;
  - the popover shows a colored **This week: used / limit (%)** bar with the next
    reset; a new **"Weekly"** menu-bar display mode shows the remaining balance;
  - a **notification** fires once when severity rises — or turn notifications off
    (a "Show notifications" toggle) to keep the colour/bar only.
  - Settings (⌘, / "Settings…") update the displayed status **live** as you type;
    limit/basis/threshold changes recompute instantly with no CLI call. Requires
    `claude-usage-lens` with datetime `--since` (v0.3.1+).

## [0.1.5] - 2026-07-05

Bundles `claude-usage-lens` **v0.3.0** (local-timezone day boundaries).

### Changed
- Day boundaries / "today" now follow your **local timezone**. The app computes
  its date windows locally and passes `--tz local` to the CLI, so "Today" and the
  daily chart reset at your local midnight — not UTC.

## [0.1.4] - 2026-07-05

Bundles `claude-usage-lens` v0.2.2 (unchanged).

### Added
- Analysis panel now shows the **period total** (cost + tokens) in a header —
  previously it had per-model/per-project breakdowns but no overall total. It's
  the same summary derivation the popover's "Last 30 days" uses, so the panel
  total, the charts, and the popover all reconcile.

### Fixed
- 30-day cost figures now reconcile. The analysis panel's **by-model** and
  **top-projects** charts used a rolling `Nd` window while the daily chart used a
  calendar-aligned N days, so their totals didn't match; all charts now share the
  same calendar window (so by-model total == daily total). The popover's
  "30-day projection" — which extrapolated from **today alone** (today × 30, e.g.
  a wildly inflated figure) — is replaced by an actual **"Last 30 days"** total on
  that same window, so the popover and the analysis panel agree.

## [0.1.3] - 2026-07-05

Bundles `claude-usage-lens` v0.2.2 (unchanged).

### Added
- App icon — a magnifying glass over a usage waveform. Source
  `assets/AppIcon-1024.png` is turned into `AppIcon.icns` by
  `scripts/make-icns.sh` (sips + iconutil) and bundled by `make build-app`, wired
  through `CFBundleIconFile`. Shows in Finder / Get Info / Spotlight (the app is a
  menu-bar agent, so it has no Dock icon).

## [0.1.2] - 2026-07-05

Bundles `claude-usage-lens` v0.2.2 (unchanged).

### Changed
- Friendlier CLI error messages ([#2](https://github.com/nlink-jp/claude-usage-lens-gui/issues/2)):
  the popover now shows a short, actionable summary (permission denied, an
  unexpected CLI crash, a missing path, or the CLI's first error line) with the
  raw output kept as smaller, selectable detail — instead of surfacing bare
  stderr. The classification is a pure, unit-tested `CLIError.summarize`.

## [0.1.1] - 2026-07-05

Bundles `claude-usage-lens` **v0.2.2** (which adds its own security hardening).

### Security
- Harden CLI binary resolution ([#1](https://github.com/nlink-jp/claude-usage-lens-gui/issues/1)):
  the bundled, Developer-ID signed + notarized binary is the trust anchor and is
  resolved first. `$CLAUDE_USAGE_LENS_BIN` and the local dev path are now
  `#if DEBUG`-only, so a release build can't be redirected to an arbitrary binary
  by the environment; the hardcoded developer path no longer ships in release.
  Resolution logic extracted to a pure, unit-tested `resolveBinary`.

### Added
- Getting Started guide (`docs/en/getting-started.md`, `docs/ja/getting-started.ja.md`)
  — install, first run, keeping usage history complete (Login Items / CLI
  daemon), data locations, and troubleshooting. Linked from the READMEs.

## [0.1.0] - 2026-07-05

### Added
- Project scaffold: SwiftPM app (macOS 14+, `LSUIElement` menu-bar agent),
  Makefile (`build` / `build-app` / `package` / `test`), Developer ID
  signing + notarization scripts (mirrors quick-translate), MIT license, docs.
- Menu-bar item showing today's usage, with a **configurable display**
  (price `$12.34` / total tokens `277M` / two-line "both"), live + timer-refreshed.
  Chosen in the popover, persisted via `@AppStorage`.
- Popover: today's cost, input/output/cache tokens, 30-day projection.
- Analysis window (Swift Charts), 7/30/90-day period, controls in the toolbar,
  responsive layout:
  - Daily trend — **contiguous series** (empty days as `$0`, via the CLI's
    `--dense`), a **Cost / Tokens** metric toggle, **thinned** MM-DD x-labels on
    long ranges, and a cursor-following **hover tooltip**.
  - **By-model stacking** (optional) — each day split into per-model segments,
    ordered by total (largest first), empty days preserved by joining onto the
    dense day axis, with a per-day breakdown hover tooltip.
  - Per-model and top-project bars — plotted by the full key so same-named
    projects aren't collapsed/summed; labels disambiguated (`parent/name`).
- `CLIRunner` — locate and invoke the `claude-usage-lens` CLI, decode its
  `report --json` / `--summary --json` output (with decode tests).
- `make build-app` embeds the CLI binary into the `.app` (self-contained).

### Notes
- Native SwiftUI (not Wails, per the CLI's RFP) — a menu-bar-resident app is
  cleaner with `MenuBarExtra`/`NSStatusItem`. macOS-only.
- Requires `claude-usage-lens` with `report --dense` (contiguous daily series).

[Unreleased]: https://github.com/nlink-jp/claude-usage-lens-gui/compare/v0.2.1...HEAD
[0.3.2]: https://github.com/nlink-jp/claude-usage-lens-gui/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/nlink-jp/claude-usage-lens-gui/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/nlink-jp/claude-usage-lens-gui/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/nlink-jp/claude-usage-lens-gui/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/nlink-jp/claude-usage-lens-gui/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/nlink-jp/claude-usage-lens-gui/compare/v0.1.9...v0.2.0
[0.1.9]: https://github.com/nlink-jp/claude-usage-lens-gui/compare/v0.1.8...v0.1.9
[0.1.8]: https://github.com/nlink-jp/claude-usage-lens-gui/compare/v0.1.7...v0.1.8
[0.1.7]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.7
[0.1.6]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.6
[0.1.5]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.5
[0.1.4]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.4
[0.1.3]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.3
[0.1.2]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.2
[0.1.1]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.1
[0.1.0]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.0
