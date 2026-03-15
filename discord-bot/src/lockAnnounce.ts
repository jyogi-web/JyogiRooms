import cron from "node-cron";
import { REST, Routes } from "discord.js";

const CRON_EXPRESSION =
  process.env.LOCK_ANNOUNCE_CRON || "0 20 * * *"; // 日本時間20:00（TZ=Asia/Tokyo前提）

const CHANNEL_ID = process.env.ANNOUNCE_CHANNEL_ID;
const BOT_TOKEN = process.env.DISCORD_BOT_TOKEN;

let task: cron.ScheduledTask | null = null;

export function startLockAnnounceCron() {
  if (!cron.validate(CRON_EXPRESSION)) {
    console.error(`❌ 無効なcron式です: ${CRON_EXPRESSION}`);
    process.exit(1);
  }

  if (!CHANNEL_ID) {
    console.error("❌ ANNOUNCE_CHANNEL_ID is not set");
    return;
  }

  if (!BOT_TOKEN) {
    console.error("❌ DISCORD_BOT_TOKEN is not set (required for announcements)");
    return;
  }

  if (task) {
    console.log("⚠️ 施錠アナウンス cron は既に起動しています");
    return;
  }

  const rest = new REST({ version: '10' }).setToken(BOT_TOKEN);

  task = cron.schedule(CRON_EXPRESSION, async () => {
    try {
      await rest.post(Routes.channelMessages(CHANNEL_ID), {
        body: {
          // TODO: ハッカソン終了後に元のメッセージに戻す
          // content: `🔒 **施錠のお知らせ**\n\n部室の施錠時間です!\n鍵持ちの部員は各部室が施錠されているか確認をお願いします。`,
          content: `💪 **ハッカソン応援メッセージ**\n\nハッカソン参加の皆さん、お疲れ様です！\n本日は泊まり込み日ですね。夜遅くまで頑張っていると思いますが、適度に休憩も取ってくださいね。\n最高のプロダクトを作り上げましょう！🔥`,
        },
      });

      console.log("✅ 施錠アナウンスを送信しました");
    } catch (err) {
      console.error("❌ 施錠アナウンス送信失敗:", err);
    }
  });

  console.log(
    `🕰️ 施錠アナウンス cron を開始しました (${CRON_EXPRESSION} JST)`
  );
}

export function stopLockAnnounceCron() {
  if (task) {
    task.stop();
    task = null;
    console.log("🛑 施錠アナウンス cron を停止しました");
  }
}
