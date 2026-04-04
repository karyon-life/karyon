import type { AgentRuntimeSpec } from '../../../types/agents';
import { createExecutionAdapter } from '../adapters/execution.ts';
import { LocalBranchMutationAdapter } from '../adapters/mutations.ts';
import { resolveAgentHandler } from '../handlers/registry.ts';
import type {
	AgentContext,
	AgentExecutionAdapter,
	AgentMutationAdapter,
	AgentTriggerInvocation,
} from '../runtime-types.ts';
import type { AgentRunTrace, AgentErrorCategory } from '../contracts/run.ts';
import { AgentSdk } from '../sdk.ts';
import { resolveTriggerDecision } from './trigger-resolver.ts';
import { loadActiveAgentSpecs, summarizeAgentSpec } from '../spec-loader.ts';

function nowIso() {
	return new Date().toISOString();
}

export class AgentKernel {
	private readonly execution;
	private readonly mutations;
	private readonly activeRuns = new Set<string>();
	private readonly lastRunAt = new Map<string, number>();

	constructor(
		private readonly sdk: AgentSdk,
		private readonly repoRoot: string,
		options?: {
			execution?: AgentExecutionAdapter;
			mutations?: AgentMutationAdapter;
		},
	) {
		this.execution = options?.execution ?? createExecutionAdapter();
		this.mutations = options?.mutations ?? new LocalBranchMutationAdapter(repoRoot);
	}

	async doctor() {
		const agents = await loadActiveAgentSpecs(this.sdk);
		for (const agent of agents) {
			resolveAgentHandler(agent.handler);
		}
		return {
			agents: agents.map(summarizeAgentSpec),
		};
	}

	private sortAgents(agents: AgentRuntimeSpec[]) {
		const priority: Record<string, number> = {
			planner: 10,
			architect: 20,
			engineer: 30,
		};
		return [...agents].sort(
			(left, right) => (priority[left.handler] ?? 100) - (priority[right.handler] ?? 100),
		);
	}

	private async resolveTrigger(agent: AgentRuntimeSpec, mode: 'auto' | 'manual' = 'auto') {
		const decision = await resolveTriggerDecision({
			agent,
			mode,
			isRunning: this.activeRuns.has(agent.slug),
			lastRunAt: this.lastRunAt.get(agent.slug),
			sdk: this.sdk.scopeForAgent(agent),
		});
		return decision.kind === 'ready' ? decision.invocation ?? null : null;
	}

	private async recordRunTrace(trace: AgentRunTrace) {
		await this.sdk.recordRun({ run: trace });
	}

	private buildTrace(
		agent: AgentRuntimeSpec,
		runId: string,
		trigger: AgentTriggerInvocation,
		overrides: Partial<AgentRunTrace>,
	): AgentRunTrace {
		return {
			runId,
			agentSlug: agent.slug,
			handlerKind: agent.handler,
			triggerKind: trigger.kind,
			triggerSource: trigger.source,
			claimedMessageId: trigger.message?.id ?? null,
			selectedItemKey: null,
			branchName: null,
			commitSha: null,
			changedPaths: [],
			summary: null,
			error: null,
			errorCategory: null,
			startedAt: nowIso(),
			finishedAt: null,
			status: 'running',
			...overrides,
		};
	}

	private categorizeError(error: unknown): AgentErrorCategory {
		const message = error instanceof Error ? error.message : String(error);
		if (message.includes('not allowed')) {
			return 'permission_error';
		}
		if (message.includes('message')) {
			return 'message_claim_error';
		}
		if (message.includes('lease')) {
			return 'lease_error';
		}
		if (message.includes('commit') || message.includes('worktree') || message.includes('artifact')) {
			return 'mutation_error';
		}
		if (message.includes('Copilot') || message.includes('execution')) {
			return 'execution_error';
		}
		return 'sdk_error';
	}

