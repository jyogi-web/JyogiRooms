import { createApi, ApiError } from '../api.js';
import type { Interaction, CommandEnv } from './types.js';
import { getStringOption, getUserId, parseDateInput, jstDate, jstDateTime, reply, replyEmbed, isEphemeral } from './utils.js';

export const reserveCommand = {
    data: {
        name: 'reserve',
        description: '予約を新規作成します',
    },

    async execute(interaction: Interaction, env: CommandEnv): Promise<object> {
        const ephemeral = isEphemeral(interaction);
        const dateInput = getStringOption(interaction, 'date');
        const startInput = getStringOption(interaction, 'start');
        const endInput = getStringOption(interaction, 'end');
        const purpose = getStringOption(interaction, 'purpose') || '';

        if (!dateInput || !startInput || !endInput) {
            return reply('必須パラメータが不足しています。', { ephemeral });
        }

        const date = parseDateInput(dateInput);
        if (!date) {
            return reply('日付の形式が正しくありません。\n例: `12/25`, `2026/01/01`, `today`', { ephemeral });
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
            return reply('時刻の形式が正しくありません。\n例: `10:00`, `10`', { ephemeral });
        }

        const [startH, startM] = startTime;
        const [endH, endM] = endTime;

        if (startH < 0 || startH > 23 || startM < 0 || startM > 59 ||
            endH < 0 || endH > 23 || endM < 0 || endM > 59) {
            return reply('時刻の形式が正しくありません。\n例: `10:00`', { ephemeral });
        }

        const startAt = jstDateTime(date.year, date.month, date.day, startH, startM);
        const endAt = jstDateTime(date.year, date.month, date.day, endH, endM);

        if (startAt < new Date()) return reply('過去の日時は予約できません。', { ephemeral });
        if (startAt >= endAt) return reply('終了時刻は開始時刻より後である必要があります。', { ephemeral });

        const discordUserId = getUserId(interaction);
        if (!discordUserId) {
            return reply('ユーザー情報を取得できませんでした。', { ephemeral });
        }

        try {
            const api = createApi(env);
            const res = await api.createReservation({
                start_at: startAt.toISOString(),
                end_at: endAt.toISOString(),
                purpose,
            }, discordUserId);

            const dateStr = startAt.toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric', weekday: 'short', timeZone: 'Asia/Tokyo' });
            const timeStr = `${startAt.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tokyo' })} ~ ${endAt.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tokyo' })}`;

            return reply(`予約を作成しました！\n📅 **${dateStr} ${timeStr}**\n📝 ${res.purpose || 'なし'}`, { ephemeral });
        } catch (e: any) {
            console.error('予約作成エラー:', e);
            if (e instanceof ApiError && e.status === 422 && e.validationErrors.length > 0) {
                const hasOverlap = e.validationErrors.some((msg: string) => msg.includes('既に予約が入っています'));
                if (hasOverlap) {
                    return await buildOverlapErrorResponse(env, startAt, endAt, e.validationErrors, ephemeral);
                }
                const errorList = e.validationErrors.map((msg: string) => `・${msg}`).join('\n');
                return reply(`予約を作成できませんでした。\n${errorList}`, { ephemeral });
            }
            return reply('予約作成に失敗しました。時間をおいて再度お試しください。', { ephemeral });
        }
    },
};

async function buildOverlapErrorResponse(env: CommandEnv, startAt: Date, endAt: Date, errors: string[], ephemeral: boolean = false): Promise<object> {
    const jst = new Date(startAt.getTime() + 9 * 60 * 60 * 1000);
    const dayStart = jstDate(jst.getUTCFullYear(), jst.getUTCMonth(), jst.getUTCDate());
    const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000 - 1);

    let description = '指定された時間帯に既存の予約があります。\n\n';

    try {
        const api = createApi(env);
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
                const timeStr = `${s.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tokyo' })} ~ ${e.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tokyo' })}`;
                let userDisplay = `User ${res.user_id}`;
                if (res.user) {
                    userDisplay = res.user.discord_id ? `<@${res.user.discord_id}>` : (res.user.display_name || res.user.username);
                }
                description += `**${timeStr}**\n${userDisplay}\n📝 ${res.purpose || 'なし'}\n\n`;
            }
        }
    } catch {
        description += errors.map((msg: string) => `・${msg}`).join('\n');
    }

    return replyEmbed('❌ 予約を作成できませんでした', description, 0xff3333, { ephemeral });
}
