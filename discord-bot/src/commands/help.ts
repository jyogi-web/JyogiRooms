import { SlashCommandBuilder } from 'discord.js';
import { InteractionResponseType } from 'discord-interactions';
import type { Interaction } from './types.js';
const BOOLEAN_TYPE = 5;

function getBooleanOption(interaction: Interaction, name: string): boolean | null {
    const options = interaction.data.options;
    if (!options) return null;
    const opt = options.find(o => o.name === name && o.type === BOOLEAN_TYPE);
    return (opt?.value as boolean) ?? null;
}

export const helpCommand = {
    data: new SlashCommandBuilder()
        .setName('help')
        .setDescription('コマンドの使い方を表示します')
        .addBooleanOption(option =>
            option
                .setName('public')
                .setDescription('チャンネル全体に表示する（デフォルトは自分だけ）')
                .setRequired(false)
        ),

    async execute(interaction: Interaction): Promise<object> {
        const isPublic = getBooleanOption(interaction, 'public') === true;

        const description = [
            '部室予約・鍵管理Webアプリ「JyogiRooms」の一部機能をDiscordから利用できるBotです。',
            '',
            '### 📅 予約関連',
            '`/list` — 今後の予約一覧を表示（最大10件）',
            '`/check` — 指定した日の予約を確認',
            '　　`preset`: 今日 / 明日 から選択',
            '　　`date`: 日付を直接指定（例: `11/23`, `2026/01/01`）',
            '`/create` — 予約を新規作成（※Webアプリへのログインが必要）',
            '　　`date`: 日付（例: `12/25`, `today`）',
            '　　`start`: 開始時刻（例: `10:00`, `10`）',
            '　　`end`: 終了時刻（例: `12:00`, `12`）',
            '　　`purpose`: 利用目的（任意）',
            '',
            '### 🚪 部室管理',
            '`/open` — 部室を開室（鍵持ち/管理者）',
            '　　`room`: 部室番号（例: `1`, `2`, `3`）',
            '`/close` — 部室を閉室（鍵持ち/管理者、`all`は管理者のみ）',
            '　　`room`: 部室番号 または `all`（全部室を閉室）',
            '`/enter` — 部室に入室',
            '　　`room`: 部室番号（例: `1`, `2`, `3`）',
            '`/exit` — 部室から退室',
            '　　`room`: 部室番号（例: `1`, `2`, `3`）',
            '`/status` — 部室の状況を確認',
            '　　`room`: 部室番号 または `all`（省略時も全部室）',
            '',
            '### 🔑 鍵管理',
            '`/key` — 各部室の鍵持ち一覧を表示',
            '　　`room`: 部室番号を指定すると、その部室のみ表示',
            '`/call` — 指定した部室の鍵持ちをメンションして通知',
            '　　`room`: 部室番号（例: `1`, `2`, `3`）',
            '',
            '### 🌐 Webアプリ',
            '予約の編集・削除、鍵の受け渡しなど、より詳細な操作はWebアプリをご利用ください',
            'https://jyogi-rooms.jyogi.net',
            '',
            '### ❓ その他',
            '`/help` — このヘルプを表示',
            '　　`public`: `True`でチャンネル全体に表示',
        ].join('\n');

        return {
            type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
            data: {
                embeds: [{
                    title: '📖 JyogiRooms Bot ヘルプ',
                    description,
                    color: 0x0099ff,
                }],
                ...(isPublic ? {} : { flags: 64 }),
            },
        };
    },
};
