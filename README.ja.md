# claude-usage-lens-gui

**本日の Claude 利用コスト**をメニューバーに常駐表示し、展開するとグラフィカルな
分析ができる macOS アプリ。[`claude-usage-lens`](https://github.com/nlink-jp/claude-usage-lens)
CLI の薄いネイティブフロントエンドで、解析・単価・集計はすべて CLI が担当します。

macOS 14+（Apple シリコン）専用。リリース済み — Developer ID 署名 + notarize 済み。

> **はじめての方は [セットアップガイド](docs/ja/getting-started.ja.md)**
> ([English](docs/en/getting-started.md)) を参照 — インストール・初回起動・
> 利用履歴を欠けさせないコツ。

## 機能

- **メニューバー**: 本日のコスト（例 `$12.34`）をライブ表示。表示は切替可能
  （price / tokens / 2段組み / 週次残量）
- **ポップオーバー**（クリック）: 本日のコスト、input/output/cache トークン、
  直近30日合計、週次バジェットバー（有効時）
- **分析ウィンドウ**: 期間合計＋日次推移・モデル別・プロジェクト別（Swift Charts）を
  7/30/90日で切替、ホバー詳細・モデル別積み上げ対応
- **週次バジェットモニタ**（任意）: 週の使用量を **コスト($) / トークン(in+out)** 基準で
  追跡し、**2段階**（警告/危険）しきい値で監視。近づくとメニューバーの数値が橙/赤に変色し、
  ポップオーバーに色付きの使用/上限バーが出て、（任意で）**通知**。設定は ⌘, /
  ポップオーバーの "Settings…"。
- **実リミットへの校正**（任意）: Claude の実際の利用枠はサーバー側にありログからは
  読めませんが、**校正**できます。Claude Code で `/usage` を実行し、公式の週次消費率と
  リセット時刻を Settings → Calibration に入力すると、**実効上限**を導出します
  （CLI の `calibrate`/`limits` 経由 — 非公開 API は使いません）。校正済みの間は
  週次バーに緑の **calibrated** バッジが付き、公式のリセット周期に追随します。
  未校正時は従来どおり**自分で設定したバジェット**（**assumed** バッジ）に
  フォールバック。公式の%とアプリの推定がずれてきたら、またプラン変更・
  プロモーション時に再校正してください。

コストは CLI のモデルに従います（Cowork は audit から厳密、Claude Code は API 定価換算の
近似）。日付はローカルタイムゾーン基準。詳細は CLI の README を参照。

## 必要要件

`claude-usage-lens` CLI — **`.app` に同梱**されるためリリースビルドは自己完結します。
次の順で解決します:
1. 同梱コピー（`Contents/Resources` — Developer ID 署名 + notarize 済み＝信頼の基点。
   `make build-app` が埋め込む）
2. `/usr/local/bin`, `/opt/homebrew/bin`（未同梱時のフォールバック）

**DEBUG ビルドのみ**、`$CLAUDE_USAGE_LENS_BIN` オーバーライドと兄弟の
`claude-usage-lens/dist/` 開発パスも参照します。リリースビルドは env 変数を無視するため、
署名済み同梱バイナリから実行先を逸らされることはありません。

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
