# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Project scaffold: SwiftPM app (macOS 14+, `LSUIElement` menu-bar agent),
  Makefile (`build` / `build-app` / `package` / `test`), Developer ID
  signing + notarization scripts (mirrors quick-translate), MIT license, docs.
- Menu-bar item showing today's cost (live, timer-refreshed).
- Popover: today's cost, input/output/cache tokens, 30-day projection.
- Analysis window: daily cost trend, per-model and top-project charts
  (Swift Charts), over a 7/30/90-day period.
- `CLIRunner` — locate and invoke the `claude-usage-lens` CLI, decode its
  `report --json` / `--summary --json` output (with a decode test).
- `make build-app` embeds the CLI binary into the `.app` (self-contained).

### Notes
- Native SwiftUI (not Wails, per the CLI's RFP) — a menu-bar-resident app is
  cleaner with `MenuBarExtra`/`NSStatusItem`. macOS-only.

[Unreleased]: https://github.com/nlink-jp/claude-usage-lens-gui
