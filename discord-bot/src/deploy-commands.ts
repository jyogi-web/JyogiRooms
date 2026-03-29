import { REST, Routes, SlashCommandBuilder } from 'discord.js';
import 'dotenv/config';

const token = process.env.DISCORD_BOT_TOKEN;
const clientId = process.env.DISCORD_CLIENT_ID;

if (!token) {
    console.error('❌ DISCORD_BOT_TOKEN is not set');
    process.exit(1);
}

if (!clientId) {
    console.error('❌ DISCORD_CLIENT_ID is not set');
    process.exit(1);
}

// コマンド定義（オプション含む）はデプロイ時のみ必要
const commandDefinitions = [
    new SlashCommandBuilder()
        .setName('list')
        .setDescription('今後の予約一覧を表示します'),

    new SlashCommandBuilder()
        .setName('check')
        .setDescription('指定した日の予約を確認します')
        .addStringOption(option =>
            option.setName('preset').setDescription('日付プリセット').setRequired(false)
                .addChoices(
                    { name: '今日 (Today)', value: 'today' },
                    { name: '明日 (Tomorrow)', value: 'tomorrow' }
                )
        )
        .addStringOption(option =>
            option.setName('date').setDescription('日付指定 (例: 11/23, 2025/01/01)').setRequired(false)
        ),

    new SlashCommandBuilder()
        .setName('reserve')
        .setDescription('予約を新規作成します')
        .addStringOption(option =>
            option.setName('date').setDescription('日付 (例: 12/25, 2026/01/01, today)').setRequired(true))
        .addStringOption(option =>
            option.setName('start').setDescription('開始時刻 (例: 13:00, 13)').setRequired(true))
        .addStringOption(option =>
            option.setName('end').setDescription('終了時刻 (例: 14:00, 14)').setRequired(true))
        .addStringOption(option =>
            option.setName('purpose').setDescription('利用目的 (任意)').setRequired(false)),

    new SlashCommandBuilder()
        .setName('key')
        .setDescription('各部室の鍵持ち一覧を表示します')
        .addStringOption(option =>
            option.setName('room').setDescription('部室番号（省略時は全部室を表示）').setRequired(false)
        ),

    new SlashCommandBuilder()
        .setName('call')
        .setDescription('指定した部室の鍵持ちをメンションして通知します')
        .addStringOption(option =>
            option.setName('room').setDescription('部室番号（例: 1, 2, 3）').setRequired(true)
        ),

    new SlashCommandBuilder()
        .setName('help')
        .setDescription('コマンドの使い方を表示します')
        .addBooleanOption(option =>
            option.setName('public').setDescription('チャンネル全体に表示する（デフォルトは自分だけ）').setRequired(false)
        ),

    new SlashCommandBuilder()
        .setName('status')
        .setDescription('部室の状況を確認します')
        .addStringOption(option =>
            option.setName('room').setDescription('部室番号（例: 1, 2, 3）または all（省略時も全部室）').setRequired(false)
        ),

    new SlashCommandBuilder()
        .setName('rank')
        .setDescription('部室の訪問回数・滞在時間ランキングを表示します')
        .addStringOption(option =>
            option.setName('type').setDescription('ランキングの種類').setRequired(false)
                .addChoices(
                    { name: '訪問日数', value: 'visits' },
                    { name: '滞在時間', value: 'duration' }
                )
        )
        .addStringOption(option =>
            option.setName('year').setDescription('年度（例: 2025, 2026, all）').setRequired(false)
        )
        .addStringOption(option =>
            option.setName('room').setDescription('部室番号（1, 2, 3）または all（省略時は全部室）').setRequired(false)
                .addChoices(
                    { name: '全部室', value: 'all' },
                    { name: '部室1', value: '1' },
                    { name: '部室2', value: '2' },
                    { name: '部室3', value: '3' }
                )
        ),
];

const rest = new REST({ version: '10' }).setToken(token);

(async () => {
    try {
        console.log('📦 Started refreshing application (/) commands.');

        const commandData = commandDefinitions.map(command => command.toJSON());

        await rest.put(
            Routes.applicationCommands(clientId),
            { body: commandData },
        );

        console.log('✅ Successfully reloaded application (/) commands.');
    } catch (error) {
        console.error('❌ Error deploying commands:', error);
    }
})();
