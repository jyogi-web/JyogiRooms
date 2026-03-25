// src/index.ts
import 'dotenv/config';
import { server } from "./server.js";

// =====================
// Environment variables
// =====================
const token = process.env.DISCORD_BOT_TOKEN;
if (!token) {
  console.error('❌ DISCORD_BOT_TOKEN is not set');
  process.exit(1);
}

const publicKey = process.env.DISCORD_PUBLIC_KEY;
if (!publicKey) {
  console.error('❌ DISCORD_PUBLIC_KEY is not set');
  process.exit(1);
}

console.log('🤖 Discord bot started (HTTP Interactions mode)');

// =====================
// Graceful shutdown (Cloud Run 対応)
// =====================
const shutdown = async (signal: string) => {
  console.log(`🛑 Received ${signal}. Shutting down...`);

  try {
    await new Promise<void>((resolve) => {
      server.close(() => {
        console.log('🌐 HTTP server closed');
        resolve();
      });
    });
  } catch (err) {
    console.error('⚠️ Error during shutdown:', err);
  } finally {
    process.exit(0);
  }
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
