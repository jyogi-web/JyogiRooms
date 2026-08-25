import type { Env } from "./types.js";

export interface StatsResponse {
  total: number;
  by_source: { source: string; count: number }[];
  by_category: { category: string; count: number }[];
  by_day: { day: string; count: number }[];
  recent: {
    id: number;
    user_id: number | null;
    discord_id: string | null;
    source: string;
    category: string;
    viewed_at: string;
  }[];
}

function sinceIso(days: number): string {
  return new Date(Date.now() - days * 86_400_000).toISOString();
}

// 閲覧ログの集計を返す（Rails 管理画面 / 開発者確認用）。
// category を渡すとそのカテゴリに絞って集計する（by_category は常に全体を返し、
// 管理画面でカテゴリを切り替えられるようにする）。
export async function getStats(
  env: Env,
  opts: { days: number; recentLimit: number; category?: string }
): Promise<StatsResponse> {
  const db = env.VIEW_LOGS_DB;
  const cat = opts.category;
  // category 絞り込み用の WHERE 句とバインド値
  const catWhere = cat ? "category = ?" : "";
  const catBind = cat ? [cat] : [];

  const totalRow = await db
    .prepare(`SELECT COUNT(*) AS c FROM view_logs${cat ? " WHERE category = ?" : ""}`)
    .bind(...catBind)
    .first<{ c: number }>();

  const bySource = await db
    .prepare(
      `SELECT source, COUNT(*) AS count FROM view_logs${cat ? " WHERE category = ?" : ""}
       GROUP BY source ORDER BY count DESC`
    )
    .bind(...catBind)
    .all<{ source: string; count: number }>();

  // カテゴリ別は常に全体（絞り込みなし）で集計＝サマリーカードで全カテゴリを提示
  const byCategory = await db
    .prepare(
      "SELECT category, COUNT(*) AS count FROM view_logs GROUP BY category ORDER BY count DESC"
    )
    .all<{ category: string; count: number }>();

  const byDay = await db
    .prepare(
      `SELECT substr(viewed_at, 1, 10) AS day, COUNT(*) AS count
       FROM view_logs
       WHERE viewed_at >= ?${catWhere ? ` AND ${catWhere}` : ""}
       GROUP BY day
       ORDER BY day DESC`
    )
    .bind(sinceIso(opts.days), ...catBind)
    .all<{ day: string; count: number }>();

  const recent = await db
    .prepare(
      `SELECT id, user_id, discord_id, source, category, viewed_at
       FROM view_logs${cat ? " WHERE category = ?" : ""}
       ORDER BY viewed_at DESC, id DESC
       LIMIT ?`
    )
    .bind(...catBind, opts.recentLimit)
    .all<StatsResponse["recent"][number]>();

  return {
    total: totalRow?.c ?? 0,
    by_source: bySource.results ?? [],
    by_category: byCategory.results ?? [],
    by_day: byDay.results ?? [],
    recent: recent.results ?? [],
  };
}
