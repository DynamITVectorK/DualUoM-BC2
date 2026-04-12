# Issue 11 — Aplicar `Rounding Precision` de la UoM secundaria a `DUoM Second Qty`

## Contexto

El campo `"DUoM Second Qty"` está declarado con `DecimalPlaces = 0 : 5` en todas las
tableextensions que lo contienen (Purchase Line, Sales Line, Item Journal Line y sus
correspondientes líneas de documentos contabilizados). Esto significa que actualmente
el sistema **acepta y calcula valores como 11,5 piezas**, lo cual no tiene sentido
físico cuando la segunda UoM es una unidad discreta (PCS, CAJA, PALET, etc.).

Business Central ya dispone de un mecanismo estándar para gestionar esta restricción:
el campo `Rounding Precision` de la tabla `Unit of Measure` (p. ej. `1` para PCS,
`0.001` para KG). Sin embargo, la extensión DualUoM-BC ignora ese dato en dos puntos
críticos:

1. **Cálculo automático** (`DUoM Calc Engine`): `ComputeSecondQty` devuelve
   `FirstQty × Ratio` sin redondear. Ejemplo: 10 KG × ratio 1,15 = **11,5 PCS**.
2. **Entrada manual** (modo `AlwaysVariable`): el usuario puede teclear `11,5 PCS`
   directamente en el campo sin que el sistema lo redondee ni rechace.

---

## Comportamiento esperado

| Escenario | Segunda UoM | Rounding Precision | Qty | Ratio | Resultado actual | Resultado esperado |
|-----------|-------------|-------------------|-----|-------|-----------------|-------------------|
| Cálculo Fixed | PCS | 1 | 10 | 1,15 | 11,5 | **12** |
| Cálculo Fixed | KG | 0,001 | 10 | 1,15 | 11,5 | **11,5** (sin cambio) |
| Cálculo Variable | PCS | 1 | 10 | 1,3 | 13 | **13** (sin cambio) |
| Entrada manual | PCS | 1 | — | — | 11,5 (aceptado) | **12** (redondeado) |
| Sin configuración | cualquiera | 0 | 10 | 1,15 | 11,5 | **11,5** (sin cambio — fallback) |

> Cuando `Rounding Precision = 0` (registro BC antiguo), usar `0.00001` como
> fallback. Esto reproduce el comportamiento actual sin truncamiento apreciable.

---

## Diseño de la solución

### Principio

Centralizar la lógica de redondeo en un helper reutilizable para no duplicar código
en cada tableextension y suscriptor. El motor de cálculo existente `DUoM Calc Engine`
(codeunit 50101) se extiende con una sobrecarga que acepta la precisión como parámetro.

### Archivos afectados

#### 1. `app/src/codeunit/DUoMCalcEngine.Codeunit.al` (50101)

Añadir sobrecarga `ComputeSecondQtyRounded` que acepta `RoundingPrecision: Decimal`
y aplica `Round(result, EffectivePrecision)` antes de devolver el valor:

```al
/// <summary>
/// Igual que ComputeSecondQty pero aplica Round() usando la precisión de la UoM secundaria.
/// Cuando RoundingPrecision = 0, usa 0.00001 como fallback (máxima precisión).
/// </summary>
procedure ComputeSecondQtyRounded(FirstQty: Decimal; Ratio: Decimal;
    Mode: Enum "DUoM Conversion Mode"; RoundingPrecision: Decimal): Decimal
var
    Result: Decimal;
    EffectivePrecision: Decimal;
begin
    Result := ComputeSecondQty(FirstQty, Ratio, Mode);
    if Mode = Mode::AlwaysVariable then
        exit(Result);  // AlwaysVariable siempre devuelve 0; Round innecesario
    EffectivePrecision := RoundingPrecision;
    if EffectivePrecision <= 0 then
        EffectivePrecision := 0.00001;
    exit(Round(Result, EffectivePrecision));
end;
```

