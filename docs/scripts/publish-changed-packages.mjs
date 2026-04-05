import { resolve } from 'node:path';
import { packageInfo, changedWorkspacePackages, run } from './workspace-lib.mjs';

const changed = changedWorkspacePackages();
const publishOrder = ['sdk', 'core'].filter((key) => changed.includes(key));

if (publishOrder.length === 0) {
	console.log('No changed workspace packages to publish.');
	process.exit(0);
}

run(process.execPath, [resolve(process.cwd(), 'scripts', 'release-verify.mjs'), '--changed']);

for (const key of publishOrder) {
	const pkg = packageInfo(key);
	run('npm', ['run', 'release:publish'], {
		cwd: pkg.dir,
	});
}
