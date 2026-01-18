import { REST, Routes } from 'discord.js';
import 'dotenv/config';
import { commands } from './commands/index.js';

// 環境変数のチェック
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

const rest = new REST({ version: '10' }).setToken(token);

(async () => {
    try {
        console.log('📦 Started refreshing application (/) commands.');

        const commandData = commands.map(command => command.data.toJSON());

        await rest.put(
            Routes.applicationCommands(clientId),
            { body: commandData },
        );

        console.log('✅ Successfully reloaded application (/) commands.');
    } catch (error) {
        console.error('❌ Error deploying commands:', error);
    }
})();
