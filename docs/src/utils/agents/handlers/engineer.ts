import path from 'node:path';
import type { AgentHandler } from '../runtime-types.ts';
import {
	parseAgentMessagePayload,
	serializeAgentMessagePayload,
} from '../contracts/messages.ts';
import type { AgentErrorCategory } from '../contracts/run.ts';

interface EngineerInputs {
	messageId: number;
	objectiveId: string | null;
	knowledgeId: string | null;
}

interface EngineerResult extends EngineerInputs {
	status: 'completed' | 'failed' | 'waiting';
	summary: string;
	branchName: string | null;
	commitSha: string | null;
	changedPaths: string[];
	errorCategory?: AgentErrorCategory | null;
}

export const engineerHandler: AgentHandler<EngineerInputs, EngineerResult> = {
	kind: 'engineer',
	async resolveInputs(context) {
		if (!context.trigger.message) {
			throw new Error('Engineer requires a claimed message trigger.');
		}
		const payload = parseAgentMessagePayload('architecture_updated', context.trigger.message.payloadJson);
		return {
			messageId: context.trigger.message.id,
			objectiveId: payload.objectiveId,
			knowledgeId: payload.knowledgeId,
		};
	},
	async execute(context, inputs) {
		const knowledge = inputs.knowledgeId
			? await context.sdk.get({
				model: 'knowledge',
				id: inputs.knowledgeId,
			})
			: null;
		if (inputs.knowledgeId && !knowledge?.payload) {
			return {
				...inputs,
				status: 'failed',
				summary: `Knowledge ${inputs.knowledgeId} could not be loaded.`,
				branchName: null,
				commitSha: null,
				changedPaths: [],
				errorCategory: 'sdk_error',
			};
		}
		const prompt = [
			context.agent.systemPrompt,
			'',
			'Always begin in plan mode and provide the next implementation steps clearly.',
			'',
			`Objective: ${inputs.objectiveId ?? 'unknown'}`,
			`Knowledge: ${inputs.knowledgeId ?? 'none'}`,
			'',
			typeof knowledge?.payload === 'object' && knowledge?.payload && 'body' in knowledge.payload
				? String((knowledge.payload as { body?: string }).body ?? '')
				: '',
		].join('\n');

		const execution = await context.execution.runTask({
			agent: context.agent,
			runId: context.runId,
			prompt,
		});

		if (execution.status !== 'completed') {
			return {
				...inputs,
				status: execution.status === 'waiting' ? 'waiting' : 'failed',
				summary: execution.summary,
				branchName: null,
				commitSha: null,
				changedPaths: [],
				errorCategory: execution.status === 'failed' ? execution.errorCategory ?? 'execution_error' : null,
			};
		}

		try {
			const artifact = await context.mutations.writeArtifact({
				runId: context.runId,
				agent: context.agent,
				relativePath: path.join('.agent-artifacts', 'engineer', `${context.runId}.md`),
				content: [
					'# Engineer Run Artifact',
					'',
					`Run: ${context.runId}`,
					`Objective: ${inputs.objectiveId ?? 'unknown'}`,
					`Knowledge: ${inputs.knowledgeId ?? 'none'}`,
					'',
					'## Copilot Output',
					'',
					execution.stdout ?? '',
				].join('\n'),
				commitMessage: `agent(engineer): artifact ${context.runId}`,
			});

			return {
				...inputs,
				status: 'completed',
				summary: 'Engineer created a local branch artifact.',
				branchName: artifact.branchName,
				commitSha: artifact.commitSha,
				changedPaths: artifact.changedPaths,
			};
		} catch (error) {
			return {
				...inputs,
				status: 'failed',
				summary: error instanceof Error ? error.message : String(error),
				branchName: null,
				commitSha: null,
				changedPaths: [],
				errorCategory: 'mutation_error',
			};
		}
	},
	async emitOutputs(context, result) {
		const messageType =
			result.status === 'completed'
				? 'task_complete'
				: result.status === 'waiting'
					? 'task_waiting'
					: 'task_failed';
		await context.sdk.createMessage({
			type: messageType,
			payload:
				messageType === 'task_complete'
					? serializeAgentMessagePayload('task_complete', {
						branchName: result.branchName,
						changedTargets: result.changedPaths,
						engineerRunId: context.runId,
					})
					: messageType === 'task_waiting'
						? serializeAgentMessagePayload('task_waiting', {
							blockingReason: result.summary,
							engineerRunId: context.runId,
						})
						: serializeAgentMessagePayload('task_failed', {
							failureSummary: result.summary,
							engineerRunId: context.runId,
						}),
		});
		return {
			status: result.status,
			summary: result.summary,
			metadata: {
				branchName: result.branchName,
				commitSha: result.commitSha,
				changedPaths: result.changedPaths,
			},
			errorCategory: result.errorCategory ?? null,
		};
	},
};
