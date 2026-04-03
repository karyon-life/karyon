import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { hashValue } from './crypto';
import type { SubscriberRecordInput } from '../../types/forms';

const localSubscriberStorePath = resolve(
	dirname(fileURLToPath(import.meta.url)),
	'../../../.local/subscribers.json',
);

interface LocalSubscriberRecord {
	email: string;
	name: string;
	source: string;
	status: string;
	consentAt: string;
	createdAt: string;
	updatedAt: string;
	ipHash: string;
}

async function readLocalSubscribers() {
	try {
		return JSON.parse(await readFile(localSubscriberStorePath, 'utf8')) as LocalSubscriberRecord[];
	} catch {
		return [];
	}
}

export async function upsertLocalSubscriber(input: SubscriberRecordInput) {
	const now = new Date().toISOString();
	const ipHash = await hashValue(input.ip || 'unknown');
	const subscribers = await readLocalSubscribers();
	const existingIndex = subscribers.findIndex((subscriber) => subscriber.email === input.email);
	const nextRecord: LocalSubscriberRecord = existingIndex === -1
		? {
				email: input.email,
				name: input.name,
				source: input.source,
				status: 'active',
				consentAt: now,
				createdAt: now,
				updatedAt: now,
				ipHash,
			}
		: {
				...subscribers[existingIndex],
				name: input.name,
				source: input.source,
				status: 'active',
				consentAt: now,
				updatedAt: now,
				ipHash,
			};

	if (existingIndex === -1) {
		subscribers.push(nextRecord);
	} else {
		subscribers[existingIndex] = nextRecord;
	}

	await mkdir(dirname(localSubscriberStorePath), { recursive: true });
	await writeFile(localSubscriberStorePath, JSON.stringify(subscribers, null, 2), 'utf8');
}
