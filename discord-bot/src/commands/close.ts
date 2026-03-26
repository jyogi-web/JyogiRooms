import { SlashCommandBuilder } from 'discord.js';
import { api, ApiError } from '../api.js';
import type { Interaction } from './types.js';
import { getStringOption, getUserId, reply, replyEmbed } from './utils.js';

export const closeCommand = {
    data: new SlashCommandBuilder()
        .setName('close')
        .setDescription('部室を閉室します')
        .addStringOption(option =>
            option.setName('room').setDescription('部室番号（例: 1, 2, 3）または all（全部室）').setRequired(true)
        ),

    async execute(interaction: Interaction): Promise<object> {
        const room = getStringOption(interaction, 'room');
        const discordUserId = getUserId(interaction);

        if (!room || !discordUserId) {
            return reply('部室番号またはallの指定が必要です。');
        }

        try {
            if (room.toLowerCase() === 'all') {
                return await closeAllRooms(discordUserId);
            }

            const roomId = parseInt(room, 10);
            if (isNaN(roomId)) {
                return reply('部室番号は数字で指定するか、`all` で全部室を閉室できます。');
            }

            const result = await api.closeRoom(roomId, discordUserId);
            return replyEmbed(
                '🔒 閉室しました',
                `**${result.room.name}** を閉室しました。\n入室中のメンバーは全員退室されました。`,
                0xff3333
            );
        } catch (error) {
            if (error instanceof ApiError) {
                return reply(`エラー: ${error.validationErrors.join(', ') || error.message}`);
            }
            console.error(error);
            return reply('閉室処理中にエラーが発生しました。');
        }
    },
};

async function closeAllRooms(discordUserId: string): Promise<object> {
    const rooms = await api.fetchKeys();
    const results: string[] = [];
    const errors: string[] = [];

    for (const room of rooms) {
        try {
            const result = await api.closeRoom(room.room_id, discordUserId);
            results.push(`${result.room.name}: 閉室しました`);
        } catch (error) {
            if (error instanceof ApiError) {
                const msg = error.validationErrors.join(', ') || error.message;
                errors.push(`${room.room_name}: ${msg}`);
            } else {
                errors.push(`${room.room_name}: エラー`);
            }
        }
    }

    let description = '';
    if (results.length > 0) {
        description += results.map(r => `✅ ${r}`).join('\n');
    }
    if (errors.length > 0) {
        if (description) description += '\n';
        description += errors.map(e => `⚠️ ${e}`).join('\n');
    }

    if (!description) {
        return reply('閉室対象の部室がありませんでした。');
    }

    return replyEmbed('🔒 全部室閉室', description, 0xff3333);
}
