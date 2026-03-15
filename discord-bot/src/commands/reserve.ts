import { SlashCommandBuilder, CommandInteraction, ChatInputCommandInteraction, EmbedBuilder } from 'discord.js';
import { api } from '../api.js';

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

    async execute(interaction: ChatInputCommandInteraction) {
        const subcommand = interaction.options.getSubcommand();

        if (subcommand === 'list') {
            await handleListCommand(interaction);
        } else if (subcommand === 'check') {
            await handleCheckCommand(interaction);
        } else if (subcommand === 'create') {
            await handleCreateCommand(interaction);
        } else {
            await interaction.reply({ content: '不明なコマンドです', ephemeral: true });
        }
    },
};

/**
 * 柔軟な日付解析を行うヘルパー
 * - "today", "tomorrow"
 * - "MM/DD", "M-D", "MM.DD" (今年は現在の年)
 * - "YYYY/MM/DD", "YYYY-MM-DD", "YYYY.MM.DD"
 */
function parseDateInput(input: string): Date | null {
    const now = new Date();
    const normalized = input.toLowerCase().trim();

    if (!normalized || normalized === 'today') {
        return now;
    }
    if (normalized === 'tomorrow') {
        const d = new Date(now);
        d.setDate(d.getDate() + 1);
        return d;
    }

    // YYYY/MM/DD or YYYY-MM-DD
    const ymdMatch = normalized.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$/);
    if (ymdMatch) {
        const year = parseInt(ymdMatch[1], 10);
        const month = parseInt(ymdMatch[2], 10) - 1;
        const day = parseInt(ymdMatch[3], 10);
        const d = new Date(year, month, day);
        if (d.getFullYear() !== year || d.getMonth() !== month || d.getDate() !== day) {
            return null;
        }
        return d;
    }

    // MM/DD or MM-DD (Current Year)
    const mdMatch = normalized.match(/^(\d{1,2})[-/.](\d{1,2})$/);
    if (mdMatch) {
        const year = now.getFullYear();
        const month = parseInt(mdMatch[1], 10) - 1;
        const day = parseInt(mdMatch[2], 10);
        const d = new Date(year, month, day);
        if (d.getFullYear() !== year || d.getMonth() !== month || d.getDate() !== day) {
            return null;
        }
        return d;
    }

    return null;
}

async function handleCheckCommand(interaction: ChatInputCommandInteraction) {
    await interaction.deferReply();

    const preset = interaction.options.getString('preset');
    const dateInput = interaction.options.getString('date');

    // 優先順位: preset > date > today(default)
    let targetDateStr = 'today';
    if (preset) {
        targetDateStr = preset;
    } else if (dateInput) {
        targetDateStr = dateInput;
    }

    const targetDate = parseDateInput(targetDateStr);

    if (!targetDate || isNaN(targetDate.getTime())) {
        await interaction.editReply(`日付の形式が正しくありません。\n例: \`11/23\`, \`2025/01/01\`, \`today\``);
        return;
    }

    // 検索範囲: 指定日の 00:00:00 〜 23:59:59
    const start = new Date(targetDate);
    start.setHours(0, 0, 0, 0);

    const end = new Date(targetDate);
    end.setHours(23, 59, 59, 999);

    try {
        const reservations = await api.fetchReservations(start.toISOString(), end.toISOString());

        const dateDisplay = start.toLocaleDateString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit', weekday: 'short' });
        const embed = new EmbedBuilder()
            .setTitle(`📅 ${dateDisplay} の予約一覧`)
            .setColor('#0099ff')
            .setTimestamp();

        if (reservations.length === 0) {
            embed.setDescription('予約はありません。');
        } else {
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
                    if (res.user.discord_id) {
                        userDisplay = `<@${res.user.discord_id}>`;
                    } else {
                        userDisplay = res.user.display_name || res.user.username;
                    }
                }

                const entry = `**${timeStr}**\n${userDisplay}\n📝 ${res.purpose || 'なし'}\n\n`;

                const OMISSION_BUFFER = 50;
                if (description.length + entry.length + OMISSION_BUFFER > MAX_LENGTH) {
                    omittedCount = reservations.length - i;
                    break;
                }

                description += entry;
            }

            if (omittedCount > 0) {
                description += `...省略: 他 ${omittedCount} 件`;
            }
            embed.setDescription(description);
        }

        await interaction.editReply({ content: '', embeds: [embed] });

    } catch (error) {
        console.error(error);
        await interaction.editReply('予約情報の取得中にエラーが発生しました。');
    }
}

