# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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

[Unreleased]: https://github.com/nlink-jp/claude-usage-lens-gui/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.1
[0.1.0]: https://github.com/nlink-jp/claude-usage-lens-gui/releases/tag/v0.1.0
