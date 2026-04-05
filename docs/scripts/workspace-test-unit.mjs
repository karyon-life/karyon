import { run, packageInfo } from './workspace-lib.mjs';

for (const key of ['sdk', 'core']) {
	const pkg = packageInfo(key);
	run('npm', ['run', 'test:unit'], { cwd: pkg.dir });
}
