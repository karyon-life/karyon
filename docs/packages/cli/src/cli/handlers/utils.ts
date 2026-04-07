import type { TreeseedCommandContext, TreeseedCommandResult } from '../types.js';

export function ok(lines: string[] = []): TreeseedCommandResult {
	return { exitCode: 0, stdout: lines };
}

export function fail(message: string, exitCode = 1): TreeseedCommandResult {
	return { exitCode, stderr: [message] };
}

export function writeResult(result: TreeseedCommandResult, context: TreeseedCommandContext) {
	for (const line of result.stdout ?? []) {
		context.write(line, 'stdout');
	}
	for (const line of result.stderr ?? []) {
		context.write(line, 'stderr');
	}
	return result.exitCode ?? 0;
}
