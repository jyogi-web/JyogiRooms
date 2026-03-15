import { SlashCommandBuilder } from 'discord.js';
import { api } from '../api.js';
import { InteractionResponseType } from 'discord-interactions';

// Discord API Interaction option types
const STRING_TYPE = 3;

interface InteractionOption {
    name: string;
    type: number;
    value?: string;
    options?: InteractionOption[];
}

interface InteractionData {
    name: string;
    options?: InteractionOption[];
}

interface InteractionUser {
    id: string;
}

interface InteractionMember {
    user: InteractionUser;
}

export interface Interaction {
    type: number;
    data: InteractionData;
    member?: InteractionMember;
    user?: InteractionUser;
    token: string;
    id: string;
}

function getSubcommand(interaction: Interaction): string | null {
    const options = interaction.data.options;
    if (!options || options.length === 0) return null;
    // Subcommand type = 1
    if (options[0].type === 1) return options[0].name;
    return null;
}

function getStringOption(interaction: Interaction, name: string): string | null {
    const subOptions = interaction.data.options?.[0]?.options;
    if (!subOptions) return null;
    const opt = subOptions.find(o => o.name === name && o.type === STRING_TYPE);
    return opt?.value ?? null;
}

function getUserId(interaction: Interaction): string {
    return interaction.member?.user?.id ?? interaction.user?.id ?? 'unknown';
}

export const reserveCommand = {
    data: new SlashCommandBuilder()
        .setName('reserve')
        .setDescription('予約関連のコマンド')
        .addSubcommand(subcommand =>
            subcommand
                .setName('list')
                .setDescription('今後の予約一覧を表示します')
        )
        .addSubcommand(subcommand =>
            subcommand
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
                )
        )
        .addSubcommand(subcommand =>
            subcommand
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
                        .setRequired(false))
        ),

    async execute(interaction: Interaction): Promise<object> {
        const subcommand = getSubcommand(interaction);

        if (subcommand === 'list') {
            return await handleListCommand(interaction);
        } else if (subcommand === 'check') {
            return await handleCheckCommand(interaction);
        } else if (subcommand === 'create') {
            return await handleCreateCommand(interaction);
        }

        return {
            type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
            data: { content: '不明なコマンドです', flags: 64 },
        };
    },
};

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

function replyEmbed(title: string, description: string) {
    return {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: {
            embeds: [{
                title,
                description,
                color: 0x0099ff,
                timestamp: new Date().toISOString(),
            }],
        },
    };
}

async function handleCheckCommand(interaction: Interaction) {
    const preset = getStringOption(interaction, 'preset');
    const dateInput = getStringOption(interaction, 'date');

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
}

async function handleListCommand(_interaction: Interaction) {
    try {
        const now = new Date().toISOString();
        const reservations = await api.fetchReservations(now);

        if (reservations.length === 0) {
            return reply('今後の予約はありません。');
        }

        const MAX_ITEMS = 10;
        const MAX_LENGTH = 4096;
        let description = '';
        let omittedCount = 0;

        for (let i = 0; i < reservations.length; i++) {
            if (i >= MAX_ITEMS) { omittedCount = reservations.length - i; break; }
            const res = reservations[i];
            const start = new Date(res.start_at);
            const end = new Date(res.end_at);
            const dateStr = start.toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric', weekday: 'short' });
            const timeStr = `${start.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })} ~ ${end.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}`;

            let userDisplay = `User ${res.user_id}`;
            if (res.user) {
                userDisplay = res.user.discord_id ? `<@${res.user.discord_id}>` : (res.user.display_name || res.user.username);
            }

            const entry = `**${dateStr} ${timeStr}**\n${userDisplay}\n📝 ${res.purpose || 'なし'}\n\n`;
            if (description.length + entry.length + 50 > MAX_LENGTH) {
                omittedCount = reservations.length - i;
                break;
            }
            description += entry;
        }

        if (omittedCount > 0) description += `...省略: 他 ${omittedCount} 件`;
        return replyEmbed('📅 今後の予約一覧', description);
    } catch (error) {
        console.error(error);
        return reply('予約情報の取得中にエラーが発生しました。');
    }
}

async function handleCreateCommand(interaction: Interaction) {
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
}
