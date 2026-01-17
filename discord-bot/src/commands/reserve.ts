import { SlashCommandBuilder, CommandInteraction } from 'discord.js';

export const reserveCommand = {
    data: new SlashCommandBuilder()
        .setName('reserve')
        .setDescription('予約を開始します'),

    async execute(interaction: CommandInteraction) {
        await interaction.reply('予約機能は現在準備中です！');
    },
};
