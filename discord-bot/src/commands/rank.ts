import { createApi } from '../api.js';
import type { RankingEntry } from '../api.js';
import { PERIOD_LABELS } from '../constants.js';
import type { Interaction, CommandEnv } from './types.js';
import { getStringOption, reply, replyEmbed } from './utils.js';

function formatDuration(totalSeconds: number): string {
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    if (hours > 0) {
        return `${hours}時間${minutes}分`;
    }
    return `${minutes}分`;
}

function rankEmoji(index: number): string {
    if (index === 0) return '🥇';
    if (index === 1) return '🥈';
    if (index === 2) return '🥉';
    return `**${index + 1}.**`;
}

export const rankCommand = {
    data: {
        name: 'rank',
        description: '部室の訪問回数・滞在時間ランキングを表示します',
    },

    async execute(interaction: Interaction, env: CommandEnv): Promise<object> {
        const type = getStringOption(interaction, 'type') ?? 'visits';
        const period = getStringOption(interaction, 'period') ?? 'month';
        const room = getStringOption(interaction, 'room');

        try {
            const api = createApi(env);
            const data = await api.fetchRanking(type, period, room ?? 'all');

            if (data.ranking.length === 0) {
                return reply('該当期間のデータがありません。');
            }

            const typeLabel = type === 'visits' ? '訪問日数' : '滞在時間';
            const roomLabel = room ? `🚪第${room}部室` : '🚪全部室';
            const periodLabel = PERIOD_LABELS[period] ?? period;
            const title = `📊 ${typeLabel}ランキング（${periodLabel} / ${roomLabel}）`;

            const lines = data.ranking.map((entry: RankingEntry, i: number) => {
                const name = entry.display_name ?? '不明なユーザー';
                const value = type === 'visits'
                    ? `${entry.count}日`
                    : formatDuration(entry.total_seconds ?? 0);
                return `${rankEmoji(i)} ${name} — ${value}`;
            });

            return replyEmbed(title, lines.join('\n'));
        } catch (error) {
            console.error(error);
            return reply('ランキングの取得中にエラーが発生しました。');
        }
    },
};
