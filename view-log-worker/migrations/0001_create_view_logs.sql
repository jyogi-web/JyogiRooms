-- 部室状況の閲覧ログ（追記型・時系列）
-- 粒度: 閲覧セッション1回 = 1行（room_id は持たない）
-- 「誰が」: web は user_id(Rails users.id) / discord は discord_id を格納する。
--          少なくとも一方は必ず入る（Worker 側で検証）。
CREATE TABLE IF NOT EXISTS view_logs (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER,                  -- Rails users.id（web 経路）
  discord_id TEXT,                     -- Discord ユーザーID（discord 経路）
  source     TEXT    NOT NULL,         -- 'web' | 'discord'
  viewed_at  TEXT    NOT NULL,         -- 閲覧時刻（呼び出し元採番・UTC ISO8601）
  created_at TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))  -- D1 挿入時刻
);

-- 分析クエリ用インデックス
CREATE INDEX IF NOT EXISTS idx_view_logs_viewed_at        ON view_logs (viewed_at);
CREATE INDEX IF NOT EXISTS idx_view_logs_user_viewed      ON view_logs (user_id, viewed_at);
CREATE INDEX IF NOT EXISTS idx_view_logs_discord_viewed   ON view_logs (discord_id, viewed_at);
CREATE INDEX IF NOT EXISTS idx_view_logs_source_viewed    ON view_logs (source, viewed_at);
