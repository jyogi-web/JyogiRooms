import { createApi } from '../api.js';
import type { Interaction, CommandEnv } from './types.js';
import { getStringOption, getUserId, reply, replyEmbed } from './utils.js';
import { logDiscordView } from '../viewLog.js';

export const statusCommand = {
    data: {
        name: 'status',
        description: '部室の状況を確認します',
    },

    async execute(interaction: Interaction, env: CommandEnv, ctx?: ExecutionContext): Promise<object> {
        const room = getStringOption(interaction, 'room');

        // 閲覧ログ（誰がいつ /status を見たか）を応答をブロックせず記録する。
        // 5分窓の重複間引きは取り込み Worker 側で行う。
        const discordUserId = getUserId(interaction);
        if (discordUserId) {
            const logPromise = logDiscordView(env, discordUserId);
            if (ctx) {
                ctx.waitUntil(logPromise);
            }
        }

        try {
            const api = createApi(env);
            const rooms = await withTimeout(() => api.fetchKeys(), 10000);

            if (rooms.length === 0) {
                return reply('部室情報が登録されていません。');
            }

            let targetRooms = rooms;
            if (room) {
                const roomId = parseInt(room, 10);
                if (isNaN(roomId)) {
                    return reply('部室番号は数字で指定してください。省略すると全部室を表示します。');
                }
                targetRooms = rooms.filter(r => r.room_id === roomId);
                if (targetRooms.length === 0) {
                    return reply(`ID ${roomId} の部室が見つかりません。`);
                }
            }

            const MAX_LENGTH = 4096;
            let description = '';

            const statusResults = await Promise.allSettled(
                targetRooms.map((r) => withTimeout(() => api.fetchRoomStatus(r.room_id), 10000))
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

function withTimeout<T>(task: () => Promise<T>, timeoutMs: number): Promise<T> {
    return new Promise<T>((resolve, reject) => {
        const timeoutId = setTimeout(() => {
            reject(new Error(`timeout after ${timeoutMs}ms`));
        }, timeoutMs);

        task()
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
