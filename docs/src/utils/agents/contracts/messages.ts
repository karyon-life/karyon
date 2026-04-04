export interface PriorityUpdatedMessage {
	objectiveId: string;
	questionId: string | null;
	reason: string;
	plannerRunId: string;
}

export interface ArchitectureUpdatedMessage {
	objectiveId: string;
	knowledgeId: string;
	architectRunId: string;
}

export interface TaskCompleteMessage {
	branchName: string | null;
	changedTargets: string[];
	engineerRunId: string;
}

export interface TaskWaitingMessage {
	blockingReason: string;
	engineerRunId: string;
}

export interface TaskFailedMessage {
	failureSummary: string;
	engineerRunId: string;
}

export interface AgentMessageContracts {
	priority_updated: PriorityUpdatedMessage;
	architecture_updated: ArchitectureUpdatedMessage;
	task_complete: TaskCompleteMessage;
	task_waiting: TaskWaitingMessage;
	task_failed: TaskFailedMessage;
}

export type AgentMessageType = keyof AgentMessageContracts;
export type AgentMessagePayload<TType extends AgentMessageType> = AgentMessageContracts[TType];

function ensureString(value: unknown, label: string) {
	if (typeof value !== 'string' || value.trim().length === 0) {
		throw new Error(`Invalid ${label}: expected non-empty string.`);
	}
	return value;
}

function ensureOptionalString(value: unknown, label: string) {
	if (value === null || value === undefined) {
		return null;
	}
	return ensureString(value, label);
}

function ensureStringArray(value: unknown, label: string) {
	if (!Array.isArray(value)) {
		throw new Error(`Invalid ${label}: expected array.`);
	}
	return value.map((entry, index) => ensureString(entry, `${label}[${index}]`));
}

export function parseAgentMessagePayload<TType extends AgentMessageType>(
	type: TType,
	payloadJson: string,
): AgentMessagePayload<TType> {
	const parsed = JSON.parse(payloadJson) as Record<string, unknown>;

	switch (type) {
		case 'priority_updated':
			return {
				objectiveId: ensureString(parsed.objectiveId, 'objectiveId'),
				questionId: ensureOptionalString(parsed.questionId, 'questionId'),
				reason: ensureString(parsed.reason, 'reason'),
				plannerRunId: ensureString(parsed.plannerRunId, 'plannerRunId'),
			} as AgentMessagePayload<TType>;
		case 'architecture_updated':
			return {
				objectiveId: ensureString(parsed.objectiveId, 'objectiveId'),
				knowledgeId: ensureString(parsed.knowledgeId, 'knowledgeId'),
				architectRunId: ensureString(parsed.architectRunId, 'architectRunId'),
			} as AgentMessagePayload<TType>;
		case 'task_complete':
			return {
				branchName: ensureOptionalString(parsed.branchName, 'branchName'),
				changedTargets: ensureStringArray(parsed.changedTargets, 'changedTargets'),
				engineerRunId: ensureString(parsed.engineerRunId, 'engineerRunId'),
			} as AgentMessagePayload<TType>;
		case 'task_waiting':
			return {
				blockingReason: ensureString(parsed.blockingReason, 'blockingReason'),
				engineerRunId: ensureString(parsed.engineerRunId, 'engineerRunId'),
			} as AgentMessagePayload<TType>;
		case 'task_failed':
			return {
				failureSummary: ensureString(parsed.failureSummary, 'failureSummary'),
				engineerRunId: ensureString(parsed.engineerRunId, 'engineerRunId'),
			} as AgentMessagePayload<TType>;
		default:
			throw new Error(`Unsupported message type "${type}".`);
	}
}

export function serializeAgentMessagePayload<TType extends AgentMessageType>(
	type: TType,
	payload: AgentMessagePayload<TType>,
) {
	parseAgentMessagePayload(type, JSON.stringify(payload));
	return payload as unknown as Record<string, unknown>;
}
