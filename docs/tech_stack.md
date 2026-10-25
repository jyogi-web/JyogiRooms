# 技術選定

## バックエンド

| 技術 | バージョン | 選定理由 |
|------|-----------|---------|
| Ruby | 3.4.12 | 最新安定版 |
| Ruby on Rails | 8.1 | フルスタックWebフレームワーク、Solid Queue/Cache/Cable による外部ミドルウェア不要の構成 |
| Puma | 7.x | Rails標準のWebサーバー |
| PostgreSQL | - | JSONB対応（room_statusの非正規化に活用）、堅牢なRDB |

## フロントエンド

| 技術 | 選定理由 |
|------|---------|
| ERB | Rails標準テンプレート、SPA不要のサーバーサイドレンダリング |
| Tailwind CSS 4.x | ユーティリティファーストCSS、迅速なUI構築 |
| Propshaft | Rails 8標準のアセットパイプライン |
| ViewComponent | UIコンポーネントの再利用（アバター等） |

## Discord Bot

| 技術 | バージョン | 選定理由 |
|------|-----------|---------|
| Node.js | 22 | 非同期I/O、Discord SDK対応 |
| TypeScript | 5.9 | 型安全性 |
| discord.js | 14.x | Discord APIクライアント |
| discord-interactions | 4.x | HTTP Interactionsモード（Gateway不要、軽量） |

## インフラ・デプロイ

| 技術 | 用途 |
|------|------|
| Raspberry Pi（自己ホスト） | Railsアプリのデプロイ先 |
| Cloudflare Workers | Discord Bot・閲覧ログWorkerのデプロイ先（サーバーレス） |
| Cloudflare Tunnel | ラズパイへの外部公開（HTTPS自動、ドメイン: `jyogi-rooms.jyogi.net`） |
| Docker / Docker Compose | コンテナ化・ラズパイ上でのオーケストレーション |
| GitHub Actions | CI/CD（テスト・lint・デプロイ自動化） |

## CI/CD パイプライン

| ワークフロー | トリガー | 内容 |
|-------------|---------|------|
| `ci.yml` | PR / develop・mainへのPush | Brakeman, Bundler-audit, RuboCop, Minitest, システムテスト |
| `deploy-discord-bot.yml` | develop・mainへのPush（`discord-bot/`配下の変更時） | `wrangler deploy`でCloudflare Workersにデプロイ |
| `deploy-raspi.yml` | develop・mainへのPush（`discord-bot/`配下以外の変更時） | ラズパイ上でdocker-composeビルド・起動 |
| `deploy-view-log-worker.yml` | develop・mainへのPush（`view-log-worker/`配下またはワークフロー自体の変更時） | `wrangler deploy`でCloudflare Workersにデプロイ |

## セキュリティ・品質ツール

| ツール | 用途 |
|--------|------|
| Brakeman | Rails静的セキュリティスキャン |
| Bundler-audit | gem脆弱性検査 |
| RuboCop | コードスタイル・品質チェック |
