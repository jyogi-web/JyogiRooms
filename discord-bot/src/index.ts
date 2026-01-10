// src/index.ts
import 'dotenv/config';
import { Client, GatewayIntentBits } from 'discord.js';

const token = process.env.DISCORD_BOT_TOKEN;

if (!token) {
  console.error('Error: DISCORD_BOT_TOKEN is not set');
  process.exit(1);
}

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
  ],
});

client.once('ready', () => {
  if (!client.user) {
    console.error('Client user is null on ready event');
    process.exit(1);
  }
  console.log(`Logged in as ${client.user.tag}`);
});

client.login(token).catch((error: unknown) => {
  console.error('Failed to login to Discord:', error);
  process.exit(1);
});
