import { describe, expect, it } from 'vitest';
import type { AgentRuntimeSpec } from '../../../types/agents';
import { AgentKernel } from '../kernel/agent-kernel.ts';
import type {
	AgentExecutionAdapter,
	AgentMutationAdapter,
} from '../runtime-types.ts';
import type {
	SdkClaimMessageRequest,
	SdkCreateMessageRequest,
	SdkGetRequest,
	SdkPickRequest,
	SdkSearchRequest,
} from '../sdk-types';

function makeAgent(
	overrides: Partial<AgentRuntimeSpec> & Pick<AgentRuntimeSpec, 'slug' | 'handler'>,
): AgentRuntimeSpec {
	return {
		slug: overrides.slug,
		handler: overrides.handler,
		enabled: true,
		systemPrompt: `${overrides.slug} prompt`,
		persona: 'test persona',
		cli: {},
		triggers: overrides.triggers ?? [],
		triggerPolicy: overrides.triggerPolicy,
		permissions: overrides.permissions ?? [],
		execution: overrides.execution ?? {
			maxConcurrency: 1,
			timeoutSeconds: 60,
			cooldownSeconds: 0,
			leaseSeconds: 60,
			retryLimit: 1,
			branchPrefix: overrides.handler,
		},
		outputs: overrides.outputs ?? {
			messageTypes: [],
			modelMutations: [],
		},
	};
}

