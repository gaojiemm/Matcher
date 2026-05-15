const core = require('@actions/core');

function getInput(name) {
  const directValue = core.getInput(name);

  if (directValue) {
    return directValue;
  }

  const fallbackEnvName = `INPUT_${name.replace(/ /g, '_').replace(/-/g, '_').toUpperCase()}`;
  return process.env[fallbackEnvName] || '';
}

function normalizeBranch(branchName, githubRef) {
  if (branchName.trim()) {
    return branchName.trim();
  }

  const ref = githubRef.trim() || process.env.GITHUB_REF || '';
  if (ref.startsWith('refs/heads/')) {
    return ref.slice('refs/heads/'.length);
  }

  return ref;
}

function decideEnvironment(branch) {
  if (branch === 'main' || branch === 'master') {
    return { environment: 'production', deployEnabled: 'true' };
  }

  if (branch === 'develop' || branch === 'development') {
    return { environment: 'development', deployEnabled: 'true' };
  }

  if (branch.startsWith('release/')) {
    return { environment: 'staging', deployEnabled: 'true' };
  }

  return { environment: 'preview', deployEnabled: 'false' };
}

try {
  const branch = normalizeBranch(getInput('branch-name'), getInput('github-ref'));
  const result = decideEnvironment(branch);

  core.setOutput('environment', result.environment);
  core.setOutput('deploy_enabled', result.deployEnabled);
  core.info(`Selected ${result.environment} for branch ${branch || 'unknown'}.`);
} catch (error) {
  core.setFailed(error.message);
}