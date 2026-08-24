import { describe, it, expect } from "vitest";
import { parseViewLogEvent } from "../src/schema.js";
import { throttleKey, throttleTtlSeconds } from "../src/throttle.js";
import { isAuthorized } from "../src/auth.js";
import type { Env } from "../src/types.js";

describe("parseViewLogEvent", () => {
  it("accepts a valid web event", () => {
    const r = parseViewLogEvent({ source: "web", user_id: 12, viewed_at: "2026-08-24T01:00:00Z" });
    expect(r.ok).toBe(true);
    if (r.ok) {
      expect(r.event.user_id).toBe(12);
      expect(r.event.discord_id).toBeNull();
      expect(r.event.viewed_at).toBe("2026-08-24T01:00:00.000Z");
    }
  });

  it("accepts a valid discord event", () => {
    const r = parseViewLogEvent({ source: "discord", discord_id: "999", viewed_at: "2026-08-24T01:00:00Z" });
    expect(r.ok).toBe(true);
    if (r.ok) {
      expect(r.event.discord_id).toBe("999");
      expect(r.event.user_id).toBeNull();
    }
  });

  it("coerces numeric user_id string", () => {
    const r = parseViewLogEvent({ source: "web", user_id: "7", viewed_at: "2026-08-24T01:00:00Z" });
    expect(r.ok).toBe(true);
    if (r.ok) expect(r.event.user_id).toBe(7);
  });

  it("rejects unknown source", () => {
    const r = parseViewLogEvent({ source: "api", user_id: 1, viewed_at: "2026-08-24T01:00:00Z" });
    expect(r.ok).toBe(false);
  });

  it("rejects web without user_id", () => {
    const r = parseViewLogEvent({ source: "web", viewed_at: "2026-08-24T01:00:00Z" });
    expect(r.ok).toBe(false);
  });

  it("rejects discord without discord_id", () => {
    const r = parseViewLogEvent({ source: "discord", viewed_at: "2026-08-24T01:00:00Z" });
    expect(r.ok).toBe(false);
  });

  it("rejects invalid viewed_at", () => {
    const r = parseViewLogEvent({ source: "web", user_id: 1, viewed_at: "not-a-date" });
    expect(r.ok).toBe(false);
  });

  it("rejects non-positive user_id", () => {
    const r = parseViewLogEvent({ source: "web", user_id: 0, viewed_at: "2026-08-24T01:00:00Z" });
    expect(r.ok).toBe(false);
  });
});

describe("throttleKey", () => {
  it("keys web by user_id", () => {
    expect(throttleKey({ source: "web", user_id: 5, discord_id: null, viewed_at: "x" })).toBe(
      "throttle:web:u:5"
    );
  });
  it("keys discord by discord_id", () => {
    expect(throttleKey({ source: "discord", user_id: null, discord_id: "42", viewed_at: "x" })).toBe(
      "throttle:discord:d:42"
    );
  });
});

describe("throttleTtlSeconds", () => {
  it("uses env value when valid", () => {
    expect(throttleTtlSeconds({ THROTTLE_TTL_SECONDS: "600" } as Env)).toBe(600);
  });
  it("falls back to 300 when missing/invalid", () => {
    expect(throttleTtlSeconds({} as Env)).toBe(300);
    expect(throttleTtlSeconds({ THROTTLE_TTL_SECONDS: "abc" } as Env)).toBe(300);
  });
});

describe("isAuthorized", () => {
  const make = (header?: string) =>
    new Request("https://x/view-logs", {
      method: "POST",
      headers: header === undefined ? {} : { "X-Ingest-Secret": header },
    });

  it("accepts matching secret", () => {
    expect(isAuthorized(make("s3cret"), "s3cret")).toBe(true);
  });
  it("rejects wrong secret", () => {
    expect(isAuthorized(make("nope"), "s3cret")).toBe(false);
  });
  it("rejects missing header", () => {
    expect(isAuthorized(make(undefined), "s3cret")).toBe(false);
  });
  it("rejects when server secret unset", () => {
    expect(isAuthorized(make("anything"), undefined)).toBe(false);
  });
});
