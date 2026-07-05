# claude-usage-lens-gui

A macOS menu-bar app that shows **today's Claude usage cost** at a glance and
expands into graphical analysis. It's a thin native front-end over the
[`claude-usage-lens`](https://github.com/nlink-jp/claude-usage-lens) CLI — the
CLI does all parsing/pricing/aggregation and this app renders it.

> **Status: WIP (scaffold + MVP).** Menu-bar cost, today's popover, and the
> analysis window (daily / model / project charts) work. macOS 14+ only.

## What it does

- **Menu bar**: live "today's cost" (e.g. `$12.34`), refreshed on a timer.
- **Popover** (click the menu bar item): today's cost, input/output/cache tokens,
  and a 30-day projection.
- **Analysis window**: daily cost trend, per-model and top-project breakdowns
  (Swift Charts), over a selectable 7/30/90-day period.

Costs follow the CLI's model: Cowork is exact (from its audit log), Claude Code
is an API list-price-equivalent estimate. See the CLI's README.

## Requirements

The `claude-usage-lens` CLI. The app finds it in this order:
1. `$CLAUDE_USAGE_LENS_BIN`
2. bundled inside the `.app` (Contents/Resources — `make build-app` embeds it)
3. `/usr/local/bin`, `/opt/homebrew/bin`, or the sibling `claude-usage-lens/dist/`

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
