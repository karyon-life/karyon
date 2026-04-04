import type { AgentHandler } from '../runtime-types.ts';

interface PlannerInputs {
	objectiveId: string | null;
	questionId: string | null;
}

interface PlannerResult extends PlannerInputs {
	reason: string;
}

export const plannerHandler: AgentHandler<PlannerInputs, PlannerResult> = {
	kind: 'planner',
	async resolveInputs(context) {
		const objectives = await context.sdk.search({
			model: 'objective',
			sort: [{ field: 'date', direction: 'desc' }],
			limit: 1,
		});
		const questions = await context.sdk.search({
			model: 'question',
			sort: [{ field: 'date', direction: 'desc' }],
			limit: 1,
		});

		return {
			objectiveId: (objectives.payload[0] as { id?: string } | undefined)?.id ?? null,
			questionId: (questions.payload[0] as { id?: string } | undefined)?.id ?? null,
		};
	},
	async execute(_context, inputs) {
		return {
			...inputs,
			reason: inputs.objectiveId
				? `Objective ${inputs.objectiveId} is the highest-value current target.`
				: 'No objective was available to prioritize.',
		};
	},
	async emitOutputs(context, result) {
		if (!result.objectiveId) {
			return {
				status: 'waiting',
				summary: 'Planner found no objective to prioritize.',
			};
		}

		await context.sdk.createMessage({
			type: 'priority_updated',
			payload: {
				objectiveId: result.objectiveId,
				questionId: result.questionId,
				reason: result.reason,
				plannerRunId: context.runId,
			},
		});
		await context.sdk.upsertCursor({
			agentSlug: context.agent.slug,
			cursorKey: 'last_priority_run_at',
			cursorValue: new Date().toISOString(),
		});
		return {
			status: 'completed',
			summary: `Planner prioritized objective ${result.objectiveId}.`,
		};
	},
};
