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

        let description = '';

        for (const res of reservations) {
            const start = new Date(res.start_at);
            const end = new Date(res.end_at);

            const dateStr = start.toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric', weekday: 'short' });
            const timeStr = `${start.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })} ~ ${end.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}`;

            // ユーザー名（APIに含まれていれば表示、なければID）
            let userName = res.user?.display_name || res.user?.username || `User ${res.user_id}`;

            // Discord IDがある場合は、サーバー上のニックネームを取得して上書き
            if (res.user?.discord_id && interaction.guild) {
                try {
                    const member = await interaction.guild.members.fetch(res.user.discord_id);
                    if (member) {
                        userName = member.displayName; // サーバーでの表示名（ニックネーム優先）
                    }
                } catch (e) {
                    // メンバーが見つからない場合などは無視してDB上の名前を使う
                    console.warn(`Member fetch failed for ${res.user.discord_id}`);
                }
            }

            description += `**${dateStr} ${timeStr}**\n👤 ${userName}\n\n`;
        }

        embed.setDescription(description);
        await interaction.editReply({ embeds: [embed] });

    } catch (error) {
        console.error(error);
        await interaction.editReply('予約情報の取得中にエラーが発生しました。');
    }
}
