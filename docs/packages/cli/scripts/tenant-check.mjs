import { createProductionBuildEnv, packageScriptPath, runNodeScript } from './package-tools.mjs';

runNodeScript(packageScriptPath('patch-starlight-content-path'), [], { cwd: process.cwd() });
runNodeScript(packageScriptPath('aggregate-book'), [], { cwd: process.cwd() });
runNodeScript(packageScriptPath('tenant-build'), [], {
	cwd: process.cwd(),
	env: createProductionBuildEnv(),
});
