import { SlashCommandBuilder } from 'discord.js';
import { api } from '../api.js';
import type { Interaction } from './types.js';
import { getStringOption, reply, replyEmbed } from './utils.js';

export const statusCommand = {
    data: new SlashCommandBuilder()
        .setName('status')
        .setDescription('部室の状況を確認します')
        .addStringOption(option =>
            option.setName('room').setDescription('部室番号（例: 1, 2, 3）または all（省略時も全部室）').setRequired(false)
        ),

    async execute(interaction: Interaction): Promise<object> {
        const room = getStringOption(interaction, 'room');

        try {
            const rooms = await withTimeout(api.fetchKeys(), 3000);

            if (rooms.length === 0) {
                return reply('部室情報が登録されていません。');
            }

            let targetRooms = rooms;
            if (room && room.toLowerCase() !== 'all') {
                const roomId = parseInt(room, 10);
                if (isNaN(roomId)) {
                    return reply('部室番号は数字で指定するか、`all` で全部室を表示できます。');
                }
                targetRooms = rooms.filter(r => r.room_id === roomId);
                if (targetRooms.length === 0) {
                    return reply(`ID ${roomId} の部室が見つかりません。`);
                }
            }

            const MAX_LENGTH = 4096;
            let description = '';

            const statusResults = await Promise.allSettled(
                targetRooms.map((r) => withTimeout(api.fetchRoomStatus(r.room_id), 3000))
            );

            for (const [index, result] of statusResults.entries()) {
                const roomInfo = targetRooms[index];
                const section = result.status === 'fulfilled'
                    ? buildStatusSection(result.value)
                    : buildFailedSection(roomInfo.room_name);

                if (description.length + section.length + 50 > MAX_LENGTH) {
                    description += '...省略: 表示しきれない部室があります';
                    break;
                }
                description += section;
            }

            return replyEmbed('🏠 部室状況', description);
        } catch (error) {
            console.error(error);
            return reply('部室状況の取得中にエラーが発生しました。');
        }
    },
};

function buildStatusSection(status: {
    room: { name: string };
    is_open: boolean;
    opened_at: string | null;
    opened_by: { display_name: string } | null;
    occupants: { display_name: string; entered_at: string }[];
    occupant_count: number;
}): string {
    const stateEmoji = status.is_open ? '🟢 開室中' : '🔴 閉室';
    let section = `### 🚪 ${status.room.name}\n${stateEmoji}`;

    if (status.is_open && status.opened_by && status.opened_at) {
        const time = formatTime(status.opened_at);
        section += ` （${status.opened_by.display_name}が${time}に開室）`;
    }
    section += '\n';

    if (status.occupant_count === 0) {
        section += '入室者なし\n';
    } else {
        section += `**入室中: ${status.occupant_count}人**\n`;
        for (const occupant of status.occupants) {
            const time = formatTime(occupant.entered_at);
            section += `・${occupant.display_name}（${time}〜）\n`;
        }
    }

    return section;
}

function buildFailedSection(roomName: string): string {
    return `### 🚪 ${roomName}\n⚠️ 状況取得に失敗しました\n`;
}

function formatTime(value: string): string {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
        return '--:--';
    }

    return date.toLocaleTimeString('ja-JP', {
        hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tokyo'
    });
}

function withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T> {
    return new Promise<T>((resolve, reject) => {
        const timeoutId = setTimeout(() => {
            reject(new Error(`timeout after ${timeoutMs}ms`));
        }, timeoutMs);

        promise
            .then((result) => {
                clearTimeout(timeoutId);
                resolve(result);
            })
            .catch((error) => {
                clearTimeout(timeoutId);
                reject(error);
            });
    });
}
