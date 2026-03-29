import { createApi } from '../api.js';
import type { Interaction, CommandEnv } from './types.js';
import { getStringOption, getUserId, reply, replyEmbed } from './utils.js';

const JST_OFFSET_MS = 9 * 60 * 60 * 1000;

function currentFiscalYear(): number {
    const jst = new Date(Date.now() + JST_OFFSET_MS);
    const month = jst.getUTCMonth() + 1;
    const year = jst.getUTCFullYear();
    return month >= 4 ? year : year - 1;
}

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

        const yearOption = getStringOption(interaction, 'year');
        const year = yearOption ?? currentFiscalYear().toString();

        try {
            const api = createApi(env);
            const data = await api.fetchMyStats(discordUserId, year);

            const yearLabel = year === 'all' ? '全期間' : `${year}年度`;
            const title = `📊 ${data.user.display_name} の部室利用統計（${yearLabel}）`;

            const lines: string[] = [];

            // 全体の統計
            lines.push('### 🏠 全体');
            lines.push(`訪問日数: **${data.total.visit_days}日**`);
            lines.push(`滞在時間: **${formatDuration(data.total.total_seconds)}**`);
            lines.push('');

            // 部室ごとの統計
            for (const room of data.rooms) {
                lines.push(`### 🚪 ${room.room_name}`);
                lines.push(`訪問日数: **${room.visit_days}日**`);
                lines.push(`滞在時間: **${formatDuration(room.total_seconds)}**`);
                lines.push('');
            }

            return replyEmbed(title, lines.join('\n'));
        } catch (error) {
            console.error(error);
            return reply('統計情報の取得中にエラーが発生しました。');
        }
    },
};
