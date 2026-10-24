// 閲覧ログ取り込み Worker (view-log-worker) への送信クライアント。
// /status 実行時に「誰がいつ見たか」を記録する。失敗してもコマンド応答には影響させない。
//
// Worker→Worker は Service Binding(env.VIEW_LOG) 経由で呼ぶ。公開 workers.dev URL への
// fetch は Cloudflare error 1042 でブロックされるため。バインディング先の pathname だけが
// ルーティングに使われる（ホスト名は任意）。

export interface ViewLogEnv {
	VIEW_LOG?: Fetcher;
	INGEST_SHARED_SECRET?: string;
}

// 閲覧対象のカテゴリ
export type ViewCategory = 'room_status' | 'ranking' | 'stats';

// Service Binding のルーティングに使う内部URL（ホストは任意・pathname のみ意味を持つ）
const INGEST_URL = 'https://view-log-worker.internal/view-logs';

// Discord 経路の閲覧を記録する。
// 5分窓の重複間引き（throttle）は取り込み Worker 側で行われる。
export async function logDiscordView(env: ViewLogEnv, discordUserId: string, category: ViewCategory): Promise<void> {
	const service = env.VIEW_LOG;
	const secret = env.INGEST_SHARED_SECRET;
	if (!service || !secret) return; // 未設定なら no-op

	try {
		const response = await service.fetch(INGEST_URL, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'X-Ingest-Secret': secret,
			},
			body: JSON.stringify({
				source: 'discord',
				category,
				discord_id: discordUserId,
				viewed_at: new Date().toISOString(),
			}),
		});
		if (!response.ok) {
			console.error('view-log ingest failed:', response.status, await response.text());
		}
	} catch (error) {
		console.error('view-log ingest error:', error);
	}
}
