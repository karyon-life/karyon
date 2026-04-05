import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { packageRoot, packageScriptPath, spawnNodeBinary, wranglerBin } from './package-tools.mjs';
import {
	createTenantWatchEntries,
	isEditablePackageWorkspace,
	startPollingWatch,
	writeDevReloadStamp,
} from './watch-dev-lib.mjs';

const tenantRoot = process.cwd();
const cliArgs = process.argv.slice(2);
const watchMode = cliArgs.includes('--watch');
const wranglerArgs = cliArgs.filter((arg) => arg !== '--watch');

function runStep(command, args, { cwd = tenantRoot, env = {}, fatal = true } = {}) {
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

function runNodeScript(scriptPath, args = [], options = {}) {
	return runStep(process.execPath, [scriptPath, ...args], options);
}

function runTenantBuildCycle({ includePackageBuild = false, fatal = true } = {}) {
	const envOverrides = ['DOCS_LOCAL_DEV_MODE=cloudflare'];
	if (watchMode) {
		envOverrides.push('DOCS_PUBLIC_DEV_WATCH_RELOAD=true');
	}

	if (includePackageBuild && isEditablePackageWorkspace()) {
		const distBuilt = runStep('npm', ['run', 'build:dist'], {
			cwd: packageRoot,
			fatal,
		});
		if (!distBuilt) {
			return false;
		}
	}

	for (const [scriptName, args] of [
		['patch-starlight-content-path', []],
		['aggregate-book', []],
		['ensure-mailpit', []],
		['sync-dev-vars', envOverrides],
		['tenant-d1-migrate-local', []],
	]) {
		const ok = runNodeScript(packageScriptPath(scriptName), args, { fatal });
		if (!ok) {
			return false;
		}
	}

	if (watchMode) {
		writeDevReloadStamp(tenantRoot);
	}

	return runNodeScript(packageScriptPath('tenant-astro-command'), ['build'], {
		fatal,
		env: watchMode ? { DOCS_PUBLIC_DEV_WATCH_RELOAD: 'true' } : {},
	});
}

process.env.DOCS_LOCAL_DEV_MODE = process.env.DOCS_LOCAL_DEV_MODE ?? 'cloudflare';

runTenantBuildCycle({
	includePackageBuild: isEditablePackageWorkspace(),
	fatal: true,
});

const wranglerConfig = resolve(tenantRoot, 'wrangler.toml');
const child = spawnNodeBinary(
	wranglerBin,
	['dev', '--local', '--config', wranglerConfig, ...wranglerArgs],
	{
		cwd: tenantRoot,
		env: watchMode ? { DOCS_PUBLIC_DEV_WATCH_RELOAD: 'true' } : {},
	},
);

let stopWatching = null;
if (watchMode) {
	console.log('Starting unified Wrangler watch mode. Changes will rebuild the app and refresh the browser.');
	stopWatching = startPollingWatch({
		watchEntries: createTenantWatchEntries(tenantRoot),
		onChange: async ({ changedPaths, packageChanged }) => {
			console.log(
				`Detected ${changedPaths.length} change${changedPaths.length === 1 ? '' : 's'}; rebuilding ${packageChanged ? 'package and tenant' : 'tenant'} output...`,
			);
			const ok = runTenantBuildCycle({
				includePackageBuild: packageChanged,
				fatal: false,
			});
			if (ok) {
				console.log('Rebuild complete.');
			} else {
				console.error('Rebuild failed. Wrangler and Mailpit are still running; fix the error and save again to retry.');
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
