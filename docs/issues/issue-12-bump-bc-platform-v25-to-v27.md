# Issue 12 — fix: Actualizar plataforma BC de v25 a v27 para coincidir con el sandbox

## Contexto

La extensión estaba compilada contra BC 25 (`runtime: 13.0`), pero el sandbox de desarrollo
ejecuta BC 27.5. Esta incompatibilidad provocaba que **cada intento de publicación en el
sandbox fallaba** con el error `Unable to publish app`.

Las implementaciones que aparentaban tener éxito eran falsos positivos: el app ya estaba
presente de una ejecución anterior y el pipeline simplemente no detectaba el error real.

---

## Problema

| Parámetro | Valor anterior (BC 25) | Valor correcto (BC 27) |
|-----------|------------------------|------------------------|
| Artifact en AL-Go | `bcartifacts/sandbox/25/w1/latest` | `bcartifacts/sandbox/27/w1/latest` |
| `platform` (app.json) | `25.0.0.0` | `27.0.0.0` |
| `application` (app.json) | `25.0.0.0` | `27.0.0.0` |
| `runtime` (app.json) | `13.0` | `15.0` |
| Deps mínimas en test/app.json | `25.0.0.0` | `27.0.0.0` |

---

## Cambios realizados

### `.github/AL-Go-Settings.json`

- Artifact actualizado de `bcartifacts/sandbox/25/w1/latest`
  a `bcartifacts/sandbox/27/w1/latest`.

### `app/app.json`

- `platform`: `25.0.0.0` → `27.0.0.0`
- `application`: `25.0.0.0` → `27.0.0.0`
- `runtime`: `13.0` → `15.0`

### `test/app.json`

- `platform`: `25.0.0.0` → `27.0.0.0`
- `application`: `25.0.0.0` → `27.0.0.0`
- Versión mínima de `Library Assert`: `25.0.0.0` → `27.0.0.0`
- Versión mínima de `System Application Test Library`: `25.0.0.0` → `27.0.0.0`

---

## Impacto

- Las publicaciones al sandbox dejan de fallar con `Unable to publish app`.
- Todo el código AL compilado desde este momento es compatible con BC 27 / runtime 15.
- La cadena de dependencias de tests queda alineada con la plataforma objetivo.

---

## Sin código AL cambiado

Este fix es exclusivamente de configuración de manifiesto y CI.  
No se modifica ningún fichero `.al` ni ninguna lógica de negocio.

---

## Criterios de aceptación

- [x] `AL-Go-Settings.json` apunta a `sandbox/27/w1/latest`.
- [x] `app/app.json` declara `platform` y `application` `27.0.0.0`, `runtime` `15.0`.
- [x] `test/app.json` declara las mismas versiones y las dependencias de test alineadas.
- [x] La publicación en el sandbox BC 27.5 se completa sin errores.

---

## Referencias

- [Pull Request #12](https://github.com/DynamITVectorK/DualUoM-BC2/pull/12)
- `.github/AL-Go-Settings.json`
- `app/app.json`
- `test/app.json`
- `docs/ci-cost-decisions.md` — política de CI y artefactos de sandbox

## Etiquetas

`fix` · `infrastructure` · `bc27` · `ci`
