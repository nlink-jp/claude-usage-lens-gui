# Getting Started — claude-usage-lens-gui

A macOS menu-bar app that shows **today's Claude usage cost** and expands into
graphical analysis. It's a native front-end over the
[`claude-usage-lens`](https://github.com/nlink-jp/claude-usage-lens) CLI, which
is **bundled inside the app** — there's nothing else to install.

Everything runs locally: it reads your own Claude Code / Cowork session logs and
never uploads anything. Costs are an API **list-price equivalent (notional)**,
not an actual bill.

## Requirements

- macOS 14 (Sonoma) or later, Apple silicon (arm64).
- You've used Claude Code and/or Claude Cowork, so local session logs exist.

## Install

1. Download `ClaudeUsageLens-vX.Y.Z-macos-arm64.zip` from the
   [latest release](https://github.com/nlink-jp/claude-usage-lens-gui/releases/latest).
2. Unzip it and move **`ClaudeUsageLens.app`** to `/Applications`.
3. Double-click to open. The app is Developer ID signed **and notarized**, so it
   opens without a security warning.
   - If a freshly downloaded copy is still blocked, right-click the app →
     **Open** once, or clear the quarantine flag:
     ```sh
     xattr -dr com.apple.quarantine /Applications/ClaudeUsageLens.app
     ```
4. It's a **menu-bar app** (no Dock icon). Look for the cost in your menu bar.

## First run

- On launch it ingests your logs and shows **today's cost** in the menu bar
  (give the first ingest a moment).
- **Click** the menu-bar item for the popover: today's cost, input/output/cache
  tokens, a 30-day projection, and a **Menu bar** display picker
  (**Price** `$12.34` / **Tokens** `277M` / **Both**, two lines).
- **Analysis…** opens the charts window (7 / 30 / 90 days):
  - Daily trend with a **Cost / Tokens** toggle, a gap-free series (empty days
    show as `$0`), and a **hover tooltip** for per-day detail.
  - Optional **By model** stacking (each day split by model), and **Top
    projects**.

## Keep your usage history complete

The app ingests only **while it is running** (every 60 seconds). Claude Code
auto-deletes old session logs, so anything never ingested is lost. Pick one:

- **Run it at login (simplest):** System Settings → General → **Login Items** →
  add `ClaudeUsageLens.app`. It will quietly keep today's numbers up to date.
- **24/7 background ingest via the CLI (power users):** install the
  [`claude-usage-lens`](https://github.com/nlink-jp/claude-usage-lens) CLI
  separately and register its launchd service, so accumulation continues even
  when the app is closed:
  ```sh
  claude-usage-lens daemon install     # status | uninstall
  ```

Both write to the same durable store, so the GUI shows whatever has been
ingested.

## Where your data lives

| | Path |
|---|---|
| Reads (Claude Code) | `~/.claude/projects/**` |
| Reads (Cowork) | `~/Library/Application Support/Claude/local-agent-mode-sessions/**` |
| Stores | `~/Library/Application Support/claude-usage-lens/usage.db` |

Nothing leaves your machine. Costs are notional (API list-price equivalent).

## Troubleshooting

- **Menu bar shows `—`:** the CLI couldn't run or found no data. Make sure you've
  actually used Claude Code / Cowork; open the popover to see the error. You can
  force a specific CLI binary with the `CLAUDE_USAGE_LENS_BIN` environment
  variable.
- **Two cost items in the menu bar:** a second copy is running — quit one
  (menu → **Quit**).
- **You want the raw numbers or automation:** use the CLI directly, e.g.
  `claude-usage-lens report --since 7d --group-by day` — see the
  [CLI README](https://github.com/nlink-jp/claude-usage-lens).

## Uninstall

1. Quit the app (menu → **Quit**) and delete `/Applications/ClaudeUsageLens.app`.
2. To also remove stored data: delete
   `~/Library/Application Support/claude-usage-lens/`.
3. If you installed the CLI daemon: `claude-usage-lens daemon uninstall`.
