import type { Env, ViewLogEvent } from "./types.js";
import { DEFAULT_THROTTLE_TTL_SECONDS } from "./types.js";

// throttle キー: カテゴリ + 経路 + 識別子 単位。
// カテゴリを含めるので、同一ユーザーが5分内にランキングと統計を見た場合は別々に記録される。
export function throttleKey(event: ViewLogEvent): string {
  const identity = event.source === "web" ? `u:${event.user_id}` : `d:${event.discord_id}`;
  return `throttle:${event.category}:${event.source}:${identity}`;
}

export function throttleTtlSeconds(env: Env): number {
  const parsed = Number(env.THROTTLE_TTL_SECONDS);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : DEFAULT_THROTTLE_TTL_SECONDS;
}

// throttle 窓内に既に記録済みか判定する（読み取りのみ）。
// KV 読み取り失敗時は fail-open（未記録扱い＝記録側に倒す）。
//   → ごく稀に重複が1件通るが、イベントを欠落させない方を優先する。
export async function isThrottled(env: Env, event: ViewLogEvent): Promise<boolean> {
  const key = throttleKey(event);
  try {
    const existing = await env.THROTTLE_KV.get(key);
    return existing !== null;
  } catch (error) {
    console.error("throttle KV read error (fail-open, will record):", error);
    return false;
  }
}

// throttle 窓を張る。D1 保存が成功した後にのみ呼ぶこと。
// 保存失敗時に窓を消費しないことで、再試行が間引かれてイベントを取りこぼすのを防ぐ。
// KV 書き込み失敗は fail-open（ログのみ・記録自体は成功扱いのまま。
// 同一キー1秒1回制限に触れても記録を失敗させない）。
export async function markRecorded(env: Env, event: ViewLogEvent): Promise<void> {
  const key = throttleKey(event);
  try {
    await env.THROTTLE_KV.put(key, "1", { expirationTtl: throttleTtlSeconds(env) });
  } catch (error) {
    console.error("throttle KV write error (ignored):", error);
  }
}
