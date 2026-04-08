# Decisiones de CI/Coste — DualUoM-BC

Este documento explica cada ajuste de ahorro de costes aplicado en `.github/AL-Go-Settings.json`
y en los archivos de workflow.

## AL-Go-Settings.json

| Ajuste | Valor | Motivo |
|---|---|---|
| `type` | `"PTE"` | Extensión de inquilino propio — tipo de app correcto para personalizaciones de BC SaaS |
| `country` | `"w1"` | Compilación de una sola localización; sin expansión de matriz entre países |
| `artifact` | `"bcartifacts/sandbox/27/w1/latest"` | El artefacto sandbox es la imagen BC más pequeña disponible (~40% más pequeña que OnPrem) |
| `compileModifiedOnly` | `true` | Omitir la compilación de archivos AL sin cambios — reduce drásticamente el tiempo de compilación en repos grandes |
| `cacheImageName` | `""` | Deshabilitar el caché de imagen Docker — en su lugar se usa el caché de artefactos BC |
| `doNotPublishApps` | `false` | Las apps deben instalarse en el contenedor Docker para que las apps de prueba puedan ejecutarse; el despliegue en entornos online se bloquea por separado con `excludeEnvironments: ["*"]` en la configuración global |
| `skipUpgrade` | `true` | Sin pruebas de actualización — aún no existe una versión publicada anterior |
| `excludeEnvironments` | `["*"]` | No desplegar automáticamente en ningún entorno desde CI; todos los despliegues son manuales |
| `buildModes` | `["Default"]` | Omitir los modos de compilación Clean y Translated — solo una pasada de compilación por ejecución |
| `runs-on` | `"windows-latest"` | El runner de Windows es necesario para la ejecución del contenedor Docker de BC (la ejecución de pruebas necesita un nivel de servicio BC en ejecución) |

### Nota sobre `System Application Test Library` (eliminado de las dependencias)

`Microsoft_System Application Test Library` estaba listado como dependencia en `test/app.json` y
en `installTestApps` en `.AL-Go/settings.json`, pero no es usado por ningún codeunit de prueba en
este repositorio. En modo de compilación Docker/contenedor (cuando `useCompilerFolder` no está establecido), el
runtime de AL-Go no puede descargar símbolos para esta biblioteca con el especificador de versión `27.0.0.0`,
porque el archivo real en el artefacto sandbox de BC 27.5 usa la versión de compilación completa
(p. ej. `27.5.xxx.xxx`) y la descarga falla con `WARNING: Unable to download symbols`.
Esto causaba un error de compilación fatal `AL1022`.

Se han eliminado tanto la entrada de dependencia en `test/app.json` como la entrada `installTestApps` en
`.AL-Go/settings.json`. Cualquier prueba futura que requiera tipos de esta biblioteca debe
volver a añadir la dependencia con la versión correcta resuelta.

### Nota sobre `useCompilerFolder` (eliminado)

`useCompilerFolder: true` se estableció previamente como medida de ahorro de costes para evitar la
sobrecarga de inicio del contenedor Docker. Sin embargo, este ajuste **impide completamente la ejecución de pruebas**: AL-Go en
modo compiler-folder solo puede compilar apps AL — no puede ejecutar pruebas porque no hay
nivel de servicio BC. La causa raíz de los artefactos `TestResults.xml` faltantes era este ajuste.

El ajuste se ha eliminado para que AL-Go arranque un contenedor Docker de BC en el runner de Windows
y ejecute los codeunits de prueba. El job de compilación ahora se ejecuta en `windows-latest`
(necesario para Docker). La compensación es aceptada: la ejecución automatizada de pruebas tiene prioridad
sobre el ahorro marginal de costes del modo solo compilador.

## Disparadores de workflow

Todos los archivos de workflow usan **únicamente** el disparador `workflow_dispatch:`.

Disparadores eliminados:
- `push:` — se dispararía en cada commit, consumiendo minutos continuamente
- `pull_request:` — se dispararía en cada actualización de PR
- `schedule:` — se dispararía periódicamente incluso sin cambios de código
- encadenamiento automático `workflow_call:` — eliminado de `PullRequestHandler.yaml` para evitar la invocación automática

## Control de concurrencia

Cada workflow que puede dispararse manualmente más de una vez incluye:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Esto cancela una ejecución en cola o en curso del mismo workflow en la misma rama
cuando se lanza una ejecución más reciente, evitando la facturación duplicada.

## Caché del compilador AL

Se añade un paso `actions/cache@v4` en `_BuildALGoProject.yaml` antes del paso de compilación AL:

```yaml
- name: Cache AL compiler
  uses: actions/cache@v4
  with:
    path: ~/.alcache
    key: al-compiler-${{ hashFiles('.github/AL-Go-Settings.json') }}
    restore-keys: al-compiler-
```

Esto almacena en caché la carpeta del compilador AL entre ejecuciones. La clave de caché se basa en el
archivo `AL-Go-Settings.json`, por lo que el caché se invalida cuando cambia la versión del artefacto BC
u otros ajustes de compilación.

## Compilación de un solo job (sin matriz)

`buildModes: ["Default"]` combinado con un único `country: "w1"` garantiza que AL-Go
genere solo una dimensión de compilación, no una matriz. Una matriz de múltiples versiones de BC
o países multiplicaría los minutos de runner.
