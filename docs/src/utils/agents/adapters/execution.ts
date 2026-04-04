import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import type { AgentExecutionAdapter } from '../runtime-types.ts';

const execFileAsync = promisify(execFile);

export class StubExecutionAdapter implements AgentExecutionAdapter {
	async runTask(input: { prompt: string; runId: string }) {
		return {
			status: 'completed' as const,
			summary: `Stubbed Copilot execution for ${input.runId}.`,
			stdout: [
				'# Planned Task',
				'',
				'1. Inspect the requested architecture context.',
				'2. Produce a safe local change artifact.',
				'3. Summarize the implementation intent.',
				'',
				`Prompt digest: ${input.prompt.slice(0, 240)}`,
			].join('\n'),
			stderr: '',
		};
	}
}

export class CopilotExecutionAdapter implements AgentExecutionAdapter {
	async runTask(input: { agent: { cli?: { model?: string; allowTools?: string[]; additionalArgs?: string[] } }; prompt: string }) {
		const args = ['copilot', '-p', input.prompt];
		if (input.agent.cli?.model) {
			args.push('--model', input.agent.cli.model);
		}
		for (const tool of input.agent.cli?.allowTools ?? []) {
			args.push('--allow-tool', tool);
		}
		args.push(...(input.agent.cli?.additionalArgs ?? []));

		try {
			const { stdout, stderr } = await execFileAsync('gh', args, {
				cwd: process.cwd(),
				env: process.env,
				maxBuffer: 10 * 1024 * 1024,
			});
			return {
				status: 'completed' as const,
				summary: 'Copilot task completed.',
				stdout,
				stderr,
			};
		} catch (error) {
			const stderr =
				error && typeof error === 'object' && 'stderr' in error
					? String((error as { stderr?: string }).stderr ?? '')
					: error instanceof Error
						? error.message
						: String(error);
			return {
				status: 'failed' as const,
				summary: 'Copilot task failed.',
				stdout: '',
				stderr,
			};
		}
	}
}

export function createExecutionAdapter() {
	if (String(process.env.DOCS_AGENT_EXECUTION_MODE ?? '').toLowerCase() === 'stub') {
		return new StubExecutionAdapter();
	}
	return new CopilotExecutionAdapter();
}
