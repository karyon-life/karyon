// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	integrations: [
		starlight({
			title: 'Karyon: The Architecture of a Cellular Graph Intelligence',
			sidebar: [
				{
					label: 'Book Outline',
					link: '/book-outline/',
				},
				{
					label: 'Part I: The Biological Edge in Systems',
					items: [
						{ label: 'Chapter 1: The Problem with Transformers', autogenerate: { directory: 'part-1/chapter-1' } },
						{ label: 'Chapter 2: Principles of Biological Intelligence', autogenerate: { directory: 'part-1/chapter-2' } },
					],
				},
				{
					label: 'Part II: Anatomy of the Organism',
					items: [
						{ label: 'Chapter 3: The Karyon Kernel (Nucleus)', autogenerate: { directory: 'part-2/chapter-3' } },
						{ label: 'Chapter 4: Digital DNA & Epigenetics', autogenerate: { directory: 'part-2/chapter-4' } },
					],
				},
				{
					label: 'Part III: The Rhizome (Memory & Learning)',
					items: [
						{ label: 'Chapter 5: The Extracellular Matrix (Topology)', autogenerate: { directory: 'part-3/chapter-5' } },
						{ label: 'Chapter 6: Synaptic Plasticity & Consolidation', autogenerate: { directory: 'part-3/chapter-6' } },
					],
				},
				{
					label: 'Part IV: Perception and Action',
					items: [
						{ label: 'Chapter 7: Sensory Organs (I/O Constraints)', autogenerate: { directory: 'part-4/chapter-7' } },
						{ label: 'Chapter 8: Motor Functions and Validation', autogenerate: { directory: 'part-4/chapter-8' } },
					],
				},
				{
					label: 'Part V: Consciousness and Autonomy',
					items: [
						{ label: 'Chapter 9: Digital Metabolism & Needs', autogenerate: { directory: 'part-5/chapter-9' } },
						{ label: 'Chapter 10: Sovereign Architecture & Symbiosis', autogenerate: { directory: 'part-5/chapter-10' } },
					],
				},
				{
					label: 'Part VI: Maturation & Lifecycle Execution',
					items: [
						{ label: 'Chapter 11: Bootstrapping Karyon', autogenerate: { directory: 'part-6/chapter-11' } },
						{ label: 'Chapter 12: The Training Curriculum', autogenerate: { directory: 'part-6/chapter-12' } },
					],
				},
			],
		}),
	],
});
