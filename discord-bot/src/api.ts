import 'dotenv/config';

// Rails API Base URL
const API_BASE_URL = (process.env.API_BASE_URL || 'http://localhost:3000/api').replace(/\/+$/, '');
const API_TIMEOUT_MS = 45000; // Cloud Runのコールドスタート(約30秒)を考慮

function roomActionUrls(path: string): URL[] {
    const urls = [new URL(`${API_BASE_URL}${path}`)];

    try {
        const parsed = new URL(API_BASE_URL);
        const pathname = parsed.pathname.replace(/\/+$/, '');

        if (pathname) {
            urls.push(new URL(`${parsed.origin}${path}`));
        }

        urls.push(new URL(`${parsed.origin}/api${path}`));

        if (!pathname.endsWith('/api')) {
            urls.push(new URL(`${API_BASE_URL}/api${path}`));
        }
    } catch {
        // ignore invalid base url parse here and rely on primary URL
    }

    const seen = new Set<string>();
    return urls.filter((url) => {
        const key = url.toString();
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
    });
}

export class ApiError extends Error {
    constructor(
        message: string,
        public readonly status: number,
        public readonly validationErrors: string[]
    ) {
        super(message);
        this.name = 'ApiError';
    }
}

export interface Reservation {
    id: number;
    user_id: number;
    start_at: string;
    end_at: string;
    purpose: string;
    // user information loaded via includes
    user?: {
        id: number;
        username: string;
        display_name: string;
        discord_id?: string;
        avatar_url?: string;
    };
}

export interface KeyHolder {
    id: number;
    username: string;
    display_name: string;
    discord_id?: string;
}

export interface KeyInfo {
    id: number;
    holder: KeyHolder | null;
}

export interface RoomKeys {
    room_id: number;
    room_name: string;
    room_number: string;
    keys: KeyInfo[];
}

export interface UserInfo {
    id: number;
    discord_id?: string;
    display_name: string;
    is_admin: boolean;
}

export interface RoomActionResponse {
    action: string;
    user: { id: number; display_name: string };
    room: { id: number; name: string };
    timestamp: string;
}

export interface RoomOccupant {
    id: number;
    display_name: string;
    entered_at: string;
}

export interface RoomStatus {
    room: { id: number; name: string };
    is_open: boolean;
    opened_at: string | null;
    opened_by: { id: number; display_name: string } | null;
    occupants: RoomOccupant[];
    occupant_count: number;
}

