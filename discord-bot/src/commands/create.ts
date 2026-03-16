import { SlashCommandBuilder } from 'discord.js';
import { api, ApiError } from '../api.js';
import type { Interaction } from './types.js';
import { getStringOption, getUserId, parseDateInput, reply, replyEmbed } from './utils.js';
import { handleNotification } from '../notifier.js';

export const createCommand = {
    data: new SlashCommandBuilder()
        .setName('create')
        .setDescription('予約を新規作成します')
        .addStringOption(option =>
            option.setName('date')
                .setDescription('日付 (例: 12/25, 2026/01/01, today)')
                .setRequired(true))
        .addStringOption(option =>
            option.setName('start')
                .setDescription('開始時刻 (例: 10:00)')
                .setRequired(true))
        .addStringOption(option =>
            option.setName('end')
                .setDescription('終了時刻 (例: 12:00)')
                .setRequired(true))
        .addStringOption(option =>
            option.setName('purpose')
                .setDescription('利用目的 (任意)')
                .setRequired(false)),

    async execute(interaction: Interaction): Promise<object> {
        const dateInput = getStringOption(interaction, 'date');
        const startInput = getStringOption(interaction, 'start');
        const endInput = getStringOption(interaction, 'end');
        const purpose = getStringOption(interaction, 'purpose') || '';

        if (!dateInput || !startInput || !endInput) {
            return reply('必須パラメータが不足しています。');
        }

        const date = parseDateInput(dateInput);
        if (!date) {
            return reply('日付の形式が正しくありません。\n例: `12/25`, `2026/01/01`, `today`');
        }

        const parseTime = (input: string): [number, number] | null => {
            const full = input.match(/^(\d{1,2}):(\d{2})$/);
            if (full) return [parseInt(full[1], 10), parseInt(full[2], 10)];
            const hourOnly = input.match(/^(\d{1,2})$/);
            if (hourOnly) return [parseInt(hourOnly[1], 10), 0];
            return null;
        };

        const startTime = parseTime(startInput);
        const endTime = parseTime(endInput);

        if (!startTime || !endTime) {
            return reply('時刻の形式が正しくありません。\n例: `10:00`, `10`');
        }

        const [startH, startM] = startTime;
        const [endH, endM] = endTime;

        if (startH < 0 || startH > 23 || startM < 0 || startM > 59 ||
            endH < 0 || endH > 23 || endM < 0 || endM > 59) {
            return reply('時刻の形式が正しくありません。\n例: `10:00`');
        }

        const setTime = (d: Date, h: number, m: number) => {
            const newD = new Date(d);
            newD.setHours(h, m, 0, 0);
            return newD;
        };

        const startAt = setTime(date, startH, startM);
        const endAt = setTime(date, endH, endM);

        if (startAt < new Date()) return reply('過去の日時は予約できません。');
        if (startAt >= endAt) return reply('終了時刻は開始時刻より後である必要があります。');

        const discordUserId = getUserId(interaction);
        if (!discordUserId) {
            return reply('ユーザー情報を取得できませんでした。');
        }

        try {
            const res = await api.createReservation({
                start_at: startAt.toISOString(),
                end_at: endAt.toISOString(),
                purpose,
            }, discordUserId);

            const dateStr = startAt.toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric', weekday: 'short' });
            const timeStr = `${startAt.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })} ~ ${endAt.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}`;

            // Discord通知を送信（コマンド応答をブロックしないよう非同期で実行）
            (async () => {
                try {
                    const notifyRoomId = Number(process.env.NOTIFY_ROOM_ID) || 3;
                    const rooms = await api.fetchKeys();
                    const targetRoom = rooms.find(r => r.room_id === notifyRoomId);
                    const keyHolders = targetRoom
                        ? targetRoom.keys.filter(k => k.holder).map(k => ({
                            discord_id: k.holder!.discord_id,
                            display_name: k.holder!.display_name,
                        }))
                        : [];
                    await handleNotification({
                        type: 'reservation_created',
                        data: {
                            user_discord_id: discordUserId,
                            start_at: startAt.toISOString(),
                            end_at: endAt.toISOString(),
                            purpose: res.purpose,
                            key_holders: keyHolders,
                        },
                    });
                } catch (notifyErr) {
                    console.error('通知送信エラー:', notifyErr);
                }
            })();

            return reply(`予約を作成しました！\n📅 **${dateStr} ${timeStr}**\n📝 ${res.purpose || 'なし'}`);
        } catch (e: any) {
            console.error('予約作成エラー:', e);
            if (e instanceof ApiError && e.status === 422 && e.validationErrors.length > 0) {
                const hasOverlap = e.validationErrors.some((msg: string) => msg.includes('既に予約が入っています'));
                if (hasOverlap) {
                    return await buildOverlapErrorResponse(startAt, endAt, e.validationErrors);
                }
                const errorList = e.validationErrors.map((msg: string) => `・${msg}`).join('\n');
                return reply(`予約を作成できませんでした。\n${errorList}`);
            }
            return reply('予約作成に失敗しました。時間をおいて再度お試しください。');
        }
    },
};

async function buildOverlapErrorResponse(startAt: Date, endAt: Date, errors: string[]): Promise<object> {
    const dayStart = new Date(startAt);
    dayStart.setHours(0, 0, 0, 0);
    const dayEnd = new Date(startAt);
    dayEnd.setHours(23, 59, 59, 999);

    let description = '指定された時間帯に既存の予約があります。\n\n';

    try {
        const reservations = await api.fetchReservations(dayStart.toISOString(), dayEnd.toISOString());
        const overlapping = reservations.filter(r => {
            const rStart = new Date(r.start_at);
            const rEnd = new Date(r.end_at);
            return rStart < endAt && rEnd > startAt;
        });

        if (overlapping.length > 0) {
            description += '**重複している予約:**\n';
            for (const res of overlapping) {
                const s = new Date(res.start_at);
                const e = new Date(res.end_at);
                const timeStr = `${s.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })} ~ ${e.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}`;
                let userDisplay = `User ${res.user_id}`;
                if (res.user) {
                    userDisplay = res.user.discord_id ? `<@${res.user.discord_id}>` : (res.user.display_name || res.user.username);
                }
                description += `**${timeStr}**\n${userDisplay}\n📝 ${res.purpose || 'なし'}\n\n`;
            }
        }
    } catch {
        // 予約取得に失敗した場合はバリデーションエラーをそのまま表示
        description += errors.map((msg: string) => `・${msg}`).join('\n');
    }

    return replyEmbed('❌ 予約を作成できませんでした', description, 0xff3333);
}
