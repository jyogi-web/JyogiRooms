# Jyogi Rooms Discord Bot

Jyogi Rooms の Discord 連携ボット。部室予約の確認・作成、部室状況・鍵持ちの確認、利用統計の表示を提供する。

## アーキテクチャ

**HTTP Interactions 方式**を採用。Discord Gateway（WebSocket 常時接続）は使わず、Discord からの HTTP POST リクエストを受け取ってレスポンスを返す。

```
Discord → POST /interactions → worker.ts → commands/* → JSON レスポンス
```

Cloudflare Workers 上で動作する（`wrangler.toml` の `main = "src/worker.ts"`）。常駐プロセスを持たないため、リクエストがないときはコストがかからない。

## 機能

### スラッシュコマンド

| コマンド | 説明 |
|---|---|
| `/list` | 今後の予約一覧を表示（最大10件） |
| `/check` | 指定日の予約を確認。`preset`（今日/明日）または `date`（MM/DD 等）で指定 |
| `/reserve` | 予約を新規作成。`date`, `start`, `end`, `purpose`（任意）を指定 |
| `/status` | 部室の状況を確認 |
| `/key` | 各部室の鍵持ち一覧を表示 |
| `/call` | 指定した部室の鍵持ちをメンションして通知 |
| `/me` | 自分の部室利用統計を表示 |
| `/rank` | 部室の訪問日数・滞在時間ランキングを表示 |
| `/help` | コマンドの使い方を表示 |

部室の開室・閉室・入室・退室は Discord コマンドでは行わず、WebアプリまたはNFCで処理します。

施錠アナウンスは Rails 側（`LockAnnounceJob`）から送信しており、この Bot には含まれません。

### ヘルスチェック

`GET /health` → `200 OK` を返す。

## セットアップ

### 1. 依存インストール

```bash
cd discord-bot
npm install
```

### 2. 環境変数・シークレットの設定

Worker が使う値は以下のとおり。本番では `API_BASE_URL` は `wrangler.toml` の `[vars]`、それ以外は Cloudflare の Secret として設定する。

```bash
npx wrangler secret put DISCORD_PUBLIC_KEY
```

| 変数名 | 必須 | 設定先 | 説明 |
|---|---|---|---|
| `DISCORD_PUBLIC_KEY` | Yes | Secret | Discord Application の Public Key（署名検証用） |
| `DISCORD_CLIENT_ID` | Yes | Secret | Discord Application ID（応答が遅いときのフォローアップ送信に使用） |
| `API_ACCESS_TOKEN` | Yes | Secret | Rails API の認証トークン |
| `API_BASE_URL` | Yes | `wrangler.toml` | Rails API の URL（例: `https://rooms.jyogi.net/api`） |
| `INGEST_SHARED_SECRET` | No | Secret | 閲覧ログ Worker（`view-log-worker`）との共有シークレット。同じ値を両方に設定する |

閲覧ログ Worker へは `wrangler.toml` の Service Binding（`VIEW_LOG`）で接続する。`VIEW_LOG` と `INGEST_SHARED_SECRET` のどちらかが未設定の場合、閲覧ログの記録は行われない。

スラッシュコマンドの登録（`npm run deploy-commands`）には、`.env` に以下を設定する。

| 変数名 | 説明 |
|---|---|
| `DISCORD_BOT_TOKEN` | Discord Bot トークン |
| `DISCORD_CLIENT_ID` | Discord Application ID |

`DISCORD_BOT_TOKEN`, `DISCORD_CLIENT_ID`, `DISCORD_PUBLIC_KEY` は [Discord Developer Portal](https://discord.com/developers/applications) の対象アプリケーションから取得する。

### 3. スラッシュコマンドの登録

Discord にコマンド定義を登録する。初回およびコマンド定義変更時に実行が必要。

```bash
npm run deploy-commands
```

### 4. Interactions Endpoint URL の設定

Discord Developer Portal > 対象アプリケーション > General Information で **Interactions Endpoint URL** を設定する。

```
https://<デプロイ先ドメイン>/interactions
```

Discord が URL に対して PING を送信し、署名検証を含めた疎通確認を行う。成功すると設定が保存される。

## 開発

### 開発サーバー起動

```bash
npm run dev    # wrangler dev（デフォルト: http://localhost:8787）
```

ローカル実行時のシークレットは `.dev.vars`（なければ `.env`）から読み込まれる。

Discord からの HTTP リクエストを受け取るには [ngrok](https://ngrok.com/) 等のトンネルツールが必要。

```bash
ngrok http 8787
```

表示された URL を Discord Developer Portal の Interactions Endpoint URL に設定する。

### 型チェック

```bash
npm run build    # Worker 用の TypeScript をコンパイル（dist/）
```

### デプロイ

develop・main ブランチへの Push（`discord-bot/` 配下の変更時）で、GitHub Actions（`deploy-discord-bot.yml`）が `wrangler deploy` を実行する。手動でデプロイする場合は以下。

```bash
npm run deploy
```

## ディレクトリ構成

```
discord-bot/
├── src/
│   ├── worker.ts             # Workers エントリーポイント（/interactions, /health）
│   ├── api.ts                # Rails API クライアント
│   ├── viewLog.ts            # 閲覧ログ Worker への送信クライアント
│   ├── constants.ts          # 共通定数
│   ├── deploy-commands.ts    # スラッシュコマンド登録スクリプト
│   └── commands/
│       ├── index.ts          # コマンド一覧
│       ├── types.ts          # 型定義
│       ├── utils.ts          # オプション取得・日付処理・レスポンス生成などの共通処理
│       └── [コマンド名].ts     # 各コマンド実装
├── package.json
├── tsconfig.json             # 共通設定
├── tsconfig.worker.json      # Worker 用（npm run build）
├── tsconfig.deploy.json      # deploy-commands 用
├── wrangler.toml
└── .env.example
```

## リクエストフロー

1. ユーザーが Discord でスラッシュコマンドを実行
2. Discord が `POST /interactions` にリクエストを送信
3. `worker.ts` が署名を検証（`discord-interactions`）
4. コマンドに応じたハンドラーを実行（`commands/*.ts`）
5. Rails API と通信して予約・鍵・部室状態データを取得
6. JSON レスポンスを Discord に返却（2.5秒以内に終わらない場合は Deferred レスポンスを返し、完了後にフォローアップでメッセージを更新）
7. Discord がユーザーにメッセージを表示
