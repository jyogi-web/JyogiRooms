import { createServer, IncomingMessage, ServerResponse } from 'http';
import { timingSafeEqual } from 'crypto';
import { verifyKey } from 'discord-interactions';
import { InteractionType, InteractionResponseType } from 'discord-interactions';
import { commands } from './commands/index.js';
import { handleNotification } from './notifier.js';

const port = Number(process.env.PORT) || 3000;
const DISCORD_PUBLIC_KEY = process.env.DISCORD_PUBLIC_KEY || '';
const DISCORD_CLIENT_ID = process.env.DISCORD_CLIENT_ID || '';

if (!DISCORD_PUBLIC_KEY) {
  console.error('❌ DISCORD_PUBLIC_KEY is not set');
  process.exit(1);
}

if (!DISCORD_CLIENT_ID) {
  console.error('❌ DISCORD_CLIENT_ID is not set');
  process.exit(1);
}

const DIRECT_RESPONSE_TIMEOUT_MS = 2500; // 3秒制限に余裕を持たせる

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => resolve(body));
    req.on('error', reject);
  });
}

function jsonResponse(res: ServerResponse, status: number, data: object) {
  const json = JSON.stringify(data);
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(json);
}

async function sendFollowup(interactionToken: string, data: object) {
  try {
    const url = `https://discord.com/api/v10/webhooks/${DISCORD_CLIENT_ID}/${interactionToken}/messages/@original`;
    const response = await fetch(url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!response.ok) {
      console.error('❌ Follow-up failed:', response.status, await response.text());
    }
  } catch (error) {
    console.error('❌ Follow-up request error:', error);
  }
}

async function handleInteraction(req: IncomingMessage, res: ServerResponse) {
  const signature = req.headers['x-signature-ed25519'] as string;
  const timestamp = req.headers['x-signature-timestamp'] as string;
  const rawBody = await readBody(req);

  // Discord署名検証
  const isValid = await verifyKey(rawBody, signature, timestamp, DISCORD_PUBLIC_KEY);
  if (!isValid) {
    res.writeHead(401);
    res.end('Invalid request signature');
    return;
  }

  const interaction = JSON.parse(rawBody);

  // PING — Discordからの疎通確認
  if (interaction.type === InteractionType.PING) {
    jsonResponse(res, 200, { type: InteractionResponseType.PONG });
    return;
  }

  // APPLICATION_COMMAND — スラッシュコマンド
  if (interaction.type === InteractionType.APPLICATION_COMMAND) {
    const command = commands.find(c => c.data.name === interaction.data.name);

    if (!command) {
      jsonResponse(res, 200, {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: { content: '不明なコマンドです。', flags: 64 },
      });
      return;
    }

    // コマンド実行とタイムアウトを競争させる
    const commandPromise = command.execute(interaction).catch((error: unknown) => {
      console.error('Command execution error:', error);
      return {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: { content: 'コマンドの実行中にエラーが発生しました。' },
      };
    });

    const timeoutPromise = new Promise<'timeout'>((resolve) => {
      setTimeout(() => resolve('timeout'), DIRECT_RESPONSE_TIMEOUT_MS);
    });

    const result = await Promise.race([commandPromise, timeoutPromise]);

    if (result === 'timeout') {
      // 2.5秒以内に完了しなかった → Deferredレスポンスを返す
      jsonResponse(res, 200, {
        type: InteractionResponseType.DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE,
      });

      // コマンド完了を待ってフォローアップ送信
      const response = await commandPromise as any;
      await sendFollowup(interaction.token, response.data || { content: 'コマンドを実行しました。' });
    } else {
      // 時間内に完了 → 直接レスポンス
      jsonResponse(res, 200, result);
    }

    return;
  }

  // 未対応のInteractionタイプ
  res.writeHead(400);
  res.end('Unknown interaction type');
}

export const server = createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('OK');
    return;
  }

  if (req.method === 'POST' && req.url === '/notify') {
    const apiKey = req.headers['x-api-key'] as string || '';
    const expectedKey = process.env.DISCORD_NOTIFY_API_KEY || '';
    const isValidKey = expectedKey.length > 0 &&
      apiKey.length === expectedKey.length &&
      timingSafeEqual(Buffer.from(apiKey), Buffer.from(expectedKey));
    if (!isValidKey) {
      res.writeHead(401);
      res.end('Unauthorized');
      return;
    }

    let body: any;
    try {
      body = JSON.parse(await readBody(req));
    } catch {
      jsonResponse(res, 400, { error: 'Invalid JSON' });
      return;
    }

    try {
      await handleNotification(body);
      jsonResponse(res, 200, { ok: true });
    } catch (error) {
      console.error('Notification handling error:', error);
      jsonResponse(res, 500, { error: 'Internal Server Error' });
    }
    return;
  }

  if (req.method === 'POST' && req.url === '/interactions') {
    try {
      await handleInteraction(req, res);
    } catch (error) {
      console.error('Interaction handling error:', error);
      res.writeHead(500);
      res.end('Internal Server Error');
    }
    return;
  }

  res.writeHead(404);
  res.end();
});

server.listen(port, () => {
  console.log(`🌐 Server listening on port ${port}`);
}).on('error', (err) => {
  console.error('❌ Failed to start server:', err);
  process.exit(1);
});
