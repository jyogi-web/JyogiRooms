import cron from "node-cron";

const PORT = Number(process.env.PORT) || 3000;
const HEALTH_CHECK_URL = process.env.HEALTH_CHECK_URL || `http://localhost:${PORT}`;

// 10分ごとにヘルスチェックを実行
export function startHealthCheckCron() {
  cron.schedule("*/10 * * * *", async () => {
    try {
      const now = new Date().toLocaleString('ja-JP');
      console.log(`🔍 [${now}] ヘルスチェック実行中... (${HEALTH_CHECK_URL})`);
      const response = await fetch(HEALTH_CHECK_URL);
    } catch (error) {
      console.error('ヘルスチェックエラ:', error);
    }
  });

  console.log("🕐 ヘルスチェックの定期実行を開始しました (10分間隔)");
}