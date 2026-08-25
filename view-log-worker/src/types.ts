/// <reference types="@cloudflare/workers-types" />

export interface Env {
  // D1: 閲覧ログ本体（永続）
  VIEW_LOGS_DB: D1Database;
  // KV: throttle 窓（TTL 自動失効）
  THROTTLE_KV: KVNamespace;
  // Rails / bot からの呼び出しを認可する共有シークレット（wrangler secret put）
  INGEST_SHARED_SECRET: string;
  // throttle 窓（秒）。未設定時は 300（5分）。
  THROTTLE_TTL_SECONDS?: string;
}

export type ViewSource = "web" | "discord";

// 閲覧対象のカテゴリ
export type ViewCategory = "room_status" | "ranking" | "stats";

// 取り込みエンドポイントが受け取る閲覧イベント
export interface ViewLogEvent {
  source: ViewSource;
  category: ViewCategory;
  viewed_at: string; // UTC ISO8601
  user_id: number | null; // Rails users.id（web）
  discord_id: string | null; // Discord ユーザーID（discord）
}

export const DEFAULT_THROTTLE_TTL_SECONDS = 300;
