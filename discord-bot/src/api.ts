import 'dotenv/config';

// Rails API Base URL
const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000/api';

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
        const timeoutId = setTimeout(() => controller.abort(), 5000); // 5 second timeout

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
     * 予約を作成する
     * @param reservation 予約情報
     * @param discordUserId DiscordユーザーID (ユーザー特定用)
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

        const response = await fetch(url.toString(), {
            method: 'POST',
            headers,
            body
        });

        if (!response.ok) {
            // Try to read error message from body if possible, otherwise use status text
            let errorMessage = `API Error: ${response.status} ${response.statusText}`;
            try {
                const errorBody = await response.json();
                if (errorBody && errorBody.error) {
                    errorMessage += ` - ${errorBody.error}`;
                } else if (errorBody && errorBody.errors) {
                    errorMessage += ` - ${JSON.stringify(errorBody.errors)}`;
                }
            } catch (e) {
                // ignore json parse error
            }
            throw new Error(errorMessage);
        }

        return await response.json() as Reservation;
    }
};
