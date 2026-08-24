import type { Env, ViewLogEvent } from "./types.js";
import { DEFAULT_THROTTLE_TTL_SECONDS } from "./types.js";

// throttle キー: 経路 + 識別子 単位。
// web は user_id、discord は discord_id で区別する。
export function throttleKey(event: ViewLogEvent): string {
  const identity = event.source === "web" ? `u:${event.user_id}` : `d:${event.discord_id}`;
  return `throttle:${event.source}:${identity}`;
}

export function throttleTtlSeconds(env: Env): number {
  const parsed = Number(env.THROTTLE_TTL_SECONDS);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : DEFAULT_THROTTLE_TTL_SECONDS;
}

// 記録すべきか判定する。
// - throttle 窓内に既に記録済み → false（間引く）
// - 新規 → キーをセット（TTL）して true
//
// KV の get→put は厳密にはアトミックでなく、また同一キーへの書き込みは
// 約1秒に1回の制限がある。読み取りが一時的に stale だと put が失敗し得るため、
// エラー時は fail-open（記録側に倒す）とする。
//   → ごく稀に重複が1件通るが、イベントを欠落させない方を優先する。
export async function shouldRecord(env: Env, event: ViewLogEvent): Promise<boolean> {
  const key = throttleKey(event);
  try {
    const existing = await env.THROTTLE_KV.get(key);
    if (existing !== null) return false;

    await env.THROTTLE_KV.put(key, "1", { expirationTtl: throttleTtlSeconds(env) });
    return true;
  } catch (error) {
    console.error("throttle KV error (fail-open, will record):", error);
    return true;
  }
}
