import type { AgentHandler } from '../runtime-types.ts';
import {
	parseAgentMessagePayload,
	serializeAgentMessagePayload,
} from '../contracts/messages.ts';

interface ReviewerInputs {
	messageType: string;
	branchName: string | null;
	summary: string;
}

interface ReviewerResult extends ReviewerInputs {
	status: 'completed' | 'failed' | 'waiting';
}

export const reviewerHandler: AgentHandler<ReviewerInputs, ReviewerResult> = {
	kind: 'reviewer',
	async resolveInputs(context) {
		if (!context.trigger.message) {
			throw new Error('Reviewer requires a claimed message trigger.');
		}
		if (context.trigger.message.type === 'task_complete') {
			const payload = parseAgentMessagePayload('task_complete', context.trigger.message.payloadJson);
			return {
				messageType: 'task_complete',
				branchName: payload.branchName,
				summary: payload.changedTargets.length
					? `Task completed with ${payload.changedTargets.length} changed target(s).`
					: 'Task completed without changed targets.',
			};
		}

		const payload = parseAgentMessagePayload('architecture_updated', context.trigger.message.payloadJson);
		return {
			messageType: 'architecture_updated',
			branchName: null,
			summary: `Architecture updated for ${payload.objectiveId}.`,
		};
	},
	async execute(_context, inputs) {
		if (inputs.messageType === 'architecture_updated') {
			return {
				...inputs,
				status: 'waiting',
			};
		}
		if (!inputs.branchName) {
			return {
				...inputs,
				status: 'failed',
				summary: 'Reviewer could not find a branch to verify.',
			};
		}
		return {
			...inputs,
			status: 'completed',
			summary: `Reviewer verified branch ${inputs.branchName}.`,
		};
	},
	async emitOutputs(context, result) {
		if (result.status === 'completed') {
			await context.sdk.createMessage({
				type: 'task_verified',
				payload: serializeAgentMessagePayload('task_verified', {
					branchName: result.branchName,
					reviewerRunId: context.runId,
				}),
			});
			return {
				status: 'completed',
				summary: result.summary,
			};
		}

		if (result.status === 'waiting') {
			await context.sdk.createMessage({
				type: 'review_waiting',
				payload: serializeAgentMessagePayload('review_waiting', {
					blockingReason: result.summary,
					reviewerRunId: context.runId,
				}),
			});
			return {
				status: 'waiting',
				summary: result.summary,
			};
		}

		await context.sdk.createMessage({
			type: 'review_failed',
			payload: serializeAgentMessagePayload('review_failed', {
				failureSummary: result.summary,
				reviewerRunId: context.runId,
			}),
		});
		return {
			status: 'failed',
			summary: result.summary,
			errorCategory: 'execution_error',
		};
	},
};