async function handleListCommand(interaction: ChatInputCommandInteraction) {
    await interaction.deferReply();

    try {
        // 現在時刻以降の予約を取得
        const now = new Date().toISOString();
        const reservations = await api.fetchReservations(now);

        if (reservations.length === 0) {
            await interaction.editReply('今後の予約はありません。');
            return;
        }

        const embed = new EmbedBuilder()
            .setTitle('📅 今後の予約一覧')
            .setColor('#0099ff')
            .setTimestamp();

        const MAX_ITEMS = 10;
        const MAX_LENGTH = 4096;
        let description = '';
        let omittedCount = 0;

        for (let i = 0; i < reservations.length; i++) {
            const res = reservations[i];

            // Item count limit check
            if (i >= MAX_ITEMS) {
                omittedCount = reservations.length - i;
                break;
            }

            const start = new Date(res.start_at);
            const end = new Date(res.end_at);

            const dateStr = start.toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric', weekday: 'short' });
            const timeStr = `${start.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })} ~ ${end.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}`;

            // Determine user display (mention if Discord ID exists)
            let userDisplay = `User ${res.user_id}`;
            if (res.user) {
                if (res.user.discord_id) {
                    userDisplay = `<@${res.user.discord_id}>`;
                } else {
                    userDisplay = res.user.display_name || res.user.username;
                }
            }

            const entry = `**${dateStr} ${timeStr}**\n${userDisplay}\n📝 ${res.purpose || 'なし'}\n\n`;

            const OMISSION_BUFFER = 50;
            if (description.length + entry.length + OMISSION_BUFFER > MAX_LENGTH) {
                omittedCount = reservations.length - i;
                break;
            }

            description += entry;
        }

        if (omittedCount > 0) {
            description += `...省略: 他 ${omittedCount} 件`;
        }

        embed.setDescription(description);
        await interaction.editReply({ content: '', embeds: [embed] });

    } catch (error) {
        console.error(error);
        await interaction.editReply('予約情報の取得中にエラーが発生しました。');
    }
}

async function handleCreateCommand(interaction: ChatInputCommandInteraction) {
    await interaction.deferReply();

    const dateInput = interaction.options.getString('date', true);
    const startInput = interaction.options.getString('start', true);
    const endInput = interaction.options.getString('end', true);
    const purpose = interaction.options.getString('purpose') || '';

    // 日付解析 (parseDateInput を利用)
    const date = parseDateInput(dateInput);
    if (!date) {
        await interaction.editReply('日付の形式が正しくありません。\n例: `12/25`, `2026/01/01`, `today`');
        return;
    }

    // 時刻解析
    const timeRegex = /^(\d{1,2}):(\d{2})$/;
    const startMatch = startInput.match(timeRegex);
    const endMatch = endInput.match(timeRegex);

    if (!startMatch || !endMatch) {
        await interaction.editReply('時刻の形式が正しくありません。\n例: `10:00`');
        return;
    }

    const startH = parseInt(startMatch[1], 10);
    const startM = parseInt(startMatch[2], 10);
    const endH = parseInt(endMatch[1], 10);
    const endM = parseInt(endMatch[2], 10);

    if (startH < 0 || startH > 23 || startM < 0 || startM > 59 ||
        endH < 0 || endH > 23 || endM < 0 || endM > 59) {
        await interaction.editReply('時刻の形式が正しくありません。\n例: `10:00`');
        return;
    }

    const setTime = (d: Date, h: number, m: number) => {
        const newD = new Date(d);
        newD.setHours(h, m, 0, 0);
        return newD;
    };

    const startAt = setTime(date, startH, startM);
    const endAt = setTime(date, endH, endM);

    if (startAt < new Date()) {
        await interaction.editReply('過去の日時は予約できません。');
        return;
    }

    if (startAt >= endAt) {
        await interaction.editReply('終了時刻は開始時刻より後である必要があります。');
        return;
    }

    try {
        const res = await api.createReservation({
            start_at: startAt.toISOString(),
            end_at: endAt.toISOString(),
            purpose
        }, interaction.user.id);

        const dateStr = startAt.toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric', weekday: 'short' });
        const timeStr = `${startAt.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })} ~ ${endAt.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}`;

        await interaction.editReply(`予約を作成しました！\n📅 **${dateStr} ${timeStr}**\n📝 ${res.purpose || 'なし'}`);

    } catch (e: any) {
        console.error(e);
        await interaction.editReply(`予約作成に失敗しました。\n${e.message || 'Unknown error'}`);
    }
}
