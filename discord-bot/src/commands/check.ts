import { SlashCommandBuilder } from 'discord.js';
import { api } from '../api.js';
import type { Interaction } from './types.js';
import { getStringOption, parseDateInput, reply, replyEmbed } from './utils.js';

export const checkCommand = {
    data: new SlashCommandBuilder()
        .setName('check')
        .setDescription('指定した日の予約を確認します')
        .addStringOption(option =>
            option
                .setName('preset')
                .setDescription('日付プリセット')
                .setRequired(false)
                .addChoices(
                    { name: '今日 (Today)', value: 'today' },
                    { name: '明日 (Tomorrow)', value: 'tomorrow' }
                )
        )
        .addStringOption(option =>
            option
                .setName('date')
                .setDescription('日付指定 (例: 11/23, 2025/01/01)')
                .setRequired(false)
        ),

    async execute(interaction: Interaction): Promise<object> {
        const preset = getStringOption(interaction, 'preset');
        const dateInput = getStringOption(interaction, 'date');

        if (preset && dateInput) {
            return reply('`preset`と`date`は同時に指定できません。どちらか一方を指定してください。');
        }

        let targetDateStr = 'today';
        if (preset) targetDateStr = preset;
        else if (dateInput) targetDateStr = dateInput;

        const targetDate = parseDateInput(targetDateStr);
        if (!targetDate || isNaN(targetDate.getTime())) {
            return reply('日付の形式が正しくありません。\n例: `11/23`, `2025/01/01`, `today`');
        }

        const start = new Date(targetDate);
        start.setHours(0, 0, 0, 0);
        const end = new Date(targetDate);
        end.setHours(23, 59, 59, 999);

        try {
            const reservations = await api.fetchReservations(start.toISOString(), end.toISOString());
            const dateDisplay = start.toLocaleDateString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit', weekday: 'short' });

            if (reservations.length === 0) {
                return replyEmbed(`📅 ${dateDisplay} の予約一覧`, '予約はありません。');
            }

            const MAX_LENGTH = 4096;
            let description = '';
            let omittedCount = 0;

            for (let i = 0; i < reservations.length; i++) {
                const res = reservations[i];
                const s = new Date(res.start_at);
                const e = new Date(res.end_at);
                const timeStr = `${s.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })} ~ ${e.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}`;

                let userDisplay = `User ${res.user_id}`;
                if (res.user) {
                    userDisplay = res.user.discord_id ? `<@${res.user.discord_id}>` : (res.user.display_name || res.user.username);
                }

                const entry = `**${timeStr}**\n${userDisplay}\n📝 ${res.purpose || 'なし'}\n\n`;
                if (description.length + entry.length + 50 > MAX_LENGTH) {
                    omittedCount = reservations.length - i;
                    break;
                }
                description += entry;
            }

            if (omittedCount > 0) description += `...省略: 他 ${omittedCount} 件`;
            return replyEmbed(`📅 ${dateDisplay} の予約一覧`, description);
        } catch (error) {
            console.error(error);
            return reply('予約情報の取得中にエラーが発生しました。');
        }
    },
};
