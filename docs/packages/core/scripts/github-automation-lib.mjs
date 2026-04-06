import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, relative, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { loadTreeseedDeployConfig } from '../src/deploy/config.mjs';
import { packageRoot } from './package-tools.mjs';

function envOrNull(key) {
	const value = process.env[key];
	return typeof value === 'string' && value.length > 0 ? value : null;
}

export function parseGitHubRepositoryFromRemote(remoteUrl) {
	if (!remoteUrl) {
		return null;
	}

	const sshMatch = remoteUrl.match(/^git@github\.com:([^/]+)\/(.+?)(?:\.git)?$/);
	if (sshMatch) {
		return `${sshMatch[1]}/${sshMatch[2]}`;
	}

	const httpsMatch = remoteUrl.match(/^https:\/\/github\.com\/([^/]+)\/(.+?)(?:\.git)?$/);
	if (httpsMatch) {
		return `${httpsMatch[1]}/${httpsMatch[2]}`;
	}

	return null;
}

function runGit(args, { cwd, allowFailure = false, capture = true } = {}) {
	const result = spawnSync('git', args, {
		cwd,
		stdio: capture ? 'pipe' : 'inherit',
		encoding: 'utf8',
	});

	if (result.status !== 0 && !allowFailure) {
		throw new Error(result.stderr?.trim() || result.stdout?.trim() || `git ${args.join(' ')} failed`);
	}

	return result;
}

function runGh(args, { cwd, allowFailure = false, capture = true, input } = {}) {
	const result = spawnSync('gh', args, {
		cwd,
		stdio: capture || input !== undefined ? ['pipe', 'pipe', 'pipe'] : 'inherit',
		encoding: 'utf8',
		input,
	});

	if (result.error && result.error.code === 'ENOENT') {
		throw new Error('GitHub CLI `gh` is required for Treeseed GitHub automation.');
	}

	if (result.status !== 0 && !allowFailure) {
		throw new Error(result.stderr?.trim() || result.stdout?.trim() || `gh ${args.join(' ')} failed`);
	}

	return result;
}

export function resolveGitHubRepositorySlug(tenantRoot) {
	const remoteResult = runGit(['remote', 'get-url', 'origin'], { cwd: tenantRoot });
	const remoteUrl = remoteResult.stdout?.trim() ?? '';
	const repository = parseGitHubRepositoryFromRemote(remoteUrl);
	if (!repository) {
		throw new Error(`Unable to determine GitHub repository from origin remote "${remoteUrl}".`);
	}
	return repository;
}

export function resolveGitRepositoryRoot(tenantRoot) {
	const result = runGit(['rev-parse', '--show-toplevel'], { cwd: tenantRoot, allowFailure: true });
	return result.status === 0 ? result.stdout.trim() : tenantRoot;
}

export function requiredGitHubSecrets(tenantRoot) {
	const deployConfig = loadTreeseedDeployConfig();
	const secrets = [
		'CLOUDFLARE_API_TOKEN',
		'TREESEED_FORM_TOKEN_SECRET',
	];

	if (deployConfig.turnstile?.enabled !== false) {
		secrets.push('TREESEED_PUBLIC_TURNSTILE_SITE_KEY', 'TREESEED_TURNSTILE_SECRET_KEY');
	}

	if (deployConfig.smtp?.enabled) {
		secrets.push(
			'TREESEED_SMTP_HOST',
			'TREESEED_SMTP_PORT',
			'TREESEED_SMTP_USERNAME',
			'TREESEED_SMTP_PASSWORD',
			'TREESEED_SMTP_FROM',
			'TREESEED_SMTP_REPLY_TO',
		);
	}

	return [...new Set(secrets)];
}

export function renderDeployWorkflow({ workingDirectory }) {
	const normalizedWorkingDirectory = workingDirectory && workingDirectory !== '.' ? workingDirectory : '.';
	const workingDirectoryLine = normalizedWorkingDirectory === '.'
		? ''
		: `    defaults:\n      run:\n        working-directory: ${normalizedWorkingDirectory}\n`;
	const templatePath = resolve(packageRoot, 'templates', 'github', 'deploy.workflow.yml');
	const template = readFileSync(templatePath, 'utf8');

	return template
		.replace('__WORKING_DIRECTORY_BLOCK__', workingDirectoryLine)
		.replace(
			'__CACHE_DEPENDENCY_PATH__',
			normalizedWorkingDirectory === '.' ? 'package-lock.json' : `${normalizedWorkingDirectory}/package-lock.json`,
		);
}

export function ensureDeployWorkflow(tenantRoot) {
	const repositoryRoot = resolveGitRepositoryRoot(tenantRoot);
	const workflowPath = resolve(tenantRoot, '.github', 'workflows', 'deploy.yml');
	const workingDirectory = relative(repositoryRoot, tenantRoot).replaceAll('\\', '/') || '.';
	const expected = renderDeployWorkflow({ workingDirectory });
	const current = existsSync(workflowPath) ? readFileSync(workflowPath, 'utf8') : null;

	if (current === expected) {
		return { workflowPath, changed: false, workingDirectory };
	}

	mkdirSync(dirname(workflowPath), { recursive: true });
	writeFileSync(workflowPath, expected, 'utf8');
	return { workflowPath, changed: true, workingDirectory };
}

export function listGitHubSecretNames(repository, tenantRoot) {
	const result = runGh(['secret', 'list', '--repo', repository, '--json', 'name'], {
		cwd: tenantRoot,
	});
	return new Set(
		(JSON.parse(result.stdout || '[]'))
			.map((entry) => entry?.name)
			.filter((value) => typeof value === 'string' && value.length > 0),
	);
}

export function formatMissingSecretsReport(repository, missingSecrets, reason = 'missing_local_env') {
	const lines = [
		'Treeseed GitHub secret sync failed.',
		`Repository: ${repository}`,
		`Reason: ${reason}`,
		'Missing secrets:',
	];

	for (const secret of missingSecrets) {
		lines.push(`- ${secret.name}: localEnv=${secret.localEnvPresent ? 'present' : 'missing'} remote=${secret.remotePresent ? 'present' : 'missing'}`);
	}

	return lines.join('\n');
}

export function ensureGitHubSecrets(tenantRoot, { dryRun = false } = {}) {
	const repository = resolveGitHubRepositorySlug(tenantRoot);
	const requiredSecrets = requiredGitHubSecrets(tenantRoot);
	const existingSecrets = listGitHubSecretNames(repository, tenantRoot);
	const missingRemote = requiredSecrets.filter((name) => !existingSecrets.has(name));

	const missingLocal = missingRemote
		.filter((name) => !envOrNull(name))
		.map((name) => ({ name, localEnvPresent: false, remotePresent: false }));

	if (missingLocal.length > 0) {
		throw new Error(formatMissingSecretsReport(repository, missingLocal));
	}

	const created = [];
	for (const name of missingRemote) {
		if (dryRun) {
			created.push(name);
			continue;
		}
		runGh(['secret', 'set', name, '--repo', repository, '--body', envOrNull(name) ?? ''], {
			cwd: tenantRoot,
		});
		created.push(name);
	}

	return {
		repository,
		existing: requiredSecrets.filter((name) => existingSecrets.has(name)),
		created,
	};
}

export function ensureGitHubDeployAutomation(tenantRoot, { dryRun = false } = {}) {
	const workflow = ensureDeployWorkflow(tenantRoot);
	const secrets = ensureGitHubSecrets(tenantRoot, { dryRun });
	return {
		workflow,
		secrets,
	};
}
