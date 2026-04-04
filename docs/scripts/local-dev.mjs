import { prepareCloudflareLocalRuntime, startWranglerDev } from './local-dev-lib.mjs';

prepareCloudflareLocalRuntime();

const child = startWranglerDev();

child.on('exit', (code, signal) => {
	if (signal) {
		process.kill(process.pid, signal);
		return;
	}

	process.exit(code ?? 0);
});
