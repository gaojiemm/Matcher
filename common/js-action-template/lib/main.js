const core = require('@actions/core');
function getRuntimeMajor() {
    return process.versions.node.split('.')[0];
}
function parsePayload(rawPayload) {
    let parsed;
    try {
        parsed = JSON.parse(rawPayload);
    }
    catch (error) {
        throw new Error(`Invalid payload: ${error.message}`);
    }
    if (!parsed || Array.isArray(parsed) || typeof parsed !== 'object') {
        throw new Error('Invalid payload: value must be a JSON object');
    }
    return parsed;
}
try {
    const name = core.getInput('name', { required: true }).trim();
    const payload = parsePayload(core.getInput('payload'));
    const message = `Hello, ${name} from Node ${getRuntimeMajor()}.`;
    core.setOutput('message', message);
    core.setOutput('payload', JSON.stringify(payload));
    core.info(message);
}
catch (error) {
    core.setFailed(error.message);
}
