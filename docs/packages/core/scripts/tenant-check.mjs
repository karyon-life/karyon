import { packageScriptPath, runNodeScript } from './package-tools.mjs';

runNodeScript(packageScriptPath('patch-starlight-content-path'), [], { cwd: process.cwd() });
runNodeScript(packageScriptPath('aggregate-book'), [], { cwd: process.cwd() });
runNodeScript(packageScriptPath('tenant-astro-command'), ['build'], {
	cwd: process.cwd(),
	env: {
		DOCS_LOCAL_DEV_MODE: 'cloudflare',
	},
});
