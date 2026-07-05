# CLAUDE.md — claude-usage-lens-gui

**Organization rules (mandatory): https://github.com/nlink-jp/.github/blob/main/CONVENTIONS.md**

## Project overview

macOS menu-bar app that surfaces today's Claude usage cost and expands into
graphical analysis. Native SwiftUI front-end over the `claude-usage-lens` CLI
(the CLI does parsing/pricing/aggregation; this app invokes it via `--json` and
renders with Swift Charts). `LSUIElement` menu-bar agent, macOS 14+.

## Non-negotiable rules

- **Tests are mandatory** — write them with the implementation
- **Never build ad-hoc** — use `make build` / `make build-app`
- **Docs in sync** — update `README.md` and `README.ja.md` together
- **Small, typed commits** — `feat:`, `fix:`, `test:`, `chore:`, `docs:`, etc.
- **No secrets / PII committed** — the app reads local usage via the CLI only

## Build & test

```sh
make run          # swift run (debug)
make build-app    # signed .app (embeds the CLI)
make package      # notarized + stapled + zipped .app
make test
```

## Key decisions

- **Native SwiftUI, not Wails** (deviation from the CLI's RFP): a menu-bar-
  resident app with a live cost label is far cleaner with `MenuBarExtra` /
  `NSStatusItem` than Wails' systray. macOS-only; matches `quick-translate`'s
  signed/notarized SwiftPM `.app` pipeline.
- **Data via the CLI's `--json`**, not a reimplementation: the CLI is the single
  source of truth; this stays a thin renderer. `Models.swift` tracks the CLI's
  report JSON schema.
- **Self-contained `.app`**: `make build-app` bundles the CLI binary into
  Resources (signed via `--deep`).

## Architecture

- `App.swift` — `@main`, `MenuBarExtra(.window)` live label + analysis `Window`
- `UsageModel` — timer-driven `ingest` + today summary; on-demand analysis load
- `CLIRunner` — locate + run the CLI, decode JSON
- `Models` — `Summary` / `Row` Codable (match report `--json`)
- `PopoverView` / `AnalysisView` — the popover and the charts window

## Design references

- CLI (data backend + cost model): https://github.com/nlink-jp/claude-usage-lens
