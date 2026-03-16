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
