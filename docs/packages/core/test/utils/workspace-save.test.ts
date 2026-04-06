import { describe, expect, it } from 'vitest';
import {
	countConflictMarkers,
	formatMergeConflictReport,
	incrementPatchVersion,
} from '../../scripts/workspace-save-lib.mjs';

describe('workspace save helpers', () => {
	it('increments patch versions', () => {
		expect(incrementPatchVersion('0.0.1')).toBe('0.0.2');
		expect(incrementPatchVersion('1.2.3')).toBe('1.2.4');
	});

	it('counts git conflict markers', () => {
		const markers = countConflictMarkers(`<<<<<<< HEAD\nleft\n=======\nright\n>>>>>>> origin/main\n`);
		expect(markers).toEqual({ start: 1, middle: 1, end: 1 });
	});

	it('formats a machine-friendly merge conflict report', () => {
		const report = formatMergeConflictReport(
			{
				branch: 'main',
				rebaseInProgress: true,
				status: 'UU docs/package.json',
				perFile: [
					{
						filePath: 'docs/package.json',
						markers: { start: 1, middle: 1, end: 1 },
						diff: 'diff --cc docs/package.json',
					},
				],
			},
			'/repo',
		);

		expect(report).toContain('Treeseed save failed due to merge conflicts');
		expect(report).toContain('docs/package.json');
		expect(report).toContain('git rebase --continue');
	});
});
