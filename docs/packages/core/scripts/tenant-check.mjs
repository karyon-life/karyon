import { astroBin, packageScriptPath, runNodeBinary, runNodeScript } from './package-tools.mjs';

runNodeScript(packageScriptPath('patch-starlight-content-path'), [], { cwd: process.cwd() });
runNodeBinary(astroBin, ['sync'], { cwd: process.cwd() });
