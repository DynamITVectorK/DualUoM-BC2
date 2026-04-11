# Issue 2 — DUoM Calculation Engine

## Descripción

Crear el codeunit central de cálculo (`DUoM Calc Engine`, ID 50101) que transforma una
cantidad primaria en su equivalente en segunda unidad de medida, aplicando el modo de
conversión correcto. Este codeunit será consumido por todos los módulos de transacciones
(compras, ventas, inventario) que se implementen en issues posteriores.

> ⚠️ Al mergear este issue debe eliminarse el codeunit temporal `DualUoMPipelineCheck`
> y su test (`DualUoMPipelineCheckTests`), ya que sólo sirvieron como placeholder de
> pipeline mientras el proyecto arrancaba.

---

## Alcance

### Archivos a crear

| Ruta | Objeto |
|---|---|
| `app/src/codeunit/DualUoMCalcEngine.Codeunit.al` | Codeunit 50101 `DUoM Calc Engine` |
| `test/src/codeunit/DualUoMCalcEngineTests.Codeunit.al` | Codeunit 50203 `DUoM Calc Engine Tests` |

### Archivos a eliminar

| Ruta | Motivo |
|---|---|
| `app/src/codeunit/DualUoMPipelineCheck.Codeunit.al` | Placeholder temporal — reemplazado por el Calc Engine |
| `test/src/codeunit/DualUoMPipelineCheckTests.Codeunit.al` | Test del placeholder — ya no necesario |

---

## Requisitos funcionales

### Firma de la función principal

```al
procedure ComputeSecondQty(FirstQty: Decimal; Ratio: Decimal; Mode: Enum "DUoM Conversion Mode"): Decimal
```

### Comportamiento por modo de conversión

| Modo | Comportamiento |
|---|---|
| `Fixed` | `SecondQty = FirstQty × Ratio`. Error si `Ratio ≤ 0`. |
| `Variable` | `SecondQty = FirstQty × Ratio`. Error si `Ratio ≤ 0`. |
| `AlwaysVariable` | Devuelve `0` (el usuario introducirá el valor manualmente en el documento). |

### Validaciones de entrada

- `FirstQty` debe ser ≥ 0; error si es negativo.
- `Ratio` debe ser > 0 para los modos `Fixed` y `Variable`; error si no.
- Para `AlwaysVariable` el parámetro `Ratio` es ignorado y no se valida.

### Redondeo

El resultado se redondea a 5 decimales (`Round(Result, 0.00001)`), coherente con la
propiedad `DecimalPlaces = 0 : 5` del campo `Fixed Ratio` en `DUoM Item Setup`.

---

## Requisitos de tests (TDD obligatorio)

Escribir el test codeunit **antes** de la implementación. Casos mínimos obligatorios:

| # | Caso | Resultado esperado |
|---|---|---|
| 1 | Fixed — qty positiva, ratio válido | `10 × 0.8 = 8` |
| 2 | Fixed — ratio = 0 | Error |
| 3 | Fixed — qty = 0 | `0` |
| 4 | Variable — qty positiva, ratio válido | Mismo comportamiento que Fixed |
| 5 | Variable — ratio = 0 | Error |
| 6 | AlwaysVariable — cualquier qty y ratio | Siempre devuelve `0` |
| 7 | FirstQty negativa (cualquier modo) | Error |
| 8 | Resultado con decimales | Verificar redondeo a 5 decimales |

Patrón de comentarios obligatorio en cada procedimiento de test:

```al
// [GIVEN] ...
// [WHEN]  ...
// [THEN]  ...
```

---

## Criterios de aceptación

- [ ] `DualUoMCalcEngine.Codeunit.al` compila sin warnings (CodeCop, PerTenantExtensionCop, UICop).
- [ ] Todos los tests del codeunit 50203 pasan en CI.
- [ ] `DualUoMPipelineCheck.Codeunit.al` y `DualUoMPipelineCheckTests.Codeunit.al` han sido eliminados.
- [ ] El permission set `DUoM - All` (ID 50100) no requiere actualización (un codeunit no es un objeto securable de datos).
- [ ] `NoImplicitWith` respetado — sin `with` implícito en ningún fichero nuevo.
- [ ] El XLF de localización (`DualUoM-BC.en-US.xlf`) está actualizado si se añaden nuevas Labels de error.

---

## Notas de implementación

- **ID de producción:** 50101 — el codeunit de pipeline check ocupa el codeunit ID interno
  pero el objeto `DualUoMPipelineCheck` se elimina en este mismo issue, liberando el nombre.
- **ID de test:** 50203 — los IDs 50201 y 50202 están ocupados por `DUoM Item Setup Tests`
  y `DUoM Item Card Opening Tests`.
- El codeunit debe declararse `Access = Public` para ser invocado desde los subscribers de
  Purchase (Issue 4–5), Sales (Issue 6–7) e Inventory (Issue 8).
- No añadir dependencias externas; usar únicamente la API estándar de BC 27.
- El enum `DUoM Conversion Mode` (ID 50100) ya existe en `app/src/enum/DUoMConversionMode.Enum.al`.

---

## Dependencias

| Issue | Estado | Relación |
|---|---|---|
| Issue 1 — Project Governance | ✅ Completado | Prerrequisito |
| Issue 3 — Item DUoM Setup Table & Page | ✅ Completado | Proporciona el enum necesario |
| Issue 4 — Purchase Line DUoM Fields | ⏳ Pendiente | **Bloqueado** por este issue |

---

## Labels

`enhancement` · `phase-1-mvp` · `tdd` · `calc-engine`
