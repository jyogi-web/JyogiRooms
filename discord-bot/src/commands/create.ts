import { SlashCommandBuilder } from 'discord.js';
import { api } from '../api.js';
import { InteractionResponseType } from 'discord-interactions';
import type { Interaction } from './types.js';

const STRING_TYPE = 3;

function getStringOption(interaction: Interaction, name: string): string | null {
    const options = interaction.data.options;
    if (!options) return null;
    const opt = options.find(o => o.name === name && o.type === STRING_TYPE);
    return opt?.value ?? null;
}

function getUserId(interaction: Interaction): string {
    return interaction.member?.user?.id ?? interaction.user?.id ?? 'unknown';
}

function parseDateInput(input: string): Date | null {
    const now = new Date();
    const normalized = input.toLowerCase().trim();

    if (!normalized || normalized === 'today') return now;
    if (normalized === 'tomorrow') {
        const d = new Date(now);
        d.setDate(d.getDate() + 1);
        return d;
    }

    const ymdMatch = normalized.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$/);
    if (ymdMatch) {
        const year = parseInt(ymdMatch[1], 10);
        const month = parseInt(ymdMatch[2], 10) - 1;
        const day = parseInt(ymdMatch[3], 10);
        const d = new Date(year, month, day);
        if (d.getFullYear() !== year || d.getMonth() !== month || d.getDate() !== day) return null;
        return d;
    }

    const mdMatch = normalized.match(/^(\d{1,2})[-/.](\d{1,2})$/);
    if (mdMatch) {
        const year = now.getFullYear();
        const month = parseInt(mdMatch[1], 10) - 1;
        const day = parseInt(mdMatch[2], 10);
        const d = new Date(year, month, day);
        if (d.getFullYear() !== year || d.getMonth() !== month || d.getDate() !== day) return null;
        return d;
    }

    return null;
}

function reply(content: string) {
    return {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: { content },
    };
}

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

        const timeRegex = /^(\d{1,2}):(\d{2})$/;
        const startMatch = startInput.match(timeRegex);
        const endMatch = endInput.match(timeRegex);

        if (!startMatch || !endMatch) {
            return reply('時刻の形式が正しくありません。\n例: `10:00`');
        }

        const startH = parseInt(startMatch[1], 10);
        const startM = parseInt(startMatch[2], 10);
        const endH = parseInt(endMatch[1], 10);
        const endM = parseInt(endMatch[2], 10);

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

        try {
            const discordUserId = getUserId(interaction);
            const res = await api.createReservation({
                start_at: startAt.toISOString(),
                end_at: endAt.toISOString(),
                purpose,
            }, discordUserId);

            const dateStr = startAt.toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric', weekday: 'short' });
            const timeStr = `${startAt.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })} ~ ${endAt.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}`;

            return reply(`予約を作成しました！\n📅 **${dateStr} ${timeStr}**\n📝 ${res.purpose || 'なし'}`);
        } catch (e: any) {
            console.error(e);
            return reply(`予約作成に失敗しました。\n${e.message || 'Unknown error'}`);
        }
    },
};
