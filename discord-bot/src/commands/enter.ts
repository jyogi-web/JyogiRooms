import { SlashCommandBuilder } from 'discord.js';
import { api, ApiError } from '../api.js';
import type { Interaction } from './types.js';
import { getStringOption, getUserId, reply, replyEmbed } from './utils.js';

export const enterCommand = {
    data: new SlashCommandBuilder()
        .setName('enter')
        .setDescription('部室に入室します')
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
            const result = await api.enterRoom(roomId, discordUserId);
            return replyEmbed(
                '📱 入室しました',
                `**${result.room.name}** に入室しました。`,
                0x00cc66
            );
        } catch (error) {
            if (error instanceof ApiError) {
                return reply(`エラー: ${error.validationErrors.join(', ') || error.message}`);
            }
            console.error(error);
            return reply('入室処理中にエラーが発生しました。');
        }
    },
};
