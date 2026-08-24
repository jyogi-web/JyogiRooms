// 閲覧ログ取り込み Worker (view-log-worker) への送信クライアント。
// /status 実行時に「誰がいつ見たか」を記録する。失敗してもコマンド応答には影響させない。

export interface ViewLogEnv {
	INGEST_URL?: string;
	INGEST_SHARED_SECRET?: string;
}

const VIEW_LOG_TIMEOUT_MS = 5000;

// Discord 経路の閲覧を記録する。
// 5分窓の重複間引き（throttle）は取り込み Worker 側で行われる。
export async function logDiscordView(env: ViewLogEnv, discordUserId: string): Promise<void> {
	const url = env.INGEST_URL;
	const secret = env.INGEST_SHARED_SECRET;
	if (!url || !secret) return; // 未設定なら no-op

	const controller = new AbortController();
	const timeoutId = setTimeout(() => controller.abort(), VIEW_LOG_TIMEOUT_MS);

	try {
		const response = await fetch(url, {
			method: 'POST',
			signal: controller.signal,
			headers: {
				'Content-Type': 'application/json',
				'X-Ingest-Secret': secret,
			},
			body: JSON.stringify({
				source: 'discord',
				discord_id: discordUserId,
				viewed_at: new Date().toISOString(),
			}),
		});
		if (!response.ok) {
			console.error('view-log ingest failed:', response.status, await response.text());
		}
	} catch (error) {
		console.error('view-log ingest error:', error);
	} finally {
		clearTimeout(timeoutId);
	}
}