La firma original `ComputeSecondQty(FirstQty, Ratio, Mode)` se mantiene sin cambios
para preservar compatibilidad con todos los llamadores existentes.

#### 2. `app/src/codeunit/DUoMPurchaseSubscribers.Codeunit.al` y `DUoMSalesSubscribers.Codeunit.al`

En los suscriptores que actualmente llaman a `ComputeSecondQty`, obtener la
`Rounding Precision` de la `Unit of Measure` cuyo código es
`DUoMItemSetup."Second UoM Code"` y llamar a `ComputeSecondQtyRounded`.

Patrón de lectura de la precisión:

```al
local procedure GetSecondUoMRoundingPrecision(ItemNo: Code[20]): Decimal
var
    DUoMItemSetup: Record "DUoM Item Setup";
    UnitOfMeasure: Record "Unit of Measure";
begin
    if not DUoMItemSetup.Get(ItemNo) then
        exit(0);
    if DUoMItemSetup."Second UoM Code" = '' then
        exit(0);
    if UnitOfMeasure.Get(DUoMItemSetup."Second UoM Code") then
        exit(UnitOfMeasure."Rounding Precision");
    exit(0);
end;
```

#### 3. `app/src/tableextension/DUoMPurchaseLine.TableExt.al`, `DUoMSalesLine.TableExt.al`, `DUoMItemJournalLine.TableExt.al`

En el trigger `OnValidate` del campo `"DUoM Second Qty"` (entrada manual del usuario),
añadir redondeo al valor introducido:

```al
trigger OnValidate()
var
    DUoMCalcEngine: Codeunit "DUoM Calc Engine";
    RoundingPrecision: Decimal;
begin
    RoundingPrecision := GetSecondUoMRoundingPrecision(Rec."No.");
    if RoundingPrecision > 0 then
        "DUoM Second Qty" := Round("DUoM Second Qty", RoundingPrecision);
end;
```

> **Nota:** La función `GetSecondUoMRoundingPrecision` puede extraerse a un helper
> compartido (p. ej. un nuevo `codeunit 50106 "DUoM UoM Helper"`) para evitar
> duplicación entre tableextensions y suscriptores.

#### 4. `test/src/codeunit/DUoMCalcEngineTests.Codeunit.al` (50204)

Añadir los siguientes casos de prueba:

| Procedimiento de test | Scenario |
|---|---|
| `ComputeSecondQtyRounded_DiscreteUoM` | Ratio=1.15, Qty=10, Precision=1 → **12** |
| `ComputeSecondQtyRounded_ContinuousUoM` | Ratio=1.15, Qty=10, Precision=0.001 → **11.5** |
| `ComputeSecondQtyRounded_ZeroPrecisionFallback` | Precision=0 → **11.5** (mismo que sin redondeo) |
| `ComputeSecondQtyRounded_AlwaysVariable` | Mode=AlwaysVariable → **0** (Round no aplica) |

#### 5. Tests de integración en `DUoMPurchaseTests.Codeunit.al` (50205) y `DUoMSalesTests.Codeunit.al` (50206)

Añadir al menos un test de integración end-to-end que verifique que al cambiar la
cantidad en una línea de pedido configurada con una UoM discreta (`Rounding Precision = 1`),
el campo `"DUoM Second Qty"` se almacena redondeado.

---

## Restricciones y decisiones de diseño

| Restricción | Decisión |
|---|---|
| No modificar `DecimalPlaces` en la definición del campo | Mantener `0 : 5` para conservar precisión en conversiones continuas. El redondeo es lógico, no de almacenamiento. |
| No bloquear el posting por cantidad no entera | Fuera de scope de este issue (Phase 2 si se necesita). |
| Compatibilidad hacia atrás | `ComputeSecondQty` (sin parámetro de precisión) no cambia. Solo se añade sobrecarga. |
| Leer desde `Unit of Measure`, no desde `Item Unit of Measure` | Simplificación Phase 1. Granularidad por UoM de conversión del ítem queda para Phase 2. |

---

## Lo que NO entra en este issue

