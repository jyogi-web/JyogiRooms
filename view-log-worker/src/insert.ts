import type { Env, ViewLogEvent } from "./types.js";

// 閲覧ログを D1 に1行追記する。
export async function insertViewLog(env: Env, event: ViewLogEvent): Promise<void> {
  await env.VIEW_LOGS_DB.prepare(
    `INSERT INTO view_logs (user_id, discord_id, source, viewed_at)
     VALUES (?, ?, ?, ?)`
  )
    .bind(event.user_id, event.discord_id, event.source, event.viewed_at)
    .run();
}
