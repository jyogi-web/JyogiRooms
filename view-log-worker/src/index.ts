import type { Env } from "./types.js";
import { isAuthorized } from "./auth.js";
import { parseViewLogEvent } from "./schema.js";
import { shouldRecord } from "./throttle.js";
import { insertViewLog } from "./insert.js";
import { getStats } from "./stats.js";

function clampInt(value: string | null, fallback: number, min: number, max: number): number {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.floor(n)));
}

function json(status: number, data: object): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // 疎通確認
    if (request.method === "GET" && url.pathname === "/health") {
      return new Response("OK", { status: 200 });
    }

    // 閲覧ログ取り込み
    if (request.method === "POST" && url.pathname === "/view-logs") {
      // 1. 認可（共有シークレット）
      if (!isAuthorized(request, env.INGEST_SHARED_SECRET)) {
        return json(401, { error: "unauthorized" });
      }

      // 2. パース＆検証
      let body: unknown;
      try {
        body = await request.json();
      } catch {
        return json(400, { error: "invalid JSON" });
      }
      const parsed = parseViewLogEvent(body);
      if (!parsed.ok) {
        return json(422, { error: parsed.error });
      }

      // 3. throttle（5分窓の重複を間引く）
      const record = await shouldRecord(env, parsed.event);
      if (!record) {
        return json(200, { recorded: false, reason: "throttled" });
      }

      // 4. D1 へ追記
      try {
        await insertViewLog(env, parsed.event);
      } catch (error) {
        console.error("insertViewLog failed:", error);
        return json(500, { error: "failed to persist view log" });
      }

      return json(201, { recorded: true });
    }

    // 集計取得（Rails 管理画面 / 開発者確認用）
    if (request.method === "GET" && url.pathname === "/view-logs/stats") {
      if (!isAuthorized(request, env.INGEST_SHARED_SECRET)) {
        return json(401, { error: "unauthorized" });
      }
      const days = clampInt(url.searchParams.get("days"), 30, 1, 365);
      const recentLimit = clampInt(url.searchParams.get("limit"), 50, 1, 500);
      try {
        const stats = await getStats(env, { days, recentLimit });
        return json(200, stats);
      } catch (error) {
        console.error("getStats failed:", error);
        return json(500, { error: "failed to load stats" });
      }
    }

    return new Response("Not Found", { status: 404 });
  },
};
