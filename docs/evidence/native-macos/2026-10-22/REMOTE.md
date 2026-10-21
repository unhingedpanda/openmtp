# Remote verification

Status: remote verification authorized by the user on 2026-10-22.
The user accepted a public fork with a standard GitHub-hosted macOS runner.
Desktop automation on the user's Mac remains disabled.
Fork: [unhingedpanda/openmtp](https://github.com/unhingedpanda/openmtp/tree/codex/native-macos-ui).
The fork's default branch is `codex/native-macos-ui` to support manual workflow dispatch.

## Execution

The workflow is `.github/workflows/native-macos.yml`.
It uses the standard `macos-26` arm64 runner.
Manual dispatch can select the standard `xcode-27` runner for macOS 27 coverage.
The two environments use separate concurrency groups.
The job skips private repositories before allocating a runner.
The workflow runs when native files change on `codex/native-macos-ui`.
The workflow also supports manual dispatch after registration on a default branch.

The job builds the release preview and verifies its bundle.
It runs behavior and UI tests before measuring browser and process performance separately.
A failed measurement cannot masquerade as a passing behavior gate.
The job preserves logs, JSON, and XCTest results for three days.
It does not publish an application binary or create an upstream pull request.
Local verification and benchmark entry points refuse desktop execution unless explicitly given `--allow-desktop`.

## Acceptance limits

Remote timings describe the hosted Mac, not the user's Mac.
The specification's thresholds remain unchanged.
The original host performance targets remain unverified until explicitly authorized on that host.
Real phone transfers, integrity, throughput, and physical device drag-and-drop require separate hardware checks.

The first remote run retains the existing performance harness to establish whether its crash reproduces.
Fixes must follow observed failures.
Original interrupted local evidence remains preserved.

## Cost boundary

Checked on 2026-10-22: standard hosted runners have free runner minutes for public repositories.
Private repositories consume their owner's included allowance.
Larger runners incur charges even in public repositories.
Artifact and cache storage have separate allowances.

Sources:

- [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- [Runner selection](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job)

No larger runner, paid service, or local VM is configured.
