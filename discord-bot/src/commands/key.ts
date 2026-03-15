import { SlashCommandBuilder } from 'discord.js';
import { api } from '../api.js';
import { InteractionResponseType } from 'discord-interactions';
import type { Interaction } from './types.js';

function replyEmbed(title: string, description: string) {
    return {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: {
            embeds: [{
                title,
                description,
                color: 0x0099ff,
                timestamp: new Date().toISOString(),
            }],
        },
    };
}

function reply(content: string) {
    return {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: { content },
    };
}

export const keyCommand = {
    data: new SlashCommandBuilder()
        .setName('key')
        .setDescription('各部室の鍵持ち一覧を表示します'),

    async execute(_interaction: Interaction): Promise<object> {
        try {
            const rooms = await api.fetchKeys();

            if (rooms.length === 0) {
                return reply('部室情報が登録されていません。');
            }

            let description = '';

            for (const room of rooms) {
                description += `### 🚪 ${room.room_name}（${room.room_number}）\n`;

                const holders = room.keys.filter(k => k.holder !== null);

                if (holders.length === 0) {
                    description += '鍵持ちはいません\n\n';
                    continue;
                }

                for (const key of holders) {
                    const holder = key.holder!;
                    const userDisplay = holder.discord_id
                        ? `<@${holder.discord_id}>`
                        : (holder.display_name || holder.username);
                    description += `🔑 ${userDisplay}\n`;
                }
                description += '\n';
            }

            return replyEmbed('🔑 鍵持ち一覧', description);
        } catch (error) {
            console.error(error);
            return reply('鍵情報の取得中にエラーが発生しました。');
        }
    },
};
