import { packageScriptPath } from './package-tools.mjs';
import { packagesWithScript, run, workspaceRoot } from './workspace-tools.mjs';

const root = workspaceRoot();

run(process.execPath, [packageScriptPath('cleanup-markdown'), '--check'], {
	cwd: root,
});

for (const pkg of packagesWithScript('lint', root)) {
	run('npm', ['run', 'lint'], { cwd: pkg.dir });
}