export const api = {
    /**
     * 予約一覧を取得する
     * @param startFrom この日時以降の予約を取得 (ISOString)
     * @returns 予約の配列
     */
    async fetchReservations(startFrom?: string, endTo?: string): Promise<Reservation[]> {
        const url = new URL(`${API_BASE_URL}/reservations`);

        if (startFrom) {
            url.searchParams.append('start_from', startFrom);
        }
        if (endTo) {
            url.searchParams.append('end_to', endTo);
        }

        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

        try {
            const headers = {
                'X-Api-Key': process.env.API_ACCESS_TOKEN || ''
            };
            const response = await fetch(url.toString(), { signal: controller.signal, headers });

            if (!response.ok) {
                throw new Error(`API Error: ${response.status} ${response.statusText}`);
            }

            return await response.json() as Reservation[];
        } finally {
            clearTimeout(timeoutId);
        }
    },

    /**
     * 各部室の鍵持ち情報を取得する
     * @returns 部室ごとの鍵情報の配列
     */
    async fetchKeys(): Promise<RoomKeys[]> {
        const urls = roomActionUrls('/keys');
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

        try {
            const headers = {
                'X-Api-Key': process.env.API_ACCESS_TOKEN || ''
            };
            let lastError: Error | null = null;

            for (const [index, url] of urls.entries()) {
                const response = await fetch(url.toString(), { signal: controller.signal, headers });

                if (response.ok) {
                    return await response.json() as RoomKeys[];
                }

                lastError = new Error(`API Error: ${response.status} ${response.statusText}`);
                const isLastCandidate = index === urls.length - 1;
                if (response.status !== 404 || isLastCandidate) {
                    throw lastError;
                }
            }

            throw lastError ?? new Error('API Error: request failed');
        } finally {
            clearTimeout(timeoutId);
        }
    },

    /**
     * 予約を作成する
     * @param reservation 予約情報
     * @param discordUserId DiscordユーザーID (ユーザー特定用)
     * @returns 作成された予約
     */
    async createReservation(reservation: { start_at: string; end_at: string; purpose?: string }, discordUserId?: string): Promise<Reservation> {
        const url = new URL(`${API_BASE_URL}/reservations`);
        const headers = {
            'X-Api-Key': process.env.API_ACCESS_TOKEN || '',
            'Content-Type': 'application/json'
        };
        const body = JSON.stringify({
            reservation,
            discord_user_id: discordUserId
        });

        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

        try {
            const response = await fetch(url.toString(), {
                method: 'POST',
                headers,
                body,
                signal: controller.signal
            });

            if (!response.ok) {
                let errorBody: any = null;
                try {
                    errorBody = await response.json();
                } catch {
                    // ignore json parse error
                }

                const err = new ApiError(
                    `API Error: ${response.status} ${response.statusText}`,
                    response.status,
                    errorBody?.errors || (errorBody?.error ? [errorBody.error] : [])
                );
                throw err;
            }

            return await response.json() as Reservation;
        } finally {
            clearTimeout(timeoutId);
        }
    },

    /**
     * 部室を開室する
     */
    async openRoom(roomId: number, discordUserId: string): Promise<RoomActionResponse> {
        return this.postRoomAction(`/rooms/${roomId}/open`, discordUserId);
    },

    /**
     * 部室を閉室する
     */
    async closeRoom(roomId: number, discordUserId: string): Promise<RoomActionResponse> {
        return this.postRoomAction(`/rooms/${roomId}/close`, discordUserId);
    },

    /**
     * 入室する
     */
    async enterRoom(roomId: number, discordUserId: string): Promise<RoomActionResponse> {
        return this.postRoomAction(`/rooms/${roomId}/enter`, discordUserId);
    },

    /**
     * 退室する（部室指定）
     */
    async exitRoom(roomId: number, discordUserId: string): Promise<RoomActionResponse> {
        return this.postRoomAction(`/rooms/${roomId}/exit`, discordUserId);
    },

    /**
     * 退室する（現在入室中の部室から自動退室）
     */
    async exitCurrent(discordUserId: string): Promise<RoomActionResponse> {
        return this.postRoomAction('/exit', discordUserId);
    },

    /**
     * 部室状況を取得する
     */
    async fetchRoomStatus(roomId: number): Promise<RoomStatus> {
        const urls = roomActionUrls(`/rooms/${roomId}/status`);
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

        try {
            const headers = {
                'X-Api-Key': process.env.API_ACCESS_TOKEN || ''
            };
            let lastError: Error | null = null;

            for (const [index, url] of urls.entries()) {
                const response = await fetch(url.toString(), { signal: controller.signal, headers });

                if (response.ok) {
                    return await response.json() as RoomStatus;
                }

                lastError = new Error(`API Error: ${response.status} ${response.statusText}`);
                const isLastCandidate = index === urls.length - 1;
                if (response.status !== 404 || isLastCandidate) {
                    throw lastError;
                }
            }

            throw lastError ?? new Error('API Error: request failed');
        } finally {
            clearTimeout(timeoutId);
        }
    },

    /**
     * Discord IDでユーザー情報を取得する
     */
    async fetchUserByDiscordId(discordUserId: string): Promise<UserInfo | null> {
        const urls = roomActionUrls('/users');
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

        try {
            const headers = {
                'X-Api-Key': process.env.API_ACCESS_TOKEN || ''
            };
            let lastError: Error | null = null;

            for (const [index, url] of urls.entries()) {
                const response = await fetch(url.toString(), { signal: controller.signal, headers });

                if (response.ok) {
                    const data = await response.json() as { users?: UserInfo[] } | UserInfo[];
                    const users = Array.isArray(data) ? data : data.users;
                    if (!Array.isArray(users)) {
                        throw new Error('API Error: users response format is invalid');
                    }
                    return users.find(u => u.discord_id === discordUserId) ?? null;
                }

                lastError = new Error(`API Error: ${response.status} ${response.statusText}`);
                const isLastCandidate = index === urls.length - 1;
                if (response.status !== 404 || isLastCandidate) {
                    throw lastError;
                }
            }

            throw lastError ?? new Error('API Error: request failed');
        } finally {
            clearTimeout(timeoutId);
        }
    },

    /**
     * 部室操作の共通POSTメソッド
     */
    async postRoomAction(path: string, discordUserId: string): Promise<RoomActionResponse> {
        const urls = roomActionUrls(path);
        const headers = {
            'X-Api-Key': process.env.API_ACCESS_TOKEN || '',
            'Content-Type': 'application/json'
        };
        const body = JSON.stringify({ discord_user_id: discordUserId });

        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

        try {
            let lastError: ApiError | null = null;

            for (const [index, url] of urls.entries()) {
                const response = await fetch(url.toString(), {
                    method: 'POST',
                    headers,
                    body,
                    signal: controller.signal
                });

                if (response.ok) {
                    return await response.json() as RoomActionResponse;
                }

                let errorBody: any = null;
                try {
                    errorBody = await response.json();
                } catch {
                    // ignore json parse error
                }

                lastError = new ApiError(
                    `API Error: ${response.status} ${response.statusText}`,
                    response.status,
                    errorBody?.errors || (errorBody?.error ? [errorBody.error] : [])
                );

                const isLastCandidate = index === urls.length - 1;
                if (response.status !== 404 || isLastCandidate) {
                    throw lastError;
                }
            }

            throw lastError ?? new ApiError('API Error: request failed', 500, []);
        } finally {
            clearTimeout(timeoutId);
        }
    }
};
