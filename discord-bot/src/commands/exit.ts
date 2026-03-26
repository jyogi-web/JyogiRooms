import { SlashCommandBuilder } from 'discord.js';
import { api, ApiError } from '../api.js';
import type { Interaction } from './types.js';
import { getStringOption, getUserId, reply, replyEmbed } from './utils.js';

export const exitCommand = {
    data: new SlashCommandBuilder()
        .setName('exit')
        .setDescription('部室から退室します')
        .addStringOption(option =>
            option.setName('room').setDescription('部室番号（例: 1, 2, 3）').setRequired(true)
        ),

    async execute(interaction: Interaction): Promise<object> {
        const room = getStringOption(interaction, 'room');
        const discordUserId = getUserId(interaction);

        if (!room || !discordUserId) {
            return reply('部室番号の指定が必要です。');
        }

        const roomId = parseInt(room, 10);
        if (isNaN(roomId)) {
            return reply('部室番号は数字で指定してください（例: 1, 2, 3）。');
        }

        try {
            const result = await api.exitRoom(roomId, discordUserId);
            return replyEmbed(
                '📱 退室しました',
                `**${result.room.name}** から退室しました。`,
                0xff9900
            );
        } catch (error) {
            if (error instanceof ApiError) {
                return reply(`エラー: ${error.validationErrors.join(', ') || error.message}`);
            }
            console.error(error);
            return reply('退室処理中にエラーが発生しました。');
        }
    },
};
