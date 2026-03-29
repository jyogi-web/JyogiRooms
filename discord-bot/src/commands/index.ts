import { listCommand } from './list.js';
import { checkCommand } from './check.js';
import { reserveCommand } from './reserve.js';
import { keyCommand } from './key.js';
import { callCommand } from './call.js';
import { helpCommand } from './help.js';
import { statusCommand } from './status.js';
import { rankCommand } from './rank.js';

export const commands = [
    listCommand,
    checkCommand,
    reserveCommand,
    keyCommand,
    callCommand,
    helpCommand,
    statusCommand,
    rankCommand,
];
