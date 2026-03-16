# Problem Matcher Demo for GitHub Actions

This repository demonstrates how to use a custom GitHub Actions problem matcher to turn plain command-line output into structured annotations in the Actions UI.

## What Is a Problem Matcher

Problem matchers let GitHub Actions recognize errors and warnings from tool output. If a line of output matches a configured regular expression, GitHub can attach that issue to a file, line, and column so it shows up in the workflow summary and log annotations.

This is useful when:

- You have an internal script that prints errors in a fixed format.
- You want lightweight annotations without building a full GitHub Action.
- You need CI logs to point directly to the failing source location.

## Repository Structure

This repository now includes a complete runnable demo:

```text
.github/
	problem-matcher.json
	workflows/
		demo.yml
demo/
	example.js
scripts/
	emit-demo-errors.sh
README.md
```

## Matcher Configuration

The matcher is defined in `.github/problem-matcher.json` and uses this pattern:

```json
{
	"version": "0.2",
	"problemMatcher": [
		{
			"owner": "test-failure",
			"source": "test",
			"applyTo": "allDocuments",
			"fileLocation": ["relative"],
			"pattern": [
				{
					"regexp": "^(.*):(\\d+):(\\d+)\\s+(.*)$",
					"file": 1,
					"line": 2,
					"column": 3,
					"message": 4
				}
			]
		}
	]
}
```

It expects command output in this exact format:

```text
path/to/file.ext:line:column message
```

Example:

```text
src/example.js:12:5 Unexpected token
tests/login.spec.ts:34:9 Assertion failed: expected 200, received 500
```

## How It Works

The regular expression captures four values:

1. File path
2. Line number
3. Column number
4. Message text

When a log line matches, GitHub Actions creates an annotation tied to that file location. Because `fileLocation` is set to `relative`, the printed file path should be relative to the repository root.

## Using the Matcher in a Workflow

You can load the matcher at runtime with the special `::add-matcher::` command.

The repository already includes a working example in `.github/workflows/demo.yml`.

It does three things:

1. Registers the matcher.
2. Runs a script that prints matching diagnostics.
3. Removes the matcher at the end of the job.

Workflow content:

```yaml
name: Problem Matcher Demo

on:
	workflow_dispatch:
	push:

jobs:
	demo:
		runs-on: ubuntu-latest
		steps:
			- name: Checkout
				uses: actions/checkout@v4

			- name: Register problem matcher
				run: echo '::add-matcher::.github/problem-matcher.json'

			- name: Emit demo diagnostics
				run: bash scripts/emit-demo-errors.sh

			- name: Remove problem matcher
				if: always()
				run: echo '::remove-matcher owner=test-failure::'
```

Once the job runs, the output from `scripts/emit-demo-errors.sh` should appear as annotations against `demo/example.js` in the Actions log.

## Demo Script Output

The demo script prints these lines:

```text
demo/example.js:4:3 Unexpected console usage in demo check
demo/example.js:9:10 Missing validation before request execution
demo/example.js:14:5 Hard-coded fallback should be removed
```

Because `demo/example.js` exists in the repository, GitHub Actions can attach each annotation to a real file location.

## Local Output Rules

If you want your own script or test runner to work with this matcher, make sure it prints lines that follow the configured format exactly.

Good:

```text
src/app.py:18:2 Undefined variable 'user_id'
```

Not matched:

```text
Error in src/app.py on line 18: Undefined variable 'user_id'
```

The second example will not be recognized because it does not match the configured regular expression.

## Common Use Cases

- Custom test harnesses
- Internal linters
- Build scripts
- Migration or validation scripts
- Monorepo tooling that emits file-based diagnostics

## Debugging Tips

If annotations are not showing up in GitHub Actions, check the following:

1. The matcher file is loaded with `::add-matcher::` before the output is printed.
2. The logged path is relative to the repository root.
3. The output line includes both line and column numbers.
4. The output format matches the regexp exactly.
5. The file actually exists in the checked-out workspace.

## Running the Demo

To see the matcher in action:

1. Push the repository to GitHub.
2. Open the Actions tab.
3. Run the `Problem Matcher Demo` workflow, or trigger it with a push to `main`.
4. Open the job log and inspect the generated annotations.

## Next Improvement Ideas

This demo can be extended in a few useful ways:

- Support warnings and errors with separate matcher definitions.
- Add multi-line patterns for stack traces or grouped test output.
- Add a second matcher for another tool format.
- Add a small test step that asserts the script output format stays compatible.

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Problem Matchers Documentation](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#problem-matchers)