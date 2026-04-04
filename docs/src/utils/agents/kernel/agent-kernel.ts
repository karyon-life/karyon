import crypto from 'node:crypto';
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
import { AgentSdk } from '../sdk.ts';
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

	private canRunScheduledAgent(agent: AgentRuntimeSpec) {
		const last = this.lastRunAt.get(agent.slug) ?? 0;
		const cooldownMs = agent.execution.cooldownSeconds * 1000;
		return Date.now() - last >= cooldownMs;
	}

	private async resolveTrigger(agent: AgentRuntimeSpec, mode: 'auto' | 'manual' = 'auto') {
		const startup = agent.triggers.find((trigger) => trigger.type === 'schedule' && trigger.runOnStart);
		const messageTrigger = agent.triggers.find((trigger) => trigger.type === 'message');

		if (mode === 'manual' && startup) {
			return {
				kind: 'manual',
				source: 'manual',
				trigger: startup,
			} satisfies AgentTriggerInvocation;
		}

		if (messageTrigger) {
			const claimed = await this.sdk
				.scopeForAgent(agent)
				.claimMessage({
					workerId: `${agent.slug}-${crypto.randomUUID()}`,
					messageTypes: messageTrigger.messageTypes ?? [],
					leaseSeconds: agent.execution.leaseSeconds,
				});
			if (claimed.payload) {
				return {
					kind: 'message',
					source: 'message',
					trigger: messageTrigger,
					message: claimed.payload,
				} satisfies AgentTriggerInvocation;
			}
		}

		if (startup) {
			if (mode === 'auto' && !this.canRunScheduledAgent(agent)) {
				return null;
			}
			return {
				kind: startup.runOnStart ? 'startup' : 'schedule',
				source: startup.runOnStart ? 'startup' : 'schedule',
				trigger: startup,
			} satisfies AgentTriggerInvocation;
		}

		return null;
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

		await this.sdk.recordRun({
			run: {
				runId,
				agentSlug: agent.slug,
				triggerSource: trigger.source,
				status: 'running',
				selectedItemKey: null,
				selectedMessageId: trigger.message?.id ?? null,
				branchName: null,
				prUrl: null,
				summary: null,
				error: null,
				startedAt: nowIso(),
				finishedAt: null,
			},
		});

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

			await this.sdk.recordRun({
				run: {
					runId,
					agentSlug: agent.slug,
					triggerSource: trigger.source,
					status: output.status,
					selectedItemKey: null,
					selectedMessageId: trigger.message?.id ?? null,
					branchName: (output.metadata?.branchName as string | undefined) ?? null,
					prUrl: null,
					summary: output.summary,
					error: output.status === 'failed' ? output.stderr ?? output.summary : null,
					startedAt: nowIso(),
					finishedAt: nowIso(),
				},
			});
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
			await this.sdk.recordRun({
				run: {
					runId,
					agentSlug: agent.slug,
					triggerSource: trigger.source,
					status: 'failed',
					selectedItemKey: null,
					selectedMessageId: trigger.message?.id ?? null,
					branchName: null,
					prUrl: null,
					summary: null,
					error: error instanceof Error ? error.message : String(error),
					startedAt: nowIso(),
					finishedAt: nowIso(),
				},
			});
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
