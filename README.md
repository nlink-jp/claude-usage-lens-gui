# claude-usage-lens-gui

A macOS menu-bar app that shows **today's Claude usage cost** at a glance and
expands into graphical analysis. It's a thin native front-end over the
[`claude-usage-lens`](https://github.com/nlink-jp/claude-usage-lens) CLI — the
CLI does all parsing/pricing/aggregation and this app renders it.

macOS 14+ (Apple silicon). Released — signed with Developer ID and notarized.

> **New here? See the [Getting Started guide](docs/en/getting-started.md)**
> ([日本語](docs/ja/getting-started.ja.md)) — install, first run, and keeping
> your usage history complete.

## What it does

- **Menu bar**: live "today's cost" (e.g. `$12.34`), refreshed on a timer.
  Display is configurable (price / tokens / two-line / weekly-remaining — the
  weekly mode shows the amount left *and* its share of the budget, `$116 · 58%`).
- **Popover** (click the menu bar item): today's cost, input/output/cache tokens,
  the last-30-days total, and the weekly-budget bar (when enabled).
- **Version**: the running build's version is printed in the popover footer
  (selectable) — a menu-bar app has no `--version` to run.
- **Analysis window**: period total plus daily trend, per-model and top-project
  breakdowns (Swift Charts), over a selectable 7/30/90-day period, with hover
  detail and optional per-model stacking.
- **Weekly budget monitor** (optional): tracks the week's usage by **cost ($)**
  or **tokens (in+out)** with **two-tier** warning / critical thresholds. As you
  approach the limit the menu-bar number turns orange/red, the popover shows a
  colored used/limit bar, and (optionally) a **notification** fires. Settings
  via ⌘, / "Settings…" in the popover. Both sides of the split are given in
  amount **and** percent (`68% used · $1,200.00 left (32%)`).
- **Will I run out?** The popover also projects where the week lands at the pace
  so far — `On pace for $5,200.00 (137%) — budget gone Sat 14:26` — spreading
  what you've spent over the elapsed slice of the window and extrapolating to
  the reset. The line is tinted by the *projection's* severity, so a week that
  is still inside its thresholds but heading over the limit shows up before the
  usage bar does. In the first ~8 hours of a window one session would dominate
  the average, so it says `Too early this week to project a pace` instead of
  printing a wild number.
- **Calibrated to the real limit** (optional): Claude's actual quota lives
  server-side and can't be read from logs, but you can **calibrate**: run
  `/usage` in Claude Code, type the official weekly percentage and its reset
  time into Settings → Calibration, and the app derives the **real effective
  cap** (via the CLI's `calibrate`/`limits` — no private API involved). The
  weekly bar then shows a green **calibrated** badge and follows the official
  reset cadence; without a calibration it falls back to your **assumed** budget
  (with a matching badge). Re-calibrate occasionally — anytime the official
  percentage drifts from the app's estimate, or after plan/promo changes.

Costs follow the CLI's model: Cowork is exact (from its audit log), Claude Code
is an API list-price-equivalent estimate. All dates use your local timezone.
See the CLI's README.

The app is single-instance: starting a second copy (for example, a
notification click resolving to a different copy of the .app) logs to
stderr and exits, leaving the running instance alone.

## Requirements

The `claude-usage-lens` CLI — **bundled inside the `.app`**, so a release build is
self-contained. It's resolved in this order:
1. the bundled copy in `Contents/Resources` (Developer-ID signed + notarized — the
   trust anchor; `make build-app` embeds it)
2. `/usr/local/bin`, `/opt/homebrew/bin` (fallback if not bundled)

In **DEBUG builds only**, a `$CLAUDE_USAGE_LENS_BIN` override and the sibling
`claude-usage-lens/dist/` dev path are also honored. Release builds ignore the
env var so it can't redirect execution away from the signed bundle.

## Build

```sh
make run                 # build + run (debug)
make build               # release binary → .build/release/
make build-app           # signed .app bundle → dist/ (embeds the CLI)
make package             # build-app + notarize + staple + zip (release)
make test
```

`make build-app` bundles the CLI from `CLI_BIN` (default `../claude-usage-lens/dist/claude-usage-lens`);
override it: `make build-app CLI_BIN=/path/to/claude-usage-lens`.

## Why Swift (not Wails)

The RFP proposed a Wails GUI. A **menu-bar-resident** app with a live cost label
is far cleaner with native `NSStatusItem`/`MenuBarExtra` than Wails' systray, so
this is a native SwiftUI app (matching `quick-translate`), talking to the CLI via
its stable `--json` output. Cross-platform GUI, if ever needed, remains a
separate Wails option.

## License

MIT — see [LICENSE](LICENSE).
