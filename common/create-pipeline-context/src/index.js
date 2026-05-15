const core = require('@actions/core');

function getRuntimeLabel() {
  const runtimeMajor = process.versions.node.split('.')[0];
  return `node${runtimeMajor}`;
}

function getInput(name, options = {}) {
  const directValue = core.getInput(name);

  if (directValue) {
    return directValue;
  }

  const fallbackEnvName = `INPUT_${name.replace(/ /g, '_').replace(/-/g, '_').toUpperCase()}`;
  const fallbackValue = process.env[fallbackEnvName] || '';

  if (options.required && !fallbackValue.trim()) {
    throw new Error(`Input required and not supplied: ${name}`);
  }

  return fallbackValue;
}

function parseJsonArray(value, inputName) {
  try {
    const parsed = JSON.parse(value);

    if (!Array.isArray(parsed)) {
      throw new Error('value must be a JSON array');
    }

    return parsed;
  } catch (error) {
    throw new Error(`Invalid ${inputName}: ${error.message}`);
  }
}

function run() {
  const service = getInput('service', { required: true }).trim();
  const testParallelKeys = parseJsonArray(
    getInput('test-parallel-keys'),
    'test-parallel-keys'
  );

  const pipelineContext = {
    service,
    runtime: getRuntimeLabel(),
    generatedAt: new Date().toISOString(),
    testParallelKeys,
  };

  core.setOutput('pipeline-context', JSON.stringify(pipelineContext));
  core.setOutput('test_parallel_keys', JSON.stringify(testParallelKeys));
  core.info(`Generated pipeline context for ${service} on Node 24.`);
}

try {
  run();
} catch (error) {
  core.setFailed(error.message);
}