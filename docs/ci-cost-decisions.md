# CI Cost Decisions — DualUoM-BC

This document explains every cost-saving setting applied in `.github/AL-Go-Settings.json`
and the workflow files.

## AL-Go-Settings.json

| Setting | Value | Reason |
|---|---|---|
| `type` | `"PTE"` | Per-Tenant Extension — correct app type for BC SaaS customisations |
| `country` | `"w1"` | Single locale build; no matrix expansion across countries |
| `artifact` | `"bcartifacts/sandbox/27/w1/latest"` | Sandbox artifact is the smallest BC image available (~40% smaller than OnPrem) |
| `compileModifiedOnly` | `true` | Skip compiling unchanged AL files — dramatically reduces compile time on large repos |
| `cacheImageName` | `""` | Disable Docker image caching — BC artifact cache is used instead |
| `doNotPublishApps` | `true` | No automatic deploy to sandbox on CI — publish is a deliberate manual step |
| `skipUpgrade` | `true` | No upgrade tests — no previous published version exists yet |
| `excludeEnvironments` | `["*"]` | Never auto-deploy to any environment from CI; all deployments are manual |
| `buildModes` | `["Default"]` | Skip Clean and Translated build modes — only one build pass per run |
| `runs-on` | `"windows-latest"` | Windows runner is required for BC Docker container execution (test execution needs a running BC service tier) |

### Note on `useCompilerFolder` (removed)

`useCompilerFolder: true` was previously set as a cost-saving measure to avoid Docker container
startup overhead. However, this setting **prevents test execution entirely**: AL-Go in
compiler-folder mode can only compile AL apps — it cannot run tests because there is no
BC service tier. The root cause of missing `TestResults.xml` artifacts was this setting.

The setting has been removed so that AL-Go spins up a BC Docker container on the Windows
runner and executes the test codeunits. The build job now runs on `windows-latest`
(required for Docker). The trade-off is accepted: automated test execution takes precedence
over the marginal cost saving from compiler-only mode.

## Workflow triggers

All workflow files use **only** `workflow_dispatch:` trigger.

Removed triggers:
- `push:` — would fire on every commit, consuming minutes continuously
- `pull_request:` — would fire on every PR update
- `schedule:` — would fire periodically even with no code changes
- `workflow_call:` auto-chaining — removed from `PullRequestHandler.yaml` to prevent automatic invocation

## Concurrency control

Every workflow that could be triggered manually more than once includes:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

This cancels a queued or in-progress run of the same workflow on the same branch
when a newer run is dispatched, preventing duplicate billing.

## AL compiler cache

A `actions/cache@v4` step is added in `_BuildALGoProject.yaml` before the AL build step:

```yaml
- name: Cache AL compiler
  uses: actions/cache@v4
  with:
    path: ~/.alcache
    key: al-compiler-${{ hashFiles('.github/AL-Go-Settings.json') }}
    restore-keys: al-compiler-
```

This caches the AL compiler folder between runs. The cache key is based on the
`AL-Go-Settings.json` file, so the cache is invalidated whenever the BC artifact
version or other build settings change.

## Single-job build (no matrix)

`buildModes: ["Default"]` combined with a single `country: "w1"` ensures AL-Go
generates only one build dimension, not a matrix. A matrix across multiple BC
versions or countries would multiply runner minutes.
