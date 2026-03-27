import { listCommand } from './list.js';
import { checkCommand } from './check.js';
import { createCommand } from './create.js';
import { keyCommand } from './key.js';
import { callCommand } from './call.js';
import { helpCommand } from './help.js';
import { statusCommand } from './status.js';

export const commands = [
    listCommand,
    checkCommand,
    createCommand,
    keyCommand,
    callCommand,
    helpCommand,
    statusCommand,
];
