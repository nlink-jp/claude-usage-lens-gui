# claude-usage-lens-gui

**本日の Claude 利用コスト**をメニューバーに常駐表示し、展開するとグラフィカルな
分析ができる macOS アプリ。[`claude-usage-lens`](https://github.com/nlink-jp/claude-usage-lens)
CLI の薄いネイティブフロントエンドで、解析・単価・集計はすべて CLI が担当します。

macOS 14+（Apple シリコン）専用。リリース済み — Developer ID 署名 + notarize 済み。

> **はじめての方は [セットアップガイド](docs/ja/getting-started.ja.md)**
> ([English](docs/en/getting-started.md)) を参照 — インストール・初回起動・
> 利用履歴を欠けさせないコツ。

## 機能

- **メニューバー**: 本日のコスト（例 `$12.34`）をライブ表示（タイマー更新）
- **ポップオーバー**（クリック）: 本日のコスト、input/output/cache トークン、30日換算
- **分析ウィンドウ**: 日次コスト推移・モデル別・プロジェクト別（Swift Charts）を
  7/30/90日で切替

コストは CLI のモデルに従います（Cowork は audit から厳密、Claude Code は API 定価換算の
近似）。詳細は CLI の README を参照。

## 必要要件

`claude-usage-lens` CLI。アプリは次の順で探索します:
1. `$CLAUDE_USAGE_LENS_BIN`
2. `.app` 内に同梱（Contents/Resources — `make build-app` が埋め込む）
3. `/usr/local/bin`, `/opt/homebrew/bin`, 兄弟の `claude-usage-lens/dist/`

## ビルド

```sh
make run                 # ビルド+実行（デバッグ）
make build               # release バイナリ → .build/release/
make build-app           # 署名済み .app → dist/（CLI 同梱）
make package             # build-app + notarize + staple + zip（リリース）
make test
```

`make build-app` は `CLI_BIN`（既定 `../claude-usage-lens/dist/claude-usage-lens`）から CLI を同梱。
上書き: `make build-app CLI_BIN=/path/to/claude-usage-lens`。

## なぜ Swift（Wails ではなく）

RFP は Wails GUI を想定していましたが、「**メニューバー常駐 + ライブコスト表示**」は
Wails の systray よりネイティブ `NSStatusItem`/`MenuBarExtra` が圧倒的に綺麗なため、
ネイティブ SwiftUI アプリ（quick-translate と同系統）とし、CLI の安定した `--json` 出力を
利用します。将来クロスPF GUI が要れば Wails を別途検討。

## ライセンス

MIT — [LICENSE](LICENSE) 参照。
