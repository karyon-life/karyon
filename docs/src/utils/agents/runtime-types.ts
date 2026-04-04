import type {
	AgentHandlerKind,
	AgentRuntimeSpec,
	AgentRunStatus,
	AgentTriggerConfig,
} from '../../types/agents';
import type { ScopedAgentSdk } from './sdk.ts';
import type { SdkMessageEntity } from './sdk-types';

export interface AgentTriggerInvocation {
	kind: 'startup' | 'schedule' | 'message' | 'manual';
	source: string;
	trigger: AgentTriggerConfig;
	message?: SdkMessageEntity | null;
}

export interface AgentExecutionResult {
	status: AgentRunStatus;
	summary: string;
	stdout?: string;
	stderr?: string;
	metadata?: Record<string, unknown>;
}

export interface AgentMutationResult {
	branchName: string | null;
	commitMessage: string | null;
	changedPaths: string[];
}

export interface AgentExecutionAdapter {
	runTask(input: {
		agent: AgentRuntimeSpec;
		runId: string;
		prompt: string;
	}): Promise<AgentExecutionResult>;
}

export interface AgentMutationAdapter {
	writeArtifact(input: {
		runId: string;
		agent: AgentRuntimeSpec;
		relativePath: string;
		content: string;
		commitMessage: string;
	}): Promise<AgentMutationResult>;
}

export interface AgentContext {
	runId: string;
	repoRoot: string;
	agent: AgentRuntimeSpec;
	sdk: ScopedAgentSdk;
	trigger: AgentTriggerInvocation;
	execution: AgentExecutionAdapter;
	mutations: AgentMutationAdapter;
}

export interface AgentHandler<TInputs = unknown, TResult = unknown> {
	kind: AgentHandlerKind;
	resolveInputs(context: AgentContext): Promise<TInputs>;
	execute(context: AgentContext, inputs: TInputs): Promise<TResult>;
	emitOutputs(context: AgentContext, result: TResult): Promise<AgentExecutionResult>;
}
