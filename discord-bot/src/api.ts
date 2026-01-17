import 'dotenv/config';

// Rails API Base URL
const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000/api';

export interface Reservation {
    id: number;
    user_id: number;
    start_at: string;
    end_at: string;
    // user information loaded via includes
    user?: {
        id: number;
        username: string;
        display_name: string;
        discord_id?: string;
    };
}

export const api = {
    /**
     * 予約一覧を取得する
     * @param startFrom この日時以降の予約を取得 (ISOString)
     * @returns 予約の配列
     */
    async fetchReservations(startFrom?: string): Promise<Reservation[]> {
        const url = new URL(`${API_BASE_URL}/reservations`);

        if (startFrom) {
            url.searchParams.append('start_from', startFrom);
        }

        try {
            const response = await fetch(url.toString());
            if (!response.ok) {
                console.error(`API Error: ${response.status} ${response.statusText}`);
                return [];
            }
            return await response.json() as Reservation[];
        } catch (error) {
            console.error('Fetch Error:', error);
            return [];
        }
    }
};
