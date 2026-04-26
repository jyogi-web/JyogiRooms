import { createApi } from '../api.js';
import type { Interaction, CommandEnv } from './types.js';
import { getIntegerOption, getUserId, reply, replyEmbed } from './utils.js';

function formatDuration(totalSeconds: number): string {
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    if (hours > 0) {
        return `${hours}時間${minutes}分`;
    }
    return `${minutes}分`;
}

export const meCommand = {
    data: {
        name: 'me',
        description: '自分の部室利用統計を表示します',
    },

    async execute(interaction: Interaction, env: CommandEnv): Promise<object> {
        const discordUserId = getUserId(interaction);
        if (!discordUserId) {
            return reply('ユーザー情報を取得できませんでした。');
        }

        const roomParam = getIntegerOption(interaction, 'room');
        const room = roomParam === null ? 'all' : String(roomParam);

        try {
            const api = createApi(env);
            const data = await api.fetchMyStats(discordUserId, room);

            const roomLabel = room === 'all' ? '全体' : `${room}号室`;
            const title = `📊 ${data.user.display_name} の部室利用統計（${roomLabel}）`;

            const lines: string[] = [];

            if (data.rank.visit.position !== null) {
                lines.push(`🏅 訪問日数ランキング: **${data.rank.visit.position}位** / ${data.rank.visit.total_users}人中`);
            }
            if (data.rank.duration.position !== null) {
                lines.push(`⏱️ 滞在時間ランキング: **${data.rank.duration.position}位** / ${data.rank.duration.total_users}人中`);
            }
            if (data.rank.visit.position !== null || data.rank.duration.position !== null) {
                lines.push('');
            }

            lines.push(`訪問日数: **${data.total.visit_days}日**`);
            lines.push(`滞在時間: **${formatDuration(data.total.total_seconds)}**`);

            return replyEmbed(title, lines.join('\n'));
        } catch (error) {
            console.error(error);
            return reply('統計情報の取得中にエラーが発生しました。');
        }
    },
};