	private async executeAgent(agent: AgentRuntimeSpec, trigger: AgentTriggerInvocation) {
		if (this.activeRuns.has(agent.slug)) {
			return {
				status: 'waiting',
				summary: `Agent ${agent.slug} is already running.`,
			};
		}
		this.activeRuns.add(agent.slug);

		const runId = crypto.randomUUID();
		const handler = resolveAgentHandler(agent.handler);
		const scopedSdk = this.sdk.scopeForAgent(agent);
		const context: AgentContext = {
			runId,
			repoRoot: this.repoRoot,
			agent,
			sdk: scopedSdk,
			trigger,
			execution: this.execution,
			mutations: this.mutations,
		};

		await this.recordRunTrace(this.buildTrace(agent, runId, trigger, {}));

		try {
			const inputs = await handler.resolveInputs(context);
			const result = await handler.execute(context, inputs);
			const output = await handler.emitOutputs(context, result);

			if (trigger.message) {
				await scopedSdk.ackMessage({
					id: trigger.message.id,
					status:
						output.status === 'completed'
							? 'completed'
							: output.status === 'waiting'
								? 'pending'
								: 'failed',
				});
			}

			await this.recordRunTrace(
				this.buildTrace(agent, runId, trigger, {
					status: output.status,
					branchName: (output.metadata?.branchName as string | undefined) ?? null,
					commitSha: (output.metadata?.commitSha as string | undefined) ?? null,
					changedPaths: (output.metadata?.changedPaths as string[] | undefined) ?? [],
					summary: output.summary,
					error: output.status === 'failed' ? output.stderr ?? output.summary : null,
					errorCategory: output.status === 'failed' ? output.errorCategory ?? 'execution_error' : null,
					finishedAt: nowIso(),
				}),
			);
			await this.sdk.upsertCursor({
				agentSlug: agent.slug,
				cursorKey: 'last_run_at',
				cursorValue: nowIso(),
			});
			this.lastRunAt.set(agent.slug, Date.now());
			return output;
		} catch (error) {
			if (trigger.message) {
				await scopedSdk.ackMessage({
					id: trigger.message.id,
					status: 'failed',
				});
			}
			await this.recordRunTrace(
				this.buildTrace(agent, runId, trigger, {
					status: 'failed',
					error: error instanceof Error ? error.message : String(error),
					errorCategory: this.categorizeError(error),
					finishedAt: nowIso(),
				}),
			);
			throw error;
		} finally {
			this.activeRuns.delete(agent.slug);
		}
	}

	async runAgent(slug: string, mode: 'auto' | 'manual' = 'manual') {
		const agents = this.sortAgents(await loadActiveAgentSpecs(this.sdk));
		const agent = agents.find((entry) => entry.slug === slug);
		if (!agent) {
			throw new Error(`Unknown or disabled agent "${slug}".`);
		}
		const trigger = await this.resolveTrigger(agent, mode);
		if (!trigger) {
			return {
				status: 'waiting',
				summary: `No runnable trigger found for ${slug}.`,
			};
		}
		return this.executeAgent(agent, trigger);
	}

	async runCycle() {
		const agents = this.sortAgents(await loadActiveAgentSpecs(this.sdk));
		const results = [];
		for (const agent of agents) {
			const trigger = await this.resolveTrigger(agent, 'auto');
			if (!trigger) {
				continue;
			}
			results.push({
				slug: agent.slug,
				result: await this.executeAgent(agent, trigger),
			});
		}
		return results;
	}

	async start(intervalMs = Number(process.env.DOCS_AGENT_SUPERVISOR_INTERVAL_MS ?? 60000)) {
		await this.runCycle();
		setInterval(() => {
			void this.runCycle();
		}, intervalMs);
	}

	async drainMessages() {
		const agents = this.sortAgents(await loadActiveAgentSpecs(this.sdk));
		const messageAgents = agents.filter((agent) =>
			agent.triggers.some((trigger) => trigger.type === 'message'),
		);
		const results = [];
		for (const agent of messageAgents) {
			results.push({
				slug: agent.slug,
				result: await this.runAgent(agent.slug, 'auto'),
			});
		}
		return results;
	}

	releaseLeases() {
		return this.sdk.releaseAllLeases();
	}

	async replayMessage(id: number) {
		await this.sdk.ackMessage({
			id,
			status: 'pending',
		});
		return {
			id,
			status: 'pending',
		};
	}
}
