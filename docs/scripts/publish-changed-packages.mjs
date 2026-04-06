import { resolve } from 'node:path';
import { packageInfo, changedWorkspacePackages, run } from './workspace-lib.mjs';

const changed = changedWorkspacePackages();
const publishOrder = ['sdk', 'core'].filter((key) => changed.includes(key));

if (publishOrder.length === 0) {
	console.log('No changed workspace packages to publish.');
	process.exit(0);
}

console.log(`Publishing changed workspace packages in order: ${publishOrder.join(', ')}`);

run(process.execPath, [resolve(process.cwd(), 'scripts', 'release-verify.mjs'), '--changed', '--full-smoke']);

for (const key of publishOrder) {
	const pkg = packageInfo(key);
	console.log(`Publishing ${pkg.name}`);
	run('npm', ['run', 'release:publish'], {
		cwd: pkg.dir,
	});
}
