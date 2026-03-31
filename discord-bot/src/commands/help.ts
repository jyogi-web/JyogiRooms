import { InteractionResponseType } from 'discord-interactions';
import type { Interaction, CommandEnv } from './types.js';
const BOOLEAN_TYPE = 5;

function getBooleanOption(interaction: Interaction, name: string): boolean | null {
    const options = interaction.data.options;
    if (!options) return null;
    const opt = options.find(o => o.name === name && o.type === BOOLEAN_TYPE);
    return (opt?.value as boolean) ?? null;
}

export const helpCommand = {
    data: {
        name: 'help',
        description: 'コマンドの使い方を表示します',
    },

    async execute(interaction: Interaction, _env: CommandEnv): Promise<object> {
        const isPublic = getBooleanOption(interaction, 'public') === true;

        const description = [
            'Webアプリ「JyogiRooms」の一部機能をDiscordから利用できるBotです。',
            '',
            '`*` = 入力必須',
            '',
            '### 📅 部室予約',
            '`/list` — 今後の予約一覧を表示（最大10件）',
            '`/check` — 指定した日の予約を確認',
            '　　`preset` 今日 / 明日 から選択',
            '　　`date` 日付を直接指定（例: `11/23`, `2026/01/01`）',
            '`/reserve` — 予約を新規作成（※Webアプリへのログインが必要）',
            '　　*`date` 日付（例: `12/25`, `today`）',
            '　　*`start` 開始時刻（例: `10:00`, `10`）',
            '　　*`end` 終了時刻（例: `12:00`, `12`）',
            '　　`purpose` 利用目的',
            '',
            '### 🚪 部室状況',
            '`/status` — 部室の状況を確認',
            '　　`room` 部室番号（省略時は全部室）',
            '',
            '### 🔑 鍵管理',
            '`/key` — 各部室の鍵持ち一覧を表示',
            '　　`room` 部室番号（省略時は全部室）',
            '`/call` — 指定した部室の鍵持ちをメンションして通知',
            '　　*`room` 部室番号（`1` / `2` / `3`）',
            '',
            '### 📊 統計・ランキング',
            '`/me` — 自分の部室利用統計を表示',
            '　　`year` 年度（例: `2025`, `all`／デフォルト: 今年度）',
            '`/rank` — 部室の訪問日数・滞在時間ランキングを表示',
            '　　`type` 訪問日数 / 滞在時間（デフォルト: 訪問日数）',
            '　　`year` 年度（例: `2025`, `2026`／デフォルト: 今年度）',
            '　　`room` 部室番号（省略時は全部室）',
            '',
            '### 🌐 Webアプリ',
            '予約の編集・削除、鍵の受け渡しなど、より詳細な操作はWebアプリをご利用ください',
            'https://rooms.jyogi.net',
            '',
            '### ❓ その他',
            '`/help` — このヘルプを表示',
            '　　`public` `True` で全員に表示（デフォルト: 自分のみ）',
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
