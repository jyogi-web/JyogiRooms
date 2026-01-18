// src/index.ts
import 'dotenv/config';
import { Client, GatewayIntentBits } from 'discord.js';
import { startHealthCheckCron, stopHealthCheckCron } from "./cron.js";
import { server } from "./server.js";
import { startLockAnnounceCron, stopLockAnnounceCron } from "./lockAnnounce.js";
import { commands } from './commands/index.js';
import { Events } from 'discord.js';

// =====================
// Environment variables
// =====================
const token = process.env.DISCORD_BOT_TOKEN;
if (!token) {
  console.error('❌ DISCORD_BOT_TOKEN is not set');
  process.exit(1);
}

// =====================
// Discord client
// =====================
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    // 必要になったら追加
    // GatewayIntentBits.GuildMessages,
  ],
});

client.once('ready', () => {
  if (!client.user) {
    console.error('❌ Client user is null on ready event');
    process.exit(1);
  }

  console.log(`🤖 Logged in as ${client.user.tag}`);
  startLockAnnounceCron(client);
});

client.on(Events.InteractionCreate, async interaction => {
  if (!interaction.isChatInputCommand()) return;

  const command = commands.find(c => c.data.name === interaction.commandName);

  if (!command) {
    console.error(`No command matching ${interaction.commandName} was found.`);
    await interaction.reply({ content: '不明なコマンドです。', ephemeral: true });
    return;
  }

  try {
    await command.execute(interaction);
  } catch (error) {
    console.error(error);
    if (interaction.replied || interaction.deferred) {
      await interaction.followUp({ content: 'コマンドの実行中にエラーが発生しました。', ephemeral: true });
    } else {
      await interaction.reply({ content: 'コマンドの実行中にエラーが発生しました。', ephemeral: true });
    }
  }
});

client.login(token).catch((error) => {
  console.error('❌ Failed to login to Discord:', error);
  process.exit(1);
});

startHealthCheckCron();

// =====================
// Graceful shutdown (Koyeb / Cloud Run 対応)
// =====================
const shutdown = async (signal: string) => {
  console.log(`🛑 Received ${signal}. Shutting down...`);

  stopHealthCheckCron();
  stopLockAnnounceCron();

  try {
    await new Promise<void>((resolve) => {
      server.close(() => {
        console.log('🌐 HTTP server closed');
        resolve();
      });
    });

    client.destroy();
    console.log('🤖 Discord client destroyed');
  } catch (err) {
    console.error('⚠️ Error during shutdown:', err);
  } finally {
    process.exit(0);
  }
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
