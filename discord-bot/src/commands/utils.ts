import { InteractionResponseType } from 'discord-interactions';
import type { Interaction } from './types.js';

export const STRING_TYPE = 3;
export const INTEGER_TYPE = 4;
export const BOOLEAN_TYPE = 5;
export const EPHEMERAL_FLAG = 64;

export function getBooleanOption(interaction: Interaction, name: string): boolean | null {
    const options = interaction.data.options;
    if (!options) return null;
    const opt = options.find(o => o.name === name && o.type === BOOLEAN_TYPE);
    return (opt?.value as boolean) ?? null;
}

// public=false のときのみ ephemeral（デフォルト/未指定は全員表示）
export function isEphemeral(interaction: Interaction): boolean {
    return getBooleanOption(interaction, 'public') === false;
}

export function getStringOption(interaction: Interaction, name: string): string | null {
    const options = interaction.data.options;
    if (!options) return null;
    const opt = options.find(o => o.name === name && o.type === STRING_TYPE);
    return (opt?.value as string) ?? null;
}

export function getIntegerOption(interaction: Interaction, name: string): number | null {
    const options = interaction.data.options;
    if (!options) return null;
    const opt = options.find(o => o.name === name && o.type === INTEGER_TYPE);
    return (opt?.value as number) ?? null;
}

export function getUserId(interaction: Interaction): string | null {
    return interaction.member?.user?.id ?? interaction.user?.id ?? null;
}

const JST_OFFSET_MS = 9 * 60 * 60 * 1000;

/** 現在のJSTの年月日を取得 */
function nowJST(): { year: number; month: number; day: number } {
    const jst = new Date(Date.now() + JST_OFFSET_MS);
    return { year: jst.getUTCFullYear(), month: jst.getUTCMonth(), day: jst.getUTCDate() };
}

/** JST年月日からJST 0:00のUTC Dateを生成 */
export function jstDate(year: number, month: number, day: number): Date {
    return new Date(Date.UTC(year, month, day) - JST_OFFSET_MS);
}

/** JST年月日時分からUTC Dateを生成 */
export function jstDateTime(year: number, month: number, day: number, hour: number, minute: number): Date {
    return new Date(Date.UTC(year, month, day, hour, minute, 0, 0) - JST_OFFSET_MS);
}

/**
 * 日付文字列をパースしてJSTの日付として返す（{year, month(0-indexed), day}）
 * Workers環境(UTC)でもJST基準で正しく動作する
 */
export function parseDateInput(input: string): { year: number; month: number; day: number } | null {
    const normalized = input.toLowerCase().trim();

    if (!normalized || normalized === 'today') {
        const n = nowJST();
        return n;
    }
    if (normalized === 'tomorrow') {
        const tomorrow = new Date(Date.now() + JST_OFFSET_MS + 24 * 60 * 60 * 1000);
        return { year: tomorrow.getUTCFullYear(), month: tomorrow.getUTCMonth(), day: tomorrow.getUTCDate() };
    }

    const ymdMatch = normalized.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$/);
    if (ymdMatch) {
        const year = parseInt(ymdMatch[1], 10);
        const month = parseInt(ymdMatch[2], 10) - 1;
        const day = parseInt(ymdMatch[3], 10);
        const d = new Date(Date.UTC(year, month, day));
        if (d.getUTCFullYear() !== year || d.getUTCMonth() !== month || d.getUTCDate() !== day) return null;
        return { year, month, day };
    }

    const mdMatch = normalized.match(/^(\d{1,2})[-/.](\d{1,2})$/);
    if (mdMatch) {
        const { year } = nowJST();
        const month = parseInt(mdMatch[1], 10) - 1;
        const day = parseInt(mdMatch[2], 10);
        const d = new Date(Date.UTC(year, month, day));
        if (d.getUTCFullYear() !== year || d.getUTCMonth() !== month || d.getUTCDate() !== day) return null;
        return { year, month, day };
    }

    return null;
}

export function reply(content: string, options?: { ephemeral?: boolean }) {
    return {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: {
            content,
            ...(options?.ephemeral ? { flags: EPHEMERAL_FLAG } : {}),
        },
    };
}

export function replyEmbed(title: string, description: string, color: number = 0x0099ff, options?: { ephemeral?: boolean }) {
    return {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: {
            embeds: [{
                title,
                description,
                color,
                timestamp: new Date().toISOString(),
            }],
            ...(options?.ephemeral ? { flags: EPHEMERAL_FLAG } : {}),
        },
    };
}
