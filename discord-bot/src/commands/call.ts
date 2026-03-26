import { SlashCommandBuilder } from 'discord.js';
import { api } from '../api.js';
import type { Interaction } from './types.js';
import { getStringOption, reply } from './utils.js';
import { InteractionResponseType } from 'discord-interactions';

export const callCommand = {
    data: new SlashCommandBuilder()
        .setName('call')
        .setDescription('指定した部室の鍵持ちをメンションして通知します')
        .addStringOption(option =>
            option.setName('room').setDescription('部室番号（例: 1, 2, 3）').setRequired(true)
        ),

    async execute(interaction: Interaction): Promise<object> {
        try {
            const room = getStringOption(interaction, 'room');
            if (!room) {
                return reply('部室番号を指定してください。');
            }

            const roomId = parseInt(room, 10);
            if (isNaN(roomId)) {
                return reply('部室番号は数字で指定してください（例: 1, 2, 3）。');
            }

            const rooms = await api.fetchKeys();
            const target = rooms.find(r => r.room_id === roomId);

            if (!target) {
                return reply(`第${room}部室が見つかりません。`);
            }

            const holders = target.keys.filter(k => k.holder !== null);

            if (holders.length === 0) {
                return reply(`${target.room_name}（${target.room_number}）には現在鍵持ちがいません。`);
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
                    content: `🔑 **${target.room_name}** の鍵持ちメンション:\n${mentions}`,
                },
            };
        } catch (error) {
            console.error(error);
            return reply('鍵情報の取得中にエラーが発生しました。');
        }
    },
};
