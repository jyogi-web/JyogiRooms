import { SlashCommandBuilder } from 'discord.js';
import { InteractionResponseType } from 'discord-interactions';
import type { Interaction } from './types.js';

export const helpCommand = {
    data: new SlashCommandBuilder()
        .setName('help')
        .setDescription('コマンドの使い方を表示します'),

    async execute(_interaction: Interaction): Promise<object> {
        const description = [
            '### 📅 予約関連',
            '`/list` — 今後の予約一覧を表示（最大10件）',
            '`/check` — 指定した日の予約を確認',
            '　　`preset`: 今日 / 明日 から選択',
            '　　`date`: 日付を直接指定（例: `11/23`, `2026/01/01`）',
            '`/create` — 予約を新規作成',
            '　　`date`: 日付（例: `12/25`, `today`）',
            '　　`start`: 開始時刻（例: `10:00`, `10`）',
            '　　`end`: 終了時刻（例: `12:00`, `12`）',
            '　　`purpose`: 利用目的（任意）',
            '',
            '### 🔑 鍵管理',
            '`/key` — 各部室の鍵持ち一覧を表示',
            '',
            '### ❓ その他',
            '`/help` — このヘルプを表示',
        ].join('\n');

        return {
            type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
            data: {
                embeds: [{
                    title: '📖 JyogiRooms Bot ヘルプ',
                    description,
                    color: 0x0099ff,
                }],
                flags: 64,
            },
        };
    },
};