describe('agent kernel', () => {
	it('fails validation when an enabled agent has no registered handler', async () => {
		const sdk = {
			listAgentSpecs: async () => [
				makeAgent({
					slug: 'invalid-agent',
					handler: 'planner',
				}),
				{
					...makeAgent({
						slug: 'unknown-handler',
						handler: 'planner',
					}),
					handler: 'ghost',
				} as unknown as AgentRuntimeSpec,
			],
		} as unknown as any;

		const kernel = new AgentKernel(sdk, process.cwd(), {
			execution: { runTask: async () => ({ status: 'completed', summary: 'ok' }) } as AgentExecutionAdapter,
			mutations: {
				writeArtifact: async () => ({
					branchName: null,
					commitMessage: null,
					worktreePath: null,
					commitSha: null,
					changedPaths: [],
				}),
			} as AgentMutationAdapter,
		});

		await expect(kernel.doctor()).rejects.toThrow('Agent spec validation failed');
	});

	it('runs the planner -> researcher -> architect -> engineer MVP chain through the kernel', async () => {
		const objective = { id: 'build-the-treeseed-surface', date: '2026-04-01T00:00:00.000Z' };
		const question = { id: 'how-should-objectives-shape-question-prioritization', date: '2026-04-01T00:00:00.000Z' };
		const knowledge = new Map<string, { id: string; body: string }>();
		const messages: Array<Record<string, unknown>> = [];
		const runs: Array<Record<string, unknown>> = [];

		const planner = makeAgent({
			slug: 'planner-agent',
			handler: 'planner',
			triggers: [{ type: 'schedule', cron: '* * * * *', runOnStart: true }],
			permissions: [
				{ model: 'question', operations: ['search', 'get', 'create', 'update'] },
				{ model: 'objective', operations: ['search', 'get'] },
				{ model: 'message', operations: ['create'] },
			],
		});
		const researcher = makeAgent({
			slug: 'researcher-agent',
			handler: 'researcher',
			triggers: [{ type: 'message', messageTypes: ['question_priority_updated'] }],
			permissions: [
				{ model: 'question', operations: ['search', 'get', 'create', 'update'] },
				{ model: 'objective', operations: ['search', 'get'] },
				{ model: 'book', operations: ['search', 'get'] },
				{ model: 'knowledge', operations: ['search', 'get', 'create', 'update'] },
				{ model: 'note', operations: ['create'] },
				{ model: 'message', operations: ['search', 'get', 'pick', 'update', 'create'] },
			],
		});
		const architect = makeAgent({
			slug: 'architecture-agent',
			handler: 'architect',
			triggers: [{ type: 'message', messageTypes: ['objective_priority_updated'] }],
			permissions: [
				{ model: 'objective', operations: ['search', 'get'] },
				{ model: 'knowledge', operations: ['search', 'get', 'create', 'update'] },
				{ model: 'message', operations: ['search', 'get', 'pick', 'update', 'create'] },
			],
		});
		const engineer = makeAgent({
			slug: 'engineer-agent',
			handler: 'engineer',
			triggers: [{ type: 'message', messageTypes: ['architecture_updated'] }],
			permissions: [
				{ model: 'message', operations: ['search', 'get', 'pick', 'update', 'create'] },
				{ model: 'knowledge', operations: ['search', 'get', 'create', 'update'] },
			],
		});

		const sdk = {
			listAgentSpecs: async () => [planner, researcher, architect, engineer],
			scopeForAgent(_agent: AgentRuntimeSpec) {
				return {
					async search(request: SdkSearchRequest) {
						if (request.model === 'objective') {
							return { payload: [objective] };
						}
						if (request.model === 'question') {
							return { payload: [question] };
						}
						if (request.model === 'knowledge') {
							return { payload: [...knowledge.values()] };
						}
						return { payload: [] };
					},
					async get(request: SdkGetRequest) {
						if (request.model === 'knowledge' && request.id) {
							return { payload: knowledge.get(request.id) ?? null };
						}
						return { payload: null };
					},
					async pick(request: SdkPickRequest) {
						if (request.model === 'objective') {
							return { payload: { item: objective, leaseToken: 'lease-1' } };
						}
						return { payload: { item: null, leaseToken: null } };
					},
					async create(request: { model: string; data: Record<string, unknown> }) {
						if (request.model === 'knowledge' || request.model === 'note') {
							knowledge.set(String(request.data.slug), {
								id: String(request.data.slug),
								body: String(request.data.body ?? ''),
							});
						}
						return { payload: { item: request.data } };
					},
					async createMessage(request: Omit<SdkCreateMessageRequest, 'actor'>) {
						const message = {
							id: messages.length + 1,
							type: request.type,
							status: 'pending',
							payloadJson: JSON.stringify(request.payload),
							relatedModel: null,
							relatedId: null,
							priority: 0,
							availableAt: new Date().toISOString(),
							claimedBy: null,
							claimedAt: null,
							leaseExpiresAt: null,
							attempts: 0,
							maxAttempts: 3,
							createdAt: new Date().toISOString(),
							updatedAt: new Date().toISOString(),
						};
						messages.push(message);
						return { payload: message };
					},
					async claimMessage(request: SdkClaimMessageRequest) {
						const message = messages.find(
							(entry) =>
								entry.status === 'pending'
								&& (!request.messageTypes?.length || request.messageTypes.includes(String(entry.type))),
						);
						if (!message) {
							return { payload: null };
						}
						message.status = 'claimed';
						message.claimedBy = request.workerId;
						return { payload: message };
					},
					async ackMessage(request: { id: number; status: string }) {
						const message = messages.find((entry) => entry.id === request.id);
						if (message) {
							message.status = request.status;
						}
						return { payload: request };
					},
					async upsertCursor() {
						return { payload: true };
					},
					async releaseLease() {
						return { payload: true };
					},
				};
			},
			async recordRun(request: { run: Record<string, unknown> }) {
				runs.push(request.run);
				return { payload: request.run };
			},
			async upsertCursor() {
				return { payload: true };
			},
			async releaseAllLeases() {
				return { payload: { count: 0 } };
			},
		} as unknown as any;

		const execution: AgentExecutionAdapter = {
			runTask: async () => ({
				status: 'completed',
				summary: 'Stub execution completed.',
				stdout: 'planned implementation output',
			}),
		};
		const mutations: AgentMutationAdapter = {
			writeArtifact: async ({ runId }) => ({
				branchName: `engineer/${runId}`,
				commitMessage: `artifact ${runId}`,
				worktreePath: `.agent-worktrees/engineer/${runId}`,
				commitSha: `commit-${runId}`,
				changedPaths: [`.agent-artifacts/engineer/${runId}.md`],
			}),
		};

		const kernel = new AgentKernel(sdk, process.cwd(), {
			execution,
			mutations: mutations as unknown as any,
		});

		const results = await kernel.runCycle();

		expect(results.map((entry) => entry.slug)).toEqual([
			'planner-agent',
			'researcher-agent',
			'architecture-agent',
			'engineer-agent',
		]);
		expect(messages.some((entry) => entry.type === 'question_priority_updated')).toBe(true);
		expect(messages.some((entry) => entry.type === 'objective_priority_updated')).toBe(true);
		expect(messages.some((entry) => entry.type === 'research_completed')).toBe(true);
		expect(messages.some((entry) => entry.type === 'architecture_updated')).toBe(true);
		expect(messages.some((entry) => entry.type === 'task_complete')).toBe(true);
		expect(runs.length).toBeGreaterThanOrEqual(8);
	});
});
