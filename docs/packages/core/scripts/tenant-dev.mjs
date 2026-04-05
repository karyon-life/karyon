import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { packageScriptPath, spawnNodeBinary, wranglerBin } from './package-tools.mjs';

const tenantRoot = process.cwd();

function runNodeScript(scriptPath, args = []) {
	const result = spawnSync(process.execPath, [scriptPath, ...args], {
		stdio: 'inherit',
		cwd: tenantRoot,
		env: { ...process.env },
	});

	if (result.status !== 0) {
		process.exit(result.status ?? 1);
	}
}

process.env.DOCS_LOCAL_DEV_MODE = process.env.DOCS_LOCAL_DEV_MODE ?? 'cloudflare';

runNodeScript(packageScriptPath('patch-starlight-content-path'));
runNodeScript(packageScriptPath('aggregate-book'));
runNodeScript(packageScriptPath('tenant-ensure-mailpit'));
runNodeScript(packageScriptPath('sync-dev-vars'), ['DOCS_LOCAL_DEV_MODE=cloudflare']);
runNodeScript(packageScriptPath('tenant-d1-migrate-local'));
runNodeScript(packageScriptPath('tenant-astro-command'), ['build']);

const wranglerConfig = resolve(tenantRoot, 'wrangler.toml');

const child = spawnNodeBinary(wranglerBin, ['dev', '--local', '--config', wranglerConfig], {
	cwd: tenantRoot,
});

child.on('exit', (code, signal) => {
	if (signal) {
		process.kill(process.pid, signal);
		return;
	}

	process.exit(code ?? 0);
});
