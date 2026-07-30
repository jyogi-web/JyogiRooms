# Jyogi Rooms Discord Bot

Jyogi Rooms の Discord 連携ボット。部室予約の確認・作成と施錠アナウンスを提供する。

## アーキテクチャ

**HTTP Interactions 方式**を採用。Discord Gateway（WebSocket 常時接続）は使わず、Discord からの HTTP POST リクエストを受け取ってレスポンスを返す。

```
Discord → POST /interactions → server.ts → commands/* → JSON レスポンス
```

これにより Cloud Run 等のサーバーレス環境でスケール to 0 が可能になり、コストを抑えられる。

## 機能

### スラッシュコマンド

| コマンド | 説明 |
|---|---|
| `/list` | 今後の予約一覧を表示（最大10件） |
| `/check` | 指定日の予約を確認。`preset`（今日/明日）または `date`（MM/DD 等）で指定 |
| `/reserve` | 予約を新規作成。`date`, `start`, `end`, `purpose`（任意）を指定 |
| `/key` | 各部室の鍵持ち一覧を表示 |
| `/call` | 指定した部室の鍵持ちをメンションして通知 |
| `/status` | 部室の状況を確認 |

部室の開室・閉室・入室・退室は Discord コマンドでは行わず、WebアプリまたはNFCで処理します。

### 施錠アナウンス（cron）

`LOCK_ANNOUNCE_CRON` で指定した時刻に、`ANNOUNCE_CHANNEL_ID` のチャンネルへ施錠リマインドを送信する。Discord REST API を使用するため Gateway 接続不要。

### ヘルスチェック

`GET /health` → `200 OK` を返す。Cloud Run のヘルスチェック用。

## セットアップ

### 1. 依存インストール

```bash
cd discord-bot
npm install
```

### 2. 環境変数の設定

`.env.example` をコピーして `.env` を作成し、各値を設定する。

```bash
cp .env.example .env
```

| 変数名 | 必須 | 説明 |
|---|---|---|
| `DISCORD_BOT_TOKEN` | Yes | Discord Bot トークン |
| `DISCORD_CLIENT_ID` | Yes | Discord Application ID（コマンドデプロイ時に使用） |
| `DISCORD_PUBLIC_KEY` | Yes | Discord Application の Public Key（署名検証用） |
| `ANNOUNCE_CHANNEL_ID` | No | 施錠アナウンスを送信するチャンネル ID |
| `LOCK_ANNOUNCE_CRON` | No | 施錠アナウンスの cron 式（デフォルト: `0 11 * * *` UTC = 20:00 JST） |
| `API_ACCESS_TOKEN` | Yes | Rails API の認証トークン |
| `API_BASE_URL` | Yes | Rails API の URL（例: `https://jyogi-rooms.jyogi.net/api`） |
| `PORT` | No | HTTP サーバーのポート（デフォルト: `3000`） |

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
npm run dev
```

ローカルで開発する場合、Discord からの HTTP リクエストを受け取るために [ngrok](https://ngrok.com/) 等のトンネルツールが必要。

```bash
ngrok http 3000
```

表示された URL を Discord Developer Portal の Interactions Endpoint URL に設定する。

### ビルド

```bash
npm run build    # TypeScript → JavaScript（dist/）
npm start        # ビルド後に実行
```

## ディレクトリ構成

```
discord-bot/
├── src/
│   ├── index.ts              # エントリーポイント（サーバー起動 + cron 開始）
│   ├── server.ts             # HTTP サーバー（/interactions, /health）
│   ├── api.ts                # Rails API クライアント
│   ├── lockAnnounce.ts       # 施錠アナウンス cron（REST API 使用）
│   ├── deploy-commands.ts    # スラッシュコマンド登録スクリプト
│   └── commands/
│       ├── index.ts          # コマンド一覧
│       └── [コマンド名].ts         # 各コマンド実装
├── dist/                     # ビルド出力
├── package.json
├── tsconfig.json
└── .env.example
```

## リクエストフロー

1. ユーザーが Discord でスラッシュコマンドを実行
2. Discord が `POST /interactions` にリクエストを送信
3. `server.ts` が署名を検証（`discord-interactions`）
4. コマンドに応じたハンドラーを実行（`commands/*.ts`）
5. Rails API と通信して予約・鍵・部室状態データを取得
6. JSON レスポンスを Discord に返却
7. Discord がユーザーにメッセージを表示
