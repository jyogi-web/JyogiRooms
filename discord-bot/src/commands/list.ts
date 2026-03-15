import { SlashCommandBuilder } from 'discord.js';
import { api } from '../api.js';
import { InteractionResponseType } from 'discord-interactions';
import type { Interaction } from './types.js';

function reply(content: string) {
    return {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: { content },
    };
}

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

export const listCommand = {
    data: new SlashCommandBuilder()
        .setName('list')
        .setDescription('今後の予約一覧を表示します'),

    async execute(_interaction: Interaction): Promise<object> {
        try {
            const now = new Date().toISOString();
            const reservations = await api.fetchReservations(now);

            if (reservations.length === 0) {
                return reply('今後の予約はありません。');
            }

            const MAX_ITEMS = 10;
            const MAX_LENGTH = 4096;
            let description = '';
            let omittedCount = 0;

            for (let i = 0; i < reservations.length; i++) {
                if (i >= MAX_ITEMS) { omittedCount = reservations.length - i; break; }
                const res = reservations[i];
                const start = new Date(res.start_at);
                const end = new Date(res.end_at);
                const dateStr = start.toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric', weekday: 'short' });
                const timeStr = `${start.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })} ~ ${end.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}`;

                let userDisplay = `User ${res.user_id}`;
                if (res.user) {
                    userDisplay = res.user.discord_id ? `<@${res.user.discord_id}>` : (res.user.display_name || res.user.username);
                }

                const entry = `**${dateStr} ${timeStr}**\n${userDisplay}\n📝 ${res.purpose || 'なし'}\n\n`;
                if (description.length + entry.length + 50 > MAX_LENGTH) {
                    omittedCount = reservations.length - i;
                    break;
                }
                description += entry;
            }

            if (omittedCount > 0) description += `...省略: 他 ${omittedCount} 件`;
            return replyEmbed('📅 今後の予約一覧', description);
        } catch (error) {
            console.error(error);
            return reply('予約情報の取得中にエラーが発生しました。');
        }
    },
};
