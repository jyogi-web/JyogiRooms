// Workers環境で必要なenv情報
export interface ApiEnv {
	API_BASE_URL: string;
	API_ACCESS_TOKEN: string;
}

const API_TIMEOUT_MS = 10000; // Workersではコールドスタートがないため短縮

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

export interface MyStatsRoom {
	room_id: number;
	room_name: string;
	visit_days: number;
	total_seconds: number;
}

export interface MyStatsResponse {
	user: { id: number; display_name: string; discord_id?: string };
	year: string;
	total: { visit_days: number; total_seconds: number };
	rooms: MyStatsRoom[];
}

export interface RankingEntry {
	user_id: number;
	display_name: string;
	discord_id?: string;
	count?: number;
	total_seconds?: number;
}

export interface RankingResponse {
	type: string;
	year: string;
	room: string;
	ranking: RankingEntry[];
}

function createApi(env: ApiEnv) {
	const baseUrl = env.API_BASE_URL;
	const apiKey = env.API_ACCESS_TOKEN;

	async function fetchWithTimeout(url: string, options: RequestInit = {}): Promise<Response> {
		const controller = new AbortController();
		const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

		try {
			const response = await fetch(url, {
				...options,
				signal: controller.signal,
				headers: {
					'X-Api-Key': apiKey,
					...options.headers,
				},
			});
			return response;
		} finally {
			clearTimeout(timeoutId);
		}
	}

	async function handleErrorResponse(response: Response): Promise<never> {
		let errorBody: any = null;
		try {
			errorBody = await response.json();
		} catch {
			// ignore json parse error
		}
		throw new ApiError(
			`API Error: ${response.status} ${response.statusText}`,
			response.status,
			errorBody?.errors || (errorBody?.error ? [errorBody.error] : [])
		);
	}

	return {
		async fetchReservations(startFrom?: string, endTo?: string): Promise<Reservation[]> {
			const url = new URL(`${baseUrl}/reservations`);
			if (startFrom) url.searchParams.append('start_from', startFrom);
			if (endTo) url.searchParams.append('end_to', endTo);

			const response = await fetchWithTimeout(url.toString());
			if (!response.ok) await handleErrorResponse(response);
			return await response.json() as Reservation[];
		},

		async fetchKeys(): Promise<RoomKeys[]> {
			const url = new URL(`${baseUrl}/keys`);
			const response = await fetchWithTimeout(url.toString());
			if (!response.ok) await handleErrorResponse(response);
			return await response.json() as RoomKeys[];
		},

		async createReservation(reservation: { start_at: string; end_at: string; purpose?: string }, discordUserId?: string): Promise<Reservation> {
			const url = new URL(`${baseUrl}/reservations`);
			const response = await fetchWithTimeout(url.toString(), {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ reservation, discord_user_id: discordUserId }),
			});
			if (!response.ok) await handleErrorResponse(response);
			return await response.json() as Reservation;
		},

		async openRoom(roomId: number, discordUserId: string): Promise<RoomActionResponse> {
			return this.postRoomAction(`/rooms/${roomId}/open`, discordUserId);
		},

		async closeRoom(roomId: number, discordUserId: string): Promise<RoomActionResponse> {
			return this.postRoomAction(`/rooms/${roomId}/close`, discordUserId);
		},

		async enterRoom(roomId: number, discordUserId: string): Promise<RoomActionResponse> {
			return this.postRoomAction(`/rooms/${roomId}/enter`, discordUserId);
		},

		async exitRoom(roomId: number, discordUserId: string): Promise<RoomActionResponse> {
			return this.postRoomAction(`/rooms/${roomId}/exit`, discordUserId);
		},

		async fetchRoomStatus(roomId: number): Promise<RoomStatus> {
			const url = new URL(`${baseUrl}/rooms/${roomId}/status`);
			const response = await fetchWithTimeout(url.toString());
			if (!response.ok) await handleErrorResponse(response);
			return await response.json() as RoomStatus;
		},

		async fetchUserByDiscordId(discordUserId: string): Promise<UserInfo | null> {
			const url = new URL(`${baseUrl}/users`);
			const response = await fetchWithTimeout(url.toString());
			if (!response.ok) await handleErrorResponse(response);
			const data = await response.json() as { users: UserInfo[] };
			return data.users.find(u => u.discord_id === discordUserId) ?? null;
		},

		async fetchMyStats(discordUserId: string, year?: string): Promise<MyStatsResponse> {
			const url = new URL(`${baseUrl}/stats/me`);
			url.searchParams.append('discord_user_id', discordUserId);
			if (year) url.searchParams.append('year', year);

			const response = await fetchWithTimeout(url.toString());
			if (!response.ok) await handleErrorResponse(response);
			return await response.json() as MyStatsResponse;
		},

		async fetchRanking(type?: string, year?: string, room?: string): Promise<RankingResponse> {
			const url = new URL(`${baseUrl}/stats/ranking`);
			if (type) url.searchParams.append('type', type);
			if (year) url.searchParams.append('year', year);
			if (room) url.searchParams.append('room', room);

			const response = await fetchWithTimeout(url.toString());
			if (!response.ok) await handleErrorResponse(response);
			return await response.json() as RankingResponse;
		},

		async postRoomAction(path: string, discordUserId: string): Promise<RoomActionResponse> {
			const url = new URL(`${baseUrl}${path}`);
			const response = await fetchWithTimeout(url.toString(), {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ discord_user_id: discordUserId }),
			});
			if (!response.ok) await handleErrorResponse(response);
			return await response.json() as RoomActionResponse;
		},
	};
}

export { createApi };
