# セットアップガイド — claude-usage-lens-gui

**本日の Claude 利用コスト**をメニューバーに表示し、展開するとグラフィカルに分析
できる macOS アプリです。[`claude-usage-lens`](https://github.com/nlink-jp/claude-usage-lens)
CLI のネイティブフロントエンドで、**CLI はアプリに同梱**されているため他に
インストールするものはありません。

すべてローカルで動作します。自分の Claude Code / Cowork のセッションログを読むだけで、
外部には一切送信しません。コストは API **定価換算（notional）** であり、実際の請求額
ではありません。

## 必要要件

- macOS 14 (Sonoma) 以降、Apple シリコン (arm64)
- Claude Code / Claude Cowork を使用済みで、ローカルセッションログが存在すること

## インストール

1. [最新リリース](https://github.com/nlink-jp/claude-usage-lens-gui/releases/latest)
   から `claude-usage-lens-gui-vX.Y.Z-darwin-arm64.zip` をダウンロード
2. 解凍し、**`ClaudeUsageLens.app`** を `/Applications` へ移動
3. ダブルクリックで起動。Developer ID 署名 **+ notarize 済み**なので、セキュリティ
   警告なしで開きます
   - ダウンロード直後にブロックされる場合は、右クリック → **開く** を一度実行するか、
     quarantine 属性を外してください:
     ```sh
     xattr -dr com.apple.quarantine /Applications/ClaudeUsageLens.app
     ```
4. **メニューバー常駐アプリ**です（Dock アイコンなし）。メニューバーにコストが出ます

## 初回起動

- 起動するとログを取り込み、メニューバーに**本日のコスト**を表示します（初回取り込みに
  少し時間がかかります）
- メニューバーの項目を**クリック**するとポップオーバー: 本日のコスト、input/output/cache
  トークン、30日換算、そして**メニューバー表示切替**
  （**Price** `$12.34` / **Tokens** `277M` / **Both**（2段組み））
- **Analysis…** でチャートウィンドウ（7 / 30 / 90 日）:
  - 日次推移（**Cost / Tokens** 切替、計上ゼロの日も `$0` で連続表示、**ホバー**で
    その日の詳細）
  - **By model**（日ごとにモデル別積み上げ）、**Top projects**

## 利用履歴を欠けさせないために

アプリは**起動中のみ**（60秒ごと）取り込みます。Claude Code は古いセッションログを
自動削除するため、一度も取り込まれなかった分は失われます。次のいずれかを推奨:

- **ログイン時に自動起動（最も簡単）:** システム設定 → 一般 → **ログイン項目** に
  `ClaudeUsageLens.app` を追加。常に本日の数値が最新に保たれます
- **CLI で 24/7 バックグラウンド取り込み（上級者）:**
  [`claude-usage-lens`](https://github.com/nlink-jp/claude-usage-lens) CLI を別途
  インストールし、launchd サービスを登録すると、アプリを閉じていても蓄積が続きます:
  ```sh
  claude-usage-lens daemon install     # status | uninstall
  ```

どちらも同じ永続ストアに書き込むので、GUI は取り込み済みの内容を表示します。

## データの保存場所

| | パス |
|---|---|
| 読み取り (Claude Code) | `~/.claude/projects/**` |
| 読み取り (Cowork) | `~/Library/Application Support/Claude/local-agent-mode-sessions/**` |
| 保存 | `~/Library/Application Support/claude-usage-lens/usage.db` |

外部送信は一切ありません。コストは notional（API 定価換算）です。

## トラブルシューティング

- **メニューバーが `—`:** CLI を実行できないか、データが見つからない状態です。Claude
  Code / Cowork を実際に使用済みか確認し、ポップオーバーでエラーを確認してください。
  CLI はアプリに同梱されています。万一見つからない場合はアプリを再インストールするか、
  `claude-usage-lens` を `PATH` に配置してください
- **メニューバーにコスト項目が2つ:** 二重起動です。片方を終了（メニュー → **Quit**）
- **生の数値や自動化が欲しい:** CLI を直接使用（例
  `claude-usage-lens report --since 7d --group-by day`）。詳細は
  [CLI README](https://github.com/nlink-jp/claude-usage-lens)

## アンインストール

1. アプリを終了（メニュー → **Quit**）し、`/Applications/ClaudeUsageLens.app` を削除
2. 保存データも消す場合: `~/Library/Application Support/claude-usage-lens/` を削除
3. CLI daemon を入れていた場合: `claude-usage-lens daemon uninstall`
