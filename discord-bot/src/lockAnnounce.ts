import cron from "node-cron";
import { Client, TextChannel } from "discord.js";

const CRON_EXPRESSION =
  process.env.LOCK_ANNOUNCE_CRON || "0 11 * * *";// Note: デフォルトで日本時間20:00を設定する

if (!cron.validate(CRON_EXPRESSION)) {
  console.error(`❌ 無効なcron式です: ${CRON_EXPRESSION}`);
  process.exit(1);
}

const CHANNEL_ID = process.env.ANNOUNCE_CHANNEL_ID;

let task: cron.ScheduledTask | null = null;

export function startLockAnnounceCron(client: Client) {
  if (!CHANNEL_ID) {
    console.error("❌ ANNOUNCE_CHANNEL_ID is not set");
    return;
  }

  if (task) {
    console.log("⚠️ 施錠アナウンス cron は既に起動しています");
    return;
  }

  task = cron.schedule(CRON_EXPRESSION, async () => {
    try {
      const channel = await client.channels.fetch(CHANNEL_ID);

      if (!channel || !channel.isTextBased()) {
        console.error("❌ チャンネルが見つからない or Text ではありません");
        return;
      }

      const now = new Date().toLocaleString("ja-JP", {
        timeZone: "Asia/Tokyo",
      });

      await (channel as TextChannel).send(
        `🔒 **施錠のお知らせ**\n\n部室の施錠時間です!\n鍵持ちの部員は各部室が施錠されているか確認をお願いします。`
      );

      console.log("✅ 施錠アナウンスを送信しました");
    } catch (err) {
      console.error("❌ 施錠アナウンス送信失敗:", err);
    }
  });

  console.log(
    `🕰️ 施錠アナウンス cron を開始しました (${CRON_EXPRESSION} UTC / 20:00 JST)`
  );
}

export function stopLockAnnounceCron() {
  if (task) {
    task.stop();
    task = null;
    console.log("🛑 施錠アナウンス cron を停止しました");
  }
}
