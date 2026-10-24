# view-log-worker

「閲覧ログ」を取り込む Cloudflare Worker。カテゴリ（部室状況 `room_status` / ランキング `ranking` / 自分の統計 `stats` / アプリ全体アクセス `app`）ごとに、誰がいつ見たかを記録する。

- **D1 (`VIEW_LOGS_DB`)** … 閲覧ログ本体（永続・分析対象）。Neon の容量・稼働を消費しない。
- **KV (`THROTTLE_KV`)** … throttle 窓（同一ユーザー・同一カテゴリの5分以内の重複を間引く。TTL で自動失効）。

Web(Rails) と Discord(bot) の両経路が、この Worker の `POST /view-logs` に集約して書き込む。

## エンドポイント

### `POST /view-logs`
ヘッダ `X-Ingest-Secret: <INGEST_SHARED_SECRET>` 必須。

ボディ（JSON）:
```jsonc
// web 経路
{ "source": "web", "category": "ranking", "user_id": 123, "viewed_at": "2026-08-24T01:23:45Z" }
// discord 経路
{ "source": "discord", "category": "stats", "discord_id": "1122334455", "viewed_at": "2026-08-24T01:23:45Z" }
```
- `category` … `room_status`（部室状況） / `ranking`（ランキング） / `stats`（自分の統計） / `app`（アプリ全体アクセス・Rails から画面種別なしで送られる）。省略時は `room_status`。
  throttle(5分)は **カテゴリ別** に効く。

レスポンス:
- `201 { "recorded": true }` … D1 に追記した
- `200 { "recorded": false, "reason": "throttled" }` … 5分窓内なので間引いた
- `401 / 422 / 500` … 認可失敗 / 検証エラー / 保存失敗

### `GET /view-logs/stats`
集計取得（Rails 管理画面 / 開発者確認用）。ヘッダ `X-Ingest-Secret: <INGEST_SHARED_SECRET>` 必須。

クエリパラメータ:
- `days` … 日別集計の対象日数。範囲 `1〜365`、既定 `30`（範囲外・未指定・空は既定）
- `limit` … 最近の閲覧の取得件数。範囲 `1〜500`、既定 `50`
- `category` … `room_status` / `ranking` / `stats` / `app` で絞り込み（未指定は全体）。
  絞り込み時も `by_category` は常に全体を返す（管理画面のカテゴリ切替用）。

レスポンス `200`:
```jsonc
{
  "total": 1234,
  "by_source":   [{ "source": "web", "count": 1000 }, { "source": "discord", "count": 234 }],
  "by_category": [{ "category": "room_status", "count": 900 }, { "category": "ranking", "count": 234 }, { "category": "stats", "count": 100 }],
  "by_day":      [{ "day": "2026-08-24", "count": 42 }],   // viewed_at 基準・降順
  "recent":      [{ "id": 9, "user_id": 123, "discord_id": null, "source": "web", "category": "ranking", "viewed_at": "2026-08-24T01:23:45.000Z" }]
}
```
- `401 / 500` … 認可失敗 / 集計失敗

### `GET /health`
`200 OK`。

## セットアップ（★本番リソース作成前に Cloudflare アカウントを確認すること）

```bash
cd view-log-worker
npm install

# どのアカウントを使うか確認してからログインする
wrangler whoami
# 必要なら: wrangler login   （複数アカウントなら CLOUDFLARE_ACCOUNT_ID を明示）

# 1) D1 作成 → 出力された database_id を wrangler.toml に記入
wrangler d1 create jyogi-view-logs

# 2) KV 作成 → 出力された id を wrangler.toml に記入
wrangler kv namespace create THROTTLE_KV

# 3) マイグレーション適用
npm run migrate:remote     # 本番
# npm run migrate:local    # ローカル(dev)

# 4) 共有シークレット設定（Rails / bot と同じ値）
wrangler secret put INGEST_SHARED_SECRET

# 5) デプロイ
npm run deploy
```

## 開発

```bash
npm run typecheck
npm test          # 純粋ロジック（検証 / throttleキー / 認可）のユニットテスト
npm run dev       # ローカル起動（--local の D1/KV を使用）
```

## 分析クエリ例

```sql
-- 日別の閲覧数
SELECT substr(viewed_at, 1, 10) AS day, COUNT(*) AS views
FROM view_logs GROUP BY day ORDER BY day DESC;

-- ユーザー別（web）の閲覧回数
SELECT user_id, COUNT(*) AS views
FROM view_logs WHERE source = 'web'
GROUP BY user_id ORDER BY views DESC;
```
