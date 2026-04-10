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
| `doNotPublishApps` | `false` | Apps must be installed into the Docker container so test apps can run; deployment to online environments is blocked separately by `excludeEnvironments: ["*"]` in the global settings |
| `skipUpgrade` | `true` | No upgrade tests — no previous published version exists yet |
| `excludeEnvironments` | `["*"]` | Never auto-deploy to any environment from CI; all deployments are manual |
| `buildModes` | `["Default"]` | Skip Clean and Translated build modes — only one build pass per run |
| `runs-on` | `"windows-2022"` | Windows Server 2022 runner — tiene Docker pre-instalado, necesario para arrancar el contenedor BC y ejecutar los tests |

### Note on `System Application Test Library` (removed from dependencies)

`Microsoft_System Application Test Library` was listed as a dependency in `test/app.json` and
in `installTestApps` in `.AL-Go/settings.json`, but it is not used by any test codeunit in
this repository. In Docker/container build mode (when `useCompilerFolder` is not set), the
AL-Go runtime cannot download symbols for this library with the `27.0.0.0` version specifier,
because the actual file in the BC 27.5 sandbox artifact uses the full build version
(e.g. `27.5.xxx.xxx`) and the download fails with `WARNING: Unable to download symbols`.
This caused a fatal `AL1022` compile error.

Both the dependency entry in `test/app.json` and the `installTestApps` entry in
`.AL-Go/settings.json` have been removed. Any future test that requires types from this
library should re-add the dependency with the correct resolved version.

### Nota sobre el runner y Docker

El runner `windows-latest` apunta a Windows Server 2025 Datacenter, donde el daemon Docker
**no está disponible**. Intentar arrancar un contenedor BC produce el error:

> `failed to connect to the docker API at npipe:////./pipe/docker_engine`

La solución es usar `runs-on: windows-2022` (Windows Server 2022), que tiene Docker
pre-instalado con soporte para contenedores Windows. Esto permite a AL-Go arrancar el
contenedor BC y ejecutar los test codeunits normalmente.

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
