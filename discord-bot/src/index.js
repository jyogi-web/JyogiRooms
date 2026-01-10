// src/index.js
import 'dotenv/config';
import { Client, GatewayIntentBits } from 'discord.js';

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
  ],
});

client.once('ready', () => {
  console.log(`Logged in as ${client.user.tag}`);
});

client.login(process.env.DISCORD_BOT_TOKEN)
  .catch((error) => {
    console.error('Failed to login to Discord:', error);
    console.error('DISCORD_BOT_TOKEN is', process.env.DISCORD_BOT_TOKEN ? 'present' : 'missing');
    process.exit(1);
  });
