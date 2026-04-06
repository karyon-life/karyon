import { packagesWithScript, run } from './workspace-tools.mjs';

for (const pkg of packagesWithScript('test:unit')) {
	run('npm', ['run', 'test:unit'], { cwd: pkg.dir });
}
