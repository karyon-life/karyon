import { astroBin, createProductionBuildEnv, packageScriptPath, runNodeBinary, runNodeScript } from './package-tools.mjs';

runNodeScript(packageScriptPath('patch-starlight-content-path'), [], { cwd: process.cwd() });
runNodeScript(packageScriptPath('aggregate-book'), [], { cwd: process.cwd() });
runNodeBinary(astroBin, ['check'], {
	cwd: process.cwd(),
	env: createProductionBuildEnv(),
});
