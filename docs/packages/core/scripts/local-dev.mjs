import { spawnSync } from 'node:child_process';
import { packageRoot } from './package-tools.mjs';
import { fixtureRoot } from './paths.mjs';
import { prepareCloudflareLocalRuntime, startWranglerDev } from './local-dev-lib.mjs';
import {
	createTenantWatchEntries,
	startPollingWatch,
	writeDevReloadStamp,
} from './watch-dev-lib.mjs';

const cliArgs = process.argv.slice(2);
const watchMode = cliArgs.includes('--watch');
const wranglerArgs = cliArgs.filter((arg) => arg !== '--watch');

function runStep(command, args, { cwd = packageRoot, env = {}, fatal = true } = {}) {
	const result = spawnSync(command, args, {
		stdio: 'inherit',
		cwd,
		env: { ...process.env, ...env },
	});

	if (result.status !== 0 && fatal) {
		process.exit(result.status ?? 1);
	}

	return result.status === 0;
}

function runFixtureBuildCycle({ includePackageBuild = false, fatal = true } = {}) {
	if (includePackageBuild) {
		const built = runStep('npm', ['run', 'build:dist'], { cwd: packageRoot, fatal });
		if (!built) {
			return false;
		}
	}

	if (watchMode) {
		writeDevReloadStamp(fixtureRoot);
	}

	try {
		prepareCloudflareLocalRuntime({
			envOverrides: watchMode ? { DOCS_PUBLIC_DEV_WATCH_RELOAD: 'true' } : {},
		});
		return true;
	} catch (error) {
		if (fatal) {
			throw error;
		}
		console.error(error instanceof Error ? error.message : String(error));
		return false;
	}
}

runFixtureBuildCycle({ includePackageBuild: true, fatal: true });

const child = startWranglerDev(wranglerArgs, {
	env: watchMode ? { DOCS_PUBLIC_DEV_WATCH_RELOAD: 'true' } : {},
});

let stopWatching = null;
if (watchMode) {
	console.log('Starting fixture watch mode. Changes will rebuild the package fixture and refresh the browser.');
	stopWatching = startPollingWatch({
		watchEntries: createTenantWatchEntries(fixtureRoot),
		onChange: async ({ changedPaths, packageChanged }) => {
			console.log(
				`Detected ${changedPaths.length} change${changedPaths.length === 1 ? '' : 's'}; rebuilding ${packageChanged ? 'package and fixture' : 'fixture'} output...`,
			);
			const ok = runFixtureBuildCycle({
				includePackageBuild: packageChanged,
				fatal: false,
			});
			if (ok) {
				console.log('Rebuild complete.');
			} else {
				console.error('Rebuild failed. Wrangler and Mailpit are still running; save again after fixing the issue to retry.');
			}
		},
	});
}

child.on('exit', (code, signal) => {
	if (stopWatching) {
		stopWatching();
	}

	if (signal) {
		process.kill(process.pid, signal);
		return;
	}

	process.exit(code ?? 0);
});
