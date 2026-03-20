import { REST, Routes } from "discord.js";

const CHANNEL_ID = process.env.ANNOUNCE_CHANNEL_ID;
const BOT_TOKEN = process.env.DISCORD_BOT_TOKEN;

if (!BOT_TOKEN || !CHANNEL_ID) {
  console.warn('⚠️ ANNOUNCE_CHANNEL_IDまたはDISCORD_BOT_TOKENが未設定のため通知は無効です');
}

let rest: REST | null = null;

function getRest(): REST | null {
  if (!BOT_TOKEN || !CHANNEL_ID) return null;
  if (!rest) {
    rest = new REST({ version: '10' }).setToken(BOT_TOKEN);
  }
  return rest;
}

interface NotificationPayload {
  type: string;
  data: Record<string, any>;
}

function formatUserMention(discordId?: string, displayName?: string): string {
  if (discordId) return `<@${discordId}>`;
  return displayName || '不明なユーザー';
}

function formatDateTime(startAt: string, endAt: string): string {
  const start = new Date(startAt);
  const end = new Date(endAt);
  const dateStr = start.toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric', weekday: 'short' });
  const startTime = start.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
  const endTime = end.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
  return `${dateStr} ${startTime} ~ ${endTime}`;
}

function buildReservationMessage(type: string, data: Record<string, any>): object {
  const user = formatUserMention(data.user_discord_id, data.user_display_name);
  const dateTime = formatDateTime(data.start_at, data.end_at);
  const purpose = data.purpose || 'なし';

  const labels: Record<string, { title: string; color: number }> = {
    reservation_created: { title: '📅 予約が作成されました', color: 0x00cc66 },
    reservation_updated: { title: '📝 予約が更新されました', color: 0xff9900 },
    reservation_destroyed: { title: '🗑️ 予約が削除されました', color: 0xff3333 },
  };
  const { title, color } = labels[type] || { title: '📅 予約通知', color: 0x0099ff };

  const description = `${user} の予約\n📅 ${dateTime}\n📝 ${purpose}`;

  // 鍵持ちへのメンションはcontent（通常テキスト）に出すことで通知を届ける
  let content: string | undefined;
  const keyHolders: { discord_id?: string; display_name?: string }[] = data.key_holders || [];
  const holders = keyHolders.filter(h => h.discord_id);
  if (holders.length > 0 && type === 'reservation_created') {
    const mentions = holders.map(h => `<@${h.discord_id}>`).join(' ');
    content = `🔑 ${mentions}\n上記の日時に部室を開けられる方はリアクションをお願いします！`;
  }

  return {
    ...(content ? { content } : {}),
    embeds: [{
      title,
      description,
      color,
      timestamp: new Date().toISOString(),
    }],
  };
}

function buildKeyMessage(type: string, data: Record<string, any>): object {
  const roomName = `${data.room_name}（${data.room_number}）`;

  const labels: Record<string, { title: string; color: number }> = {
    key_transferred: { title: '🔑 鍵が譲渡されました', color: 0x0099ff },
    key_assigned: { title: '🔑 鍵が割り当てられました', color: 0x00cc66 },
    key_unassigned: { title: '🔑 鍵の割り当てが解除されました', color: 0xff9900 },
  };
  const { title, color } = labels[type] || { title: '🔑 鍵通知', color: 0x0099ff };

  let description = `🚪 ${roomName}\n`;

  if (type === 'key_transferred') {
    const from = formatUserMention(data.from_user_discord_id, data.from_user_display_name);
    const to = formatUserMention(data.to_user_discord_id, data.to_user_display_name);
    description += `${from} → ${to}`;
  } else if (type === 'key_assigned') {
    const to = formatUserMention(data.to_user_discord_id, data.to_user_display_name);
    description += `${to} に割り当て`;
  } else if (type === 'key_unassigned') {
    const from = formatUserMention(data.from_user_discord_id, data.from_user_display_name);
    description += `${from} の割り当てを解除`;
  }

  return {
    embeds: [{
      title,
      description,
      color,
      timestamp: new Date().toISOString(),
    }],
  };
}

export async function handleNotification(payload: NotificationPayload): Promise<void> {
  const client = getRest();
  if (!client || !CHANNEL_ID) {
    throw new Error('通知送信不可: BOT_TOKENまたはCHANNEL_IDが未設定');
  }

  let message: object;

  if (payload.type.startsWith('reservation_')) {
    message = buildReservationMessage(payload.type, payload.data);
  } else if (payload.type.startsWith('key_')) {
    message = buildKeyMessage(payload.type, payload.data);
  } else {
    throw new Error(`不明な通知タイプ: ${payload.type}`);
  }

  try {
    await client.post(Routes.channelMessages(CHANNEL_ID), { body: message });
    console.log(`✅ 通知を送信しました: ${payload.type}`);
  } catch (err) {
    console.error(`❌ 通知送信失敗 (${payload.type}):`, err);
    throw err;
  }
}
