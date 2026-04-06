export interface QuestionPriorityUpdatedMessage {
	questionId: string;
	reason: string;
	plannerRunId: string;
}

export interface ObjectivePriorityUpdatedMessage {
	objectiveId: string;
	reason: string;
	plannerRunId: string;
}

export interface ArchitectureUpdatedMessage {
	objectiveId: string;
	knowledgeId: string;
	architectRunId: string;
}

export interface SubscriberNotifiedMessage {
	email: string;
	itemCount: number;
	notifierRunId: string;
}

export interface ResearchStartedMessage {
	questionId: string;
	researcherRunId: string;
}

export interface ResearchCompletedMessage {
	questionId: string;
	knowledgeId: string | null;
	researcherRunId: string;
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

export interface TaskVerifiedMessage {
	branchName: string | null;
	reviewerRunId: string;
}

export interface ReviewFailedMessage {
	failureSummary: string;
	reviewerRunId: string;
}

export interface ReviewWaitingMessage {
	blockingReason: string;
	reviewerRunId: string;
}

export interface ReleaseStartedMessage {
	taskRunId: string | null;
	releaserRunId: string;
}

export interface ReleaseCompletedMessage {
	releaseSummary: string;
	releaserRunId: string;
}

export interface ReleaseFailedMessage {
	failureSummary: string;
	releaserRunId: string;
}

export interface AgentMessageContracts {
	question_priority_updated: QuestionPriorityUpdatedMessage;
	objective_priority_updated: ObjectivePriorityUpdatedMessage;
	architecture_updated: ArchitectureUpdatedMessage;
	subscriber_notified: SubscriberNotifiedMessage;
	research_started: ResearchStartedMessage;
	research_completed: ResearchCompletedMessage;
	task_complete: TaskCompleteMessage;
	task_waiting: TaskWaitingMessage;
	task_failed: TaskFailedMessage;
	task_verified: TaskVerifiedMessage;
	review_failed: ReviewFailedMessage;
	review_waiting: ReviewWaitingMessage;
	release_started: ReleaseStartedMessage;
	release_completed: ReleaseCompletedMessage;
	release_failed: ReleaseFailedMessage;
}

export type AgentMessageType = keyof AgentMessageContracts;
export type AgentMessagePayload<TType extends AgentMessageType> = AgentMessageContracts[TType];
export declare const AGENT_MESSAGE_TYPES: readonly AgentMessageType[];

export declare function parseAgentMessagePayload<TType extends AgentMessageType>(
	type: TType,
	payloadJson: string,
): AgentMessagePayload<TType>;

export declare function serializeAgentMessagePayload<TType extends AgentMessageType>(
	type: TType,
	payload: AgentMessagePayload<TType>,
): Record<string, unknown>;
