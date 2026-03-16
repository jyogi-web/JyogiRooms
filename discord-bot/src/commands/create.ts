import { SlashCommandBuilder } from 'discord.js';
import { api } from '../api.js';
import type { Interaction } from './types.js';
import { getStringOption, getUserId, parseDateInput, reply } from './utils.js';

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

            return reply(`予約を作成しました！\n📅 **${dateStr} ${timeStr}**\n📝 ${res.purpose || 'なし'}`);
        } catch (e: any) {
            console.error('予約作成エラー:', e);
            return reply('予約作成に失敗しました。時間をおいて再度お試しください。');
        }
    },
};
