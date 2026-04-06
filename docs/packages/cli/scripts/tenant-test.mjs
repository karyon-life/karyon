import { packageScriptPath, runNodeScript } from './package-tools.mjs';

runNodeScript(packageScriptPath('tenant-check'), [], {
	cwd: process.cwd(),
});
