// src/index.ts
import 'dotenv/config';
import { Client, GatewayIntentBits } from 'discord.js';
import { createServer } from 'http';
// =====================
// Environment variables
// =====================
const token = process.env.DISCORD_BOT_TOKEN;
if (!token) {
    console.error('❌ DISCORD_BOT_TOKEN is not set');
    process.exit(1);
}
const port = Number(process.env.PORT) || 3000;
// =====================
// Health check HTTP server (for Koyeb)
// =====================
const server = createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('OK');
        return;
    }
    res.writeHead(404);
    res.end();
});
server.listen(port, () => {
    console.log(`🌐 Health check server listening on port ${port}`);
});
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
});
client.login(token).catch((error) => {
    console.error('❌ Failed to login to Discord:', error);
    process.exit(1);
});
// =====================
// Graceful shutdown (Koyeb / Cloud Run 対応)
// =====================
const shutdown = async (signal) => {
    console.log(`🛑 Received ${signal}. Shutting down...`);
    try {
        server.close(() => {
            console.log('🌐 HTTP server closed');
        });
        await client.destroy();
        console.log('🤖 Discord client destroyed');
    }
    catch (err) {
        console.error('⚠️ Error during shutdown:', err);
    }
    finally {
        process.exit(0);
    }
};
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
