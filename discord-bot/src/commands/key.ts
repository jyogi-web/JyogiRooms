import { SlashCommandBuilder } from 'discord.js';
import { api } from '../api.js';
import type { Interaction } from './types.js';
import { getIntegerOption, reply, replyEmbed } from './utils.js';

export const keyCommand = {
    data: new SlashCommandBuilder()
        .setName('key')
        .setDescription('各部室の鍵持ち一覧を表示します')
        .addIntegerOption(option =>
            option.setName('room_id').setDescription('部室ID（省略時は全部室を表示）').setRequired(false)
        ),

    async execute(interaction: Interaction): Promise<object> {
        try {
            const roomId = getIntegerOption(interaction, 'room_id');
            const rooms = await api.fetchKeys();

            if (rooms.length === 0) {
                return reply('部室情報が登録されていません。');
            }

            if (roomId !== null) {
                const room = rooms.find(r => r.room_id === roomId);
                if (!room) {
                    return reply(`ID ${roomId} の部室が見つかりません。`);
                }
                return replyEmbed(`🔑 ${room.room_name}（${room.room_number}）の鍵持ち`, buildRoomSection(room));
            }

            const MAX_LENGTH = 4096;
            let description = '';

            for (const room of rooms) {
                const section = buildRoomSection(room);
                if (description.length + section.length + 50 > MAX_LENGTH) {
                    description += '...省略: 表示しきれない部室があります';
                    break;
                }
                description += section;
            }

            return replyEmbed('🔑 鍵持ち一覧', description);
        } catch (error) {
            console.error(error);
            return reply('鍵情報の取得中にエラーが発生しました。');
        }
    },
};

function buildRoomSection(room: { room_name: string; room_number: string; keys: { holder: { discord_id?: string; display_name: string; username: string } | null }[] }): string {
    let section = `### 🚪 ${room.room_name}（${room.room_number}）\n`;

    const holders = room.keys.filter(k => k.holder !== null);

    if (holders.length === 0) {
        section += '鍵持ちはいません\n\n';
        return section;
    }

    for (const key of holders) {
        const holder = key.holder!;
        const userDisplay = holder.discord_id
            ? `<@${holder.discord_id}>`
            : (holder.display_name || holder.username);
        section += `🔑 ${userDisplay}\n`;
    }
    section += '\n';
    return section;
}
