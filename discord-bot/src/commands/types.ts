export interface InteractionOption {
    name: string;
    type: number;
    value?: string | number | boolean;
    options?: InteractionOption[];
}

export interface InteractionData {
    name: string;
    options?: InteractionOption[];
}

export interface InteractionUser {
    id: string;
}

export interface InteractionMember {
    user: InteractionUser;
}

export interface Interaction {
    type: number;
    data: InteractionData;
    member?: InteractionMember;
    user?: InteractionUser;
    token: string;
    id: string;
}

export interface CommandEnv {
    API_BASE_URL: string;
    API_ACCESS_TOKEN: string;
    // 閲覧ログ取り込み Worker への Service Binding（未設定なら記録は no-op）
    VIEW_LOG?: Fetcher;
    INGEST_SHARED_SECRET?: string;
}

export interface Command {
    data: { name: string; description: string };
    // ctx はバックグラウンド処理（ctx.waitUntil）用。応答をブロックせず閲覧ログ等を送るのに使う。
    execute(interaction: Interaction, env: CommandEnv, ctx?: ExecutionContext): Promise<object>;
}
