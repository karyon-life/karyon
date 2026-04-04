import type { AgentHandler } from '../runtime-types.ts';
import { serializeAgentMessagePayload } from '../contracts/messages.ts';

interface NotifierInputs {
	subscriptions: Array<{ email: string }>;
	activityCount: number;
}

interface NotifierResult extends NotifierInputs {}

const WATCHED_MODELS = ['note', 'question', 'objective', 'book', 'knowledge'] as const;

export const notifierHandler: AgentHandler<NotifierInputs, NotifierResult> = {
	kind: 'notifier',
	async resolveInputs(context) {
		const subscriptions = await context.sdk.search({
			model: 'subscription',
			filters: [{ field: 'status', op: 'eq', value: 'active' }],
			limit: 100,
		});
		const cursor = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
		const activity = await Promise.all(
			WATCHED_MODELS.map((model) =>
				context.sdk.follow({
					model,
					since: cursor,
				}),
			),
		);

		return {
			subscriptions: subscriptions.payload as Array<{ email: string }>,
			activityCount: activity.reduce((count, response) => count + response.payload.items.length, 0),
		};
	},
	async execute(_context, inputs) {
		return inputs;
	},
	async emitOutputs(context, result) {
		if (!result.subscriptions.length) {
			return {
				status: 'waiting',
				summary: 'Notifier found no active subscriptions.',
			};
		}
		if (!result.activityCount) {
			return {
				status: 'waiting',
				summary: 'Notifier found no new activity to announce.',
			};
		}

		for (const subscription of result.subscriptions) {
			await context.sdk.createMessage({
				type: 'subscriber_notified',
				payload: serializeAgentMessagePayload('subscriber_notified', {
					email: subscription.email,
					itemCount: result.activityCount,
					notifierRunId: context.runId,
				}),
			});
		}
		await context.sdk.upsertCursor({
			agentSlug: context.agent.slug,
			cursorKey: 'last_notified_at',
			cursorValue: new Date().toISOString(),
		});
		return {
			status: 'completed',
			summary: `Notifier prepared ${result.subscriptions.length} subscriber notifications.`,
		};
	},
};