- Leer `Rounding Precision` desde `Item Unit of Measure` en lugar de `Unit of Measure`
  (conversiones específicas por ítem — Phase 2).
- Warning visual al usuario cuando el valor se ha redondeado automáticamente.
- Bloqueo en el posting si la segunda cantidad almacenada no es entera para UoM discretas.
- Cambiar `DecimalPlaces` en la definición de los campos de tabla.

---

## Criterios de aceptación

- [ ] `ComputeSecondQtyRounded(10, 1.15, Fixed, 1)` devuelve `12`.
- [ ] `ComputeSecondQtyRounded(10, 1.15, Fixed, 0.001)` devuelve `11.5`.
- [ ] `ComputeSecondQtyRounded(10, 1.15, Fixed, 0)` devuelve `11.5` (fallback = comportamiento actual).
- [ ] `ComputeSecondQtyRounded(10, 1.15, AlwaysVariable, 1)` devuelve `0`.
- [ ] `ComputeSecondQty(10, 1.15, Fixed)` (firma original) sigue devolviendo `11.5` sin cambios.
- [ ] Al introducir manualmente `11.5` en `"DUoM Second Qty"` con una segunda UoM de `Rounding Precision = 1`, el campo queda a `12` tras el `Validate`.
- [ ] Los suscriptores de Purchase y Sales llaman a `ComputeSecondQtyRounded` con la precisión obtenida de `DUoM Item Setup`.
- [ ] Todos los tests existentes de la suite siguen en verde (regresión cero).
- [ ] El compilador AL no emite ningún warning (política zero-warnings).
- [ ] Todas las cadenas de usuario nuevas o modificadas están incluidas en ambos XLF (`en-US` y `es-ES`).

---

## Ficheros a crear / modificar

| Acción | Fichero |
|--------|---------|
| Modificar | `app/src/codeunit/DUoMCalcEngine.Codeunit.al` |
| Modificar | `app/src/codeunit/DUoMPurchaseSubscribers.Codeunit.al` |
| Modificar | `app/src/codeunit/DUoMSalesSubscribers.Codeunit.al` |
| Modificar (opcional) | Crear `app/src/codeunit/DUoMUoMHelper.Codeunit.al` (50106) si se extrae el helper |
| Modificar | `app/src/tableextension/DUoMPurchaseLine.TableExt.al` |
| Modificar | `app/src/tableextension/DUoMSalesLine.TableExt.al` |
| Modificar | `app/src/tableextension/DUoMItemJournalLine.TableExt.al` |
| Modificar | `test/src/codeunit/DUoMCalcEngineTests.Codeunit.al` (50204) |
| Modificar | `test/src/codeunit/DUoMPurchaseTests.Codeunit.al` (50205) |
| Modificar | `test/src/codeunit/DUoMSalesTests.Codeunit.al` (50206) |
| Modificar (si se crea codeunit 50106) | `app/src/permissionset/DUoMAll.PermissionSet.al` |
| Modificar | `app/Translations/DualUoM-BC.en-US.xlf` |
| Modificar | `app/Translations/DualUoM-BC.es-ES.xlf` |

---

## Referencias

- `app/src/codeunit/DUoMCalcEngine.Codeunit.al` — motor de cálculo actual (sin redondeo)
- `app/src/tableextension/DUoMPurchaseLine.TableExt.al` — ejemplo de `DecimalPlaces = 0:5` y `OnValidate`
- `app/src/table/DUoMItemSetup.Table.al` — campo `"Second UoM Code"` con `TableRelation = "Unit of Measure"`
- BC 27 tabla `Unit of Measure`, campo `"Rounding Precision"`
- `docs/02-functional-design.md` — modos de conversión (Fixed, Variable, AlwaysVariable)
- `docs/05-testing-strategy.md` — reglas TDD y convenciones de test
- `docs/06-backlog.md` — orden de entrega del backlog

## Etiquetas sugeridas

`enhancement` · `phase-1` · `data-quality` · `calc-engine`
