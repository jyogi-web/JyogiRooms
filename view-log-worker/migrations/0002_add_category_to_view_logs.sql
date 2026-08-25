-- 閲覧対象のカテゴリを追加（既存行はすべて部室状況として扱う）
-- 値: 'room_status'（部室状況） | 'ranking'（ランキング） | 'stats'（自分の統計）
ALTER TABLE view_logs ADD COLUMN category TEXT NOT NULL DEFAULT 'room_status';

CREATE INDEX IF NOT EXISTS idx_view_logs_category_viewed ON view_logs (category, viewed_at);
