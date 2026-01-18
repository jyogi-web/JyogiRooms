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
        ),

    async execute(interaction: ChatInputCommandInteraction) {
        const subcommand = interaction.options.getSubcommand();

        if (subcommand === 'list') {
            await handleListCommand(interaction);
        } else {
            await interaction.reply({ content: '不明なコマンドです', ephemeral: true });
        }
    },
};

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

            const entry = `**${dateStr} ${timeStr}**\n👤${userDisplay}\n📝 ${res.purpose || 'なし'}\n\n`;
            
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
