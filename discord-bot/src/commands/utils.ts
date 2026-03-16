import { InteractionResponseType } from 'discord-interactions';
import type { Interaction } from './types.js';

export const STRING_TYPE = 3;

export function getStringOption(interaction: Interaction, name: string): string | null {
    const options = interaction.data.options;
    if (!options) return null;
    const opt = options.find(o => o.name === name && o.type === STRING_TYPE);
    return (opt?.value as string) ?? null;
}

export function getUserId(interaction: Interaction): string | null {
    return interaction.member?.user?.id ?? interaction.user?.id ?? null;
}

export function parseDateInput(input: string): Date | null {
    const now = new Date();
    const normalized = input.toLowerCase().trim();

    if (!normalized || normalized === 'today') return now;
    if (normalized === 'tomorrow') {
        const d = new Date(now);
        d.setDate(d.getDate() + 1);
        return d;
    }

    const ymdMatch = normalized.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$/);
    if (ymdMatch) {
        const year = parseInt(ymdMatch[1], 10);
        const month = parseInt(ymdMatch[2], 10) - 1;
        const day = parseInt(ymdMatch[3], 10);
        const d = new Date(year, month, day);
        if (d.getFullYear() !== year || d.getMonth() !== month || d.getDate() !== day) return null;
        return d;
    }

    const mdMatch = normalized.match(/^(\d{1,2})[-/.](\d{1,2})$/);
    if (mdMatch) {
        const year = now.getFullYear();
        const month = parseInt(mdMatch[1], 10) - 1;
        const day = parseInt(mdMatch[2], 10);
        const d = new Date(year, month, day);
        if (d.getFullYear() !== year || d.getMonth() !== month || d.getDate() !== day) return null;
        return d;
    }

    return null;
}

export function reply(content: string) {
    return {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: { content },
    };
}

export function replyEmbed(title: string, description: string, color: number = 0x0099ff) {
    return {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: {
            embeds: [{
                title,
                description,
                color,
                timestamp: new Date().toISOString(),
            }],
        },
    };
}
