import { SlashCommandBuilder } from 'discord.js';
import { api, ApiError } from '../api.js';
import type { Interaction } from './types.js';
import { getUserId, reply, replyEmbed } from './utils.js';

export const exitCommand = {
    data: new SlashCommandBuilder()
        .setName('exit')
        .setDescription('現在入室中の部室から退室します'),

    async execute(interaction: Interaction): Promise<object> {
        const discordUserId = getUserId(interaction);

        if (!discordUserId) {
            return reply('ユーザー情報を取得できませんでした。');
        }

        try {
            const result = await api.exitCurrent(discordUserId);
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
