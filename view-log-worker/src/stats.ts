import type { Env } from "./types.js";

export interface StatsResponse {
  total: number;
  by_source: { source: string; count: number }[];
  by_day: { day: string; count: number }[];
  recent: {
    id: number;
    user_id: number | null;
    discord_id: string | null;
    source: string;
    viewed_at: string;
  }[];
}

function sinceIso(days: number): string {
  return new Date(Date.now() - days * 86_400_000).toISOString();
}

// 閲覧ログの集計を返す（Rails 管理画面 / 開発者確認用）。
// Rails 側で user_id / discord_id を display_name に解決して表示する。
export async function getStats(
  env: Env,
  opts: { days: number; recentLimit: number }
): Promise<StatsResponse> {
  const db = env.VIEW_LOGS_DB;

  const totalRow = await db
    .prepare("SELECT COUNT(*) AS c FROM view_logs")
    .first<{ c: number }>();

  const bySource = await db
    .prepare(
      "SELECT source, COUNT(*) AS count FROM view_logs GROUP BY source ORDER BY count DESC"
    )
    .all<{ source: string; count: number }>();

  const byDay = await db
    .prepare(
      `SELECT substr(viewed_at, 1, 10) AS day, COUNT(*) AS count
       FROM view_logs
       WHERE viewed_at >= ?
       GROUP BY day
       ORDER BY day DESC`
    )
    .bind(sinceIso(opts.days))
    .all<{ day: string; count: number }>();

  const recent = await db
    .prepare(
      `SELECT id, user_id, discord_id, source, viewed_at
       FROM view_logs
       ORDER BY viewed_at DESC, id DESC
       LIMIT ?`
    )
    .bind(opts.recentLimit)
    .all<StatsResponse["recent"][number]>();

  return {
    total: totalRow?.c ?? 0,
    by_source: bySource.results ?? [],
    by_day: byDay.results ?? [],
    recent: recent.results ?? [],
  };
}
