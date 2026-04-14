import { verifyKey } from 'discord-interactions';
import { InteractionType, InteractionResponseType } from 'discord-interactions';
import { commands } from './commands/index.js';
import { isEphemeral, EPHEMERAL_FLAG } from './commands/utils.js';

export interface Env {
	DISCORD_PUBLIC_KEY: string;
	DISCORD_CLIENT_ID: string;
	DISCORD_BOT_TOKEN: string;
	API_ACCESS_TOKEN: string;
	API_BASE_URL: string;
}

const DIRECT_RESPONSE_TIMEOUT_MS = 2500;

function jsonResponse(status: number, data: object): Response {
	return new Response(JSON.stringify(data), {
		status,
		headers: { 'Content-Type': 'application/json' },
	});
}

async function sendFollowup(clientId: string, interactionToken: string, data: object) {
	try {
		const url = `https://discord.com/api/v10/webhooks/${clientId}/${interactionToken}/messages/@original`;
		const response = await fetch(url, {
			method: 'PATCH',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify(data),
		});
		if (!response.ok) {
			console.error('Follow-up failed:', response.status, await response.text());
		}
	} catch (error) {
		console.error('Follow-up request error:', error);
	}
}

async function handleInteraction(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
	const signature = request.headers.get('x-signature-ed25519') || '';
	const timestamp = request.headers.get('x-signature-timestamp') || '';
	const rawBody = await request.text();

	const isValid = await verifyKey(rawBody, signature, timestamp, env.DISCORD_PUBLIC_KEY);
	if (!isValid) {
		return new Response('Invalid request signature', { status: 401 });
	}

	const interaction = JSON.parse(rawBody);

	// PING — Discord疎通確認
	if (interaction.type === InteractionType.PING) {
		return jsonResponse(200, { type: InteractionResponseType.PONG });
	}

	// APPLICATION_COMMAND — スラッシュコマンド
	if (interaction.type === InteractionType.APPLICATION_COMMAND) {
		const command = commands.find(c => c.data.name === interaction.data.name);

		if (!command) {
			// 不明なコマンドは常にephemeral（コマンドが存在しないためpublicオプションを取得できない）
			return jsonResponse(200, {
				type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
				data: { content: '不明なコマンドです。', flags: EPHEMERAL_FLAG },
			});
		}

		const ephemeral = isEphemeral(interaction);
		const commandPromise = command.execute(interaction, env).catch((error: unknown) => {
			console.error('Command execution error:', error);
			return {
				type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
				data: {
					content: 'コマンドの実行中にエラーが発生しました。',
					...(ephemeral ? { flags: EPHEMERAL_FLAG } : {}),
				},
			};
		});

		const timeoutPromise = new Promise<'timeout'>((resolve) => {
			setTimeout(() => resolve('timeout'), DIRECT_RESPONSE_TIMEOUT_MS);
		});

		const result = await Promise.race([commandPromise, timeoutPromise]);

		if (result === 'timeout') {
			// Deferredレスポンスを返し、フォローアップをバックグラウンドで実行
			ctx.waitUntil(
				(async () => {
					const response = await commandPromise as any;
					// PATCH時はflagsを除去（Discord仕様：初期レスポンスのflagsのみ有効）
					const { flags: _flags, ...followupData } = response.data || {};
					if (!followupData.content && !followupData.embeds) {
						followupData.content = 'コマンドを実行しました。';
					}
					await sendFollowup(env.DISCORD_CLIENT_ID, interaction.token, followupData);
				})()
			);

			return jsonResponse(200, {
				type: InteractionResponseType.DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE,
				...(ephemeral ? { data: { flags: EPHEMERAL_FLAG } } : {}),
			});
		}

		return jsonResponse(200, result);
	}

	return new Response('Unknown interaction type', { status: 400 });
}

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		const url = new URL(request.url);

		if (request.method === 'GET' && url.pathname === '/health') {
			return new Response('OK', { status: 200 });
		}

		if (request.method === 'POST' && url.pathname === '/interactions') {
			try {
				return await handleInteraction(request, env, ctx);
			} catch (error) {
				console.error('Interaction handling error:', error);
				return new Response('Internal Server Error', { status: 500 });
			}
		}

		return new Response('Not Found', { status: 404 });
	},
};
