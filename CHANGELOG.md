# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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

[Unreleased]: https://github.com/nlink-jp/claude-usage-lens-gui/compare/v0.1.6...HEAD
[0.1.6]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.6
[0.1.5]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.5
[0.1.4]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.4
[0.1.3]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.3
[0.1.2]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.2
[0.1.1]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.1
[0.1.0]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.0
