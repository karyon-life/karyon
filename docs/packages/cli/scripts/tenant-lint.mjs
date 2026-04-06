import { packageScriptPath, runNodeScript } from './package-tools.mjs';

runNodeScript(packageScriptPath('cleanup-markdown'), ['--check'], {
	cwd: process.cwd(),
});
