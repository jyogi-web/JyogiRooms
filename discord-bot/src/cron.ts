import cron from "node-cron";

const PORT = Number(process.env.PORT) || 3000;
const HEALTH_CHECK_URL = process.env.HEALTH_CHECK_URL || `http://localhost:${PORT}/health`;

let healthCheckTask: cron.ScheduledTask | null = null;

// 10分ごとにヘルスチェックを実行
export function startHealthCheckCron() {
  if (healthCheckTask) {
    console.log("⚠️ ヘルスチェックのcronは既に実行中です");
    return;
  }

  healthCheckTask = cron.schedule("*/10 * * * *", async () => {
    try {
      const now = new Date().toLocaleString('ja-JP');
      console.log(`🔍 [${now}] ヘルスチェック実行中... (${HEALTH_CHECK_URL})`);
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000); // 5秒のタイムアウト
      try {
        const response = await fetch(HEALTH_CHECK_URL, { signal: controller.signal });
        clearTimeout(timeoutId);
        if (!response.ok) {
          console.error(`❌ ヘルスチェック失敗: ステータス ${response.status}`);
        } else {
          console.log(`✅ ヘルスチェック成功: ステータス ${response.status}`);
        }
      } catch (fetchError) {
        clearTimeout(timeoutId);
        if (fetchError instanceof Error && fetchError.name === 'AbortError') {
          console.error('❌ ヘルスチェックタイムアウト');
        } else {
          throw fetchError;
        }
      }
    } catch (error) {
      console.error('❌ ヘルスチェックエラー:', error);
    }
  });

  console.log("🕐 ヘルスチェックの定期実行を開始しました (10分間隔)");
}

export function stopHealthCheckCron() {
  if (healthCheckTask) {
    healthCheckTask.stop();
    healthCheckTask = null;
    console.log("🛑 ヘルスチェックのcronを停止しました");
  }
}