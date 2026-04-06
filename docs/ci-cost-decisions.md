# CI Cost Decisions — DualUoM-BC

This document explains every cost-saving setting applied in `.github/AL-Go-Settings.json`
and the workflow files.

## AL-Go-Settings.json

| Setting | Value | Reason |
|---|---|---|
| `type` | `"PTE"` | Per-Tenant Extension — correct app type for BC SaaS customisations |
| `country` | `"w1"` | Single locale build; no matrix expansion across countries |
| `artifact` | `"bcartifacts/sandbox/25/w1/latest"` | Sandbox artifact is the smallest BC image available (~40% smaller than OnPrem) |
| `compileModifiedOnly` | `true` | Skip compiling unchanged AL files — dramatically reduces compile time on large repos |
| `cacheImageName` | `""` | Disable Docker image caching (not needed when `useCompilerFolder` is true) |
| `doNotPublishApps` | `true` | No automatic deploy to sandbox on CI — publish is a deliberate manual step |
| `skipUpgrade` | `true` | No upgrade tests — no previous published version exists yet |
| `useCompilerFolder` | `true` | Uses AL compiler folder instead of a Docker container, avoiding container startup overhead |
| `excludeEnvironments` | `["*"]` | Never auto-deploy to any environment from CI; all deployments are manual |
| `buildModes` | `["Default"]` | Skip Clean and Translated build modes — only one build pass per run |
| `runs-on` | `"ubuntu-latest"` | Linux runner costs ~$0.008/min vs Windows ~$0.016/min (~50% saving) |

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
