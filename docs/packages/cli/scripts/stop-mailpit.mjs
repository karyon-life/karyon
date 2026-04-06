import { stopKnownMailpitContainers } from './mailpit-runtime.mjs';

if (!stopKnownMailpitContainers()) {
	process.exit(1);
}

console.log('Mailpit is stopped.');
