import type { TreeseedCommandHandler } from '../types.js';
import { packageScriptPath } from '../../../scripts/package-tools.ts';

export const handleInit: TreeseedCommandHandler = (invocation, context) => {
	const result = context.spawn(process.execPath, [packageScriptPath('scaffold-site'), ...invocation.rawArgs], {
		cwd: context.cwd,
		env: { ...context.env },
		stdio: 'inherit',
	});
	return { exitCode: result.status ?? 1 };
};
