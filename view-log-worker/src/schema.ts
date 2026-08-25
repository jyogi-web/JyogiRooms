import type { ViewLogEvent, ViewSource, ViewCategory } from "./types.js";

export type ParseResult =
  | { ok: true; event: ViewLogEvent }
  | { ok: false; error: string };

const VALID_SOURCES: ViewSource[] = ["web", "discord"];
const VALID_CATEGORIES: ViewCategory[] = ["room_status", "ranking", "stats"];

// 受信 JSON を検証して ViewLogEvent に正規化する。
export function parseViewLogEvent(body: unknown): ParseResult {
  if (typeof body !== "object" || body === null) {
    return { ok: false, error: "body must be a JSON object" };
  }
  const raw = body as Record<string, unknown>;

  const source = raw.source;
  if (typeof source !== "string" || !VALID_SOURCES.includes(source as ViewSource)) {
    return { ok: false, error: "source must be 'web' or 'discord'" };
  }

  const viewedAt = raw.viewed_at;
  if (typeof viewedAt !== "string" || Number.isNaN(Date.parse(viewedAt))) {
    return { ok: false, error: "viewed_at must be a valid ISO8601 string" };
  }

  // category: 未指定は後方互換で "room_status"
  let category: ViewCategory = "room_status";
  if (raw.category !== undefined && raw.category !== null) {
    if (typeof raw.category !== "string" || !VALID_CATEGORIES.includes(raw.category as ViewCategory)) {
      return { ok: false, error: "category must be one of room_status, ranking, stats" };
    }
    category = raw.category as ViewCategory;
  }

  // user_id: 数値 or 数値文字列 or 未指定
  let userId: number | null = null;
  if (raw.user_id !== undefined && raw.user_id !== null) {
    const n = typeof raw.user_id === "string" ? Number(raw.user_id) : raw.user_id;
    if (typeof n !== "number" || !Number.isInteger(n) || n <= 0) {
      return { ok: false, error: "user_id must be a positive integer" };
    }
    userId = n;
  }

  // discord_id: 文字列 or 未指定
  let discordId: string | null = null;
  if (raw.discord_id !== undefined && raw.discord_id !== null) {
    if (typeof raw.discord_id !== "string" || raw.discord_id.length === 0) {
      return { ok: false, error: "discord_id must be a non-empty string" };
    }
    discordId = raw.discord_id;
  }

  // 「誰が」を必ず1つは持つ
  if (userId === null && discordId === null) {
    return { ok: false, error: "either user_id or discord_id is required" };
  }

  // 経路と識別子の整合性
  if (source === "web" && userId === null) {
    return { ok: false, error: "web source requires user_id" };
  }
  if (source === "discord" && discordId === null) {
    return { ok: false, error: "discord source requires discord_id" };
  }

  return {
    ok: true,
    event: {
      source: source as ViewSource,
      category,
      viewed_at: new Date(viewedAt).toISOString(), // UTC 正規化
      user_id: userId,
      discord_id: discordId,
    },
  };
}
