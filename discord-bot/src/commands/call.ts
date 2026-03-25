import { SlashCommandBuilder } from 'discord.js';
import { api } from '../api.js';
import type { Interaction } from './types.js';
import { getIntegerOption, reply } from './utils.js';
import { InteractionResponseType } from 'discord-interactions';

export const callCommand = {
    data: new SlashCommandBuilder()
        .setName('call')
        .setDescription('指定した部室の鍵持ちをメンションして通知します')
        .addIntegerOption(option =>
            option.setName('room_id').setDescription('部室ID').setRequired(true)
        ),

    async execute(interaction: Interaction): Promise<object> {
        try {
            const roomId = getIntegerOption(interaction, 'room_id');
            if (roomId === null) {
                return reply('部室IDを指定してください。');
            }

            const rooms = await api.fetchKeys();
            const room = rooms.find(r => r.room_id === roomId);

            if (!room) {
                return reply(`ID ${roomId} の部室が見つかりません。`);
            }

            const holders = room.keys.filter(k => k.holder !== null);

            if (holders.length === 0) {
                return reply(`${room.room_name}（${room.room_number}）には現在鍵持ちがいません。`);
            }

            const mentions = holders
                .map(k => {
                    const holder = k.holder!;
                    return holder.discord_id
                        ? `<@${holder.discord_id}>`
                        : (holder.display_name || holder.username);
                })
                .join(' ');

            return {
                type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
                data: {
                    content: `🔑 **${room.room_name}** の鍵持ちメンション:\n${mentions}`,
                },
            };
        } catch (error) {
            console.error(error);
            return reply('鍵情報の取得中にエラーが発生しました。');
        }
    },
};
