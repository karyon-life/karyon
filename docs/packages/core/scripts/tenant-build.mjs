import { astroBin, packageScriptPath, runNodeBinary, runNodeScript } from './package-tools.mjs';

process.env.DOCS_LOCAL_DEV_MODE = process.env.DOCS_LOCAL_DEV_MODE ?? 'cloudflare';

runNodeScript(packageScriptPath('patch-starlight-content-path'), [], { cwd: process.cwd() });
runNodeScript(packageScriptPath('aggregate-book'), [], { cwd: process.cwd() });
runNodeBinary(astroBin, ['build'], {
	cwd: process.cwd(),
	env: {
		DOCS_LOCAL_DEV_MODE: process.env.DOCS_LOCAL_DEV_MODE,
	},
});
