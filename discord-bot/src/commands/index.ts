import { listCommand } from './list.js';
import { checkCommand } from './check.js';
import { createCommand } from './create.js';
import { keyCommand } from './key.js';
import { callCommand } from './call.js';
import { helpCommand } from './help.js';
import { openCommand } from './open.js';
import { closeCommand } from './close.js';
import { enterCommand } from './enter.js';
import { exitCommand } from './exit.js';
import { statusCommand } from './status.js';

export const commands = [
    listCommand,
    checkCommand,
    createCommand,
    keyCommand,
    callCommand,
    helpCommand,
    openCommand,
    closeCommand,
    enterCommand,
    exitCommand,
    statusCommand,
];
