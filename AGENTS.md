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
make test       # swift test
```

## Structure

```
Sources/ClaudeUsageLens/
  App.swift         @main; MenuBarExtra live label (tinted by weekly state) +
                    Window("analysis") + Window("settings")
  UsageModel.swift  ObservableObject; timer → ingest + summary; loadAnalysis();
                    weekly-budget compute + notifications
  CLIRunner.swift   locate + run the CLI, decode JSON
  Models.swift      Codable Summary / Row (match the CLI's report JSON)
  MenuBarMode.swift menu-bar display mode (price/tokens/both/weekly)
  WeeklyLimit.swift pure lastReset/state helpers + LimitBasis/LimitState/WeeklyStatus
  Settings.swift    UserDefaults keys/defaults + WeeklySettings snapshot
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
- **Weekly monitor**: settings live in UserDefaults (`Settings.swift` keys +
  `WeeklySettings` snapshot; `SettingsView` binds the same keys via @AppStorage).
  `UsageModel` caches the raw weekly usage (cost + in+out tokens) so limit / basis
  / threshold changes rebuild the status **instantly with no CLI call**
  (`applyWeeklySettings`); only reset day/time re-queries (`refreshWeekly`, using
  the CLI's datetime `--since`). Notifications fire only from the periodic refresh
  on an upward severity crossing, gated by the "Show notifications" setting — never
  while tuning settings.
- **Settings/analysis windows, not the Settings scene**: a menu-bar (LSUIElement)
  app can't reliably focus the `Settings` scene / `SettingsLink`, so both open as
  plain `Window`s via `openWindow(id:)` + `NSApp.activate(ignoringOtherApps:)`.
- **Signing**: `--deep` signs the bundled CLI too. Pure SwiftUI/AppKit needs no
  entitlements (Hardened Runtime alone). Notarize + staple the `.app`.
- **Native, not Wails**: deliberate deviation from the CLI's RFP — a menu-bar
  app is cleaner native. macOS-only; a cross-platform GUI would be a separate
  Wails project.

## Design reference

- The CLI: https://github.com/nlink-jp/claude-usage-lens
