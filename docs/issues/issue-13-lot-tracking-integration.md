# Issue 13 — DualUoM: Ratio por Lote integrado con Item Tracking BC 27

## Contexto

**Issue:** #13 (rediseño Phase 2)
**Milestone:** Phase 2 — Funcionalidad extendida
**Etiquetas:** `enhancement`, `phase-2`, `lot-tracking`, `item-tracking`, `tdd`, `al`
**Fecha de creación:** 2026-04-22
**Dependencias previas:** Issues 1–12 completados ✅

---

## Problema

En sectores agroalimentarios y similares, el ratio de conversión (p. ej. KG/PCS) varía
por lote de recepción. Un lote de lechugas Romanas puede pesar 0,38 kg/unidad mientras
que otro del mismo artículo pesa 0,41 kg/unidad.

### Hallazgo arquitectónico crítico (2026-04-22)

> **`Lot No.` NO es un campo directo en `Purchase Line` (tabla 39) ni en `Sales Line`
> (tabla 37) en BC 27 / runtime 15.**

En Business Central 27, **una línea de documento puede contener N lotes**. Los lotes
se gestionan exclusivamente a través de la infraestructura estándar de trazabilidad:

- **`Reservation Entry` (tabla 337):** almacenamiento persistente de las asignaciones
  de lote por documento.
- **Página `Item Tracking Lines` (6510):** interfaz de usuario donde el usuario asigna
  N lotes a una línea de pedido, cada uno con su propia cantidad.
- **Flujo de contabilización:** para cada lote asignado en `Reservation Entry`, BC crea
  un `Item Ledger Entry` (ILE) independiente con la cantidad correspondiente al lote.
  En `OnAfterInitItemLedgEntry`, el `ItemJournalLine` tiene `Lot No.` y `Quantity`
  específicos del lote que se está procesando en ese momento.

El único caso donde `Lot No.` SÍ es campo directo es **`Item Journal Line` (tabla 83)**,
por lo que para el diario de productos la integración directa sigue siendo válida.

### Problema actual con multi-lote (bug existente)

El suscriptor actual `OnPurchPostCopyDocFieldsToItemJnlLine` en `DUoM Inventory
Subscribers` (50104) copia `DUoM Second Qty` directamente desde la `Purchase Line`
(valor total de la línea) al `Item Journal Line` de cada lote. Con múltiples lotes,
cada ILE recibe la segunda cantidad **total** de la línea en lugar de la parte
proporcional al lote. Este issue corrige ese comportamiento.

---

## Diseño de la solución

### Principio rector

> **Usar siempre las librerías, codeunits y métodos estándar de BC para la gestión de
> lotes y reservas. No manipular `Reservation Entry` ni el flujo de Item Tracking
> "from scratch".**

La integración DUoM con lotes se hace **subscripting a eventos estándar**, no
accediendo directamente a tablas de reserva ni reimplementando el flujo de posting.

### Flujo de integración

```
Caso A — Item Journal Line (Lot No. campo directo):
  Usuario asigna Lot No. en IJL
  → OnAfterValidateEvent[Lot No.] en Table "Item Journal Line"
  → DUoM Lot Subscribers (50108): busca DUoM Lot Ratio(Item No., Lot No.)
  → Si existe y modo ≠ Fixed: sobreescribe DUoM Ratio + recalcula DUoM Second Qty

Caso B — Purchase/Sales Line (N lotes vía Item Tracking):
  Usuario asigna N lotes en "Item Tracking Lines" (estándar BC)
  → Lots persisten en Reservation Entry (flujo estándar, sin intervención DUoM)
  → Al contabilizar: BC crea un ILE por lote, cada uno con Lot No. propio
  → OnAfterInitItemLedgEntry(NewILE, ItemJnlLine, ...)
    - ItemJnlLine."Lot No." tiene el lote del ILE que se está creando
    - DUoM Inventory Subscribers (50104): copia DUoM Ratio de IJL a ILE
    - NUEVO: recalcula DUoM Second Qty = Abs(ILE.Quantity) × DUoM Ratio
    - NUEVO: llama a DUoM Lot Subscribers.TryApplyLotRatioToILE(NewILE, IJL)
    - TryApplyLotRatioToILE: si lote tiene ratio y modo ≠ Fixed →
        ILE.DUoM Ratio = LotActualRatio
        ILE.DUoM Second Qty = Abs(ILE.Quantity) × LotActualRatio
```

### Diagrama de jerarquía de resolución (completa con lote)

```
1. DUoM Item Setup (50100)          → master switch (Dual UoM Enabled)
2. DUoM Item Variant Setup (50101)  → override por variante (opcional)
3. DUoM Lot Ratio (50102)           → ratio real por lote (solo Variable/AlwaysVariable)
                                        Se aplica en ILE, no en la línea de documento
```

---

## Alcance

### Dentro del alcance

1. **`DUoM Lot Subscribers` (codeunit 50108):**
   - Suscriptor a `OnAfterValidateEvent` de `Lot No.` en `Item Journal Line` →
     pre-rellenado de `DUoM Ratio` y `DUoM Second Qty` en el diario.
   - Procedimiento público `TryApplyLotRatioToILE` que encapsula la lógica de
     override de ratio de lote en la ILE durante el posting.

2. **Modificar `DUoM Inventory Subscribers` (50104) — `OnAfterInitItemLedgEntry`:**
   - Cambiar el comportamiento actual (copia directa de `DUoM Second Qty` desde IJL)
     por recálculo proporcional: `Abs(ILE.Quantity) × DUoM Ratio` cuando el ratio ≠ 0.
   - Llamar a `DUoM Lot Subscribers.TryApplyLotRatioToILE` para aplicar el ratio
     específico del lote cuando esté disponible.
   - Mantener el comportamiento actual (copia directa) solo para modo AlwaysVariable
     sin ratio de lote registrado (`DUoM Ratio = 0`).

3. **Tabla `DUoM Lot Ratio` (50102):** ya existe. Sin cambios de estructura.

4. **Página `DUoM Lot Ratio List` (50102):** ya existe. Sin cambios.

5. **Acción `DUoM Lot Ratios` en `DUoM Item Setup` (page 50100):** ya existe.

6. **Tests TDD (codeunit 50217):** mínimo 7 tests — ver sección de tests.

7. **Permission sets:** `DUoM Lot Ratio = RIMD` ya incluido en ambos permission sets.

### Fuera del alcance

| Exclusión | Issue futuro |
|-----------|-------------|
| Pre-rellenado en la **página** `Item Tracking Lines` (mostrar ratio sugerido) | Futuro (UI enhancement) |
| Propagación de ratio de lote a líneas de documentos registrados (Purch. Rcpt. Line, etc.) | Los valores del ILE son la fuente de verdad; las líneas históricas ya propagan DUoM Ratio desde la línea de pedido |
| Soporte de lote en Warehouse Receipt/Shipment | Issue 14 |
| Soporte de lote en actividades dirigidas (Directed Put-Away/Pick) | Issue 15 |
| Soporte de lote en devoluciones | Issue 16 |
| Ratio de lote para modo `AlwaysVariable` con múltiples lotes sin ratios registrados | Limitación conocida documentada |

---

## Requisitos funcionales

### RF-01 — Pre-rellenado en Item Journal Line

Cuando el usuario valida `Lot No.` en un `Item Journal Line` para un artículo con DUoM
activado y modo ≠ Fixed:

1. El sistema busca un registro en `DUoM Lot Ratio` para `(Item No., Lot No.)`.
2. Si existe, sobreescribe `DUoM Ratio` con `Actual Ratio` del lote.
3. Recalcula `DUoM Second Qty` con `DUoM Calc Engine.ComputeSecondQtyRounded`.
4. Si no existe registro, `DUoM Ratio` permanece sin cambios.
5. Modo Fixed: el ratio de lote NUNCA sobreescribe el ratio fijo.

### RF-02 — Override de ratio de lote en ILE durante posting

Cuando BC crea un ILE durante la contabilización de un documento con trazabilidad de
lote (N lotes por línea):

1. Para cada ILE, `ItemJournalLine."Lot No."` contiene el lote específico.
2. El sistema busca `DUoM Lot Ratio` para `(Item No., Lot No.)`.
3. Si existe y modo ≠ Fixed:
   - `ILE."DUoM Ratio"` = `Actual Ratio` del lote.
   - `ILE."DUoM Second Qty"` = `Abs(ILE.Quantity) × ILE."DUoM Ratio"`.
4. Si no existe ratio de lote:
   - Si `DUoM Ratio ≠ 0` (Fixed o Variable con ratio): recalcula proportionalmente
     `Abs(ILE.Quantity) × DUoM Ratio`.
   - Si `DUoM Ratio = 0` (AlwaysVariable sin ratio de lote): copia `DUoM Second Qty`
     directamente desde `ItemJournalLine` (comportamiento actual preservado).

### RF-03 — Modo Fixed: ratio de lote nunca sobreescribe

Cuando el modo de conversión efectivo es Fixed, el ratio de lote **no** modifica
`DUoM Ratio` ni en el diario ni en el ILE. El ratio fijo siempre prevalece.

### RF-04 — Modo AlwaysVariable: ratio de lote pre-rellena como sugerencia

En modo AlwaysVariable, si existe ratio para el lote, se pre-rellena `DUoM Ratio` como
sugerencia editable (tanto en IJL como en ILE). El usuario puede sobreescribirlo en IJL.

---

## Requisitos técnicos

### RT-01 — Nuevo codeunit `DUoM Lot Subscribers` (50108)

```al
codeunit 50108 "DUoM Lot Subscribers"
{
    Access = Internal;

    // Suscriptor: Item Journal Line — Lot No. validate
    // Publisher: Table "Item Journal Line", campo Lot No.
    // Evento elegido: OnAfterValidateEvent, porque Lot No. ES campo directo en IJL (tabla 83).
    // Firma verificada: BC 27 / runtime 15 — Item Journal Line tiene Lot No. (field 5407).
    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line",
                     'OnAfterValidateEvent', 'Lot No.', false, false)]
    local procedure OnAfterValidateItemJnlLineLotNo(
        var Rec: Record "Item Journal Line";
        var xRec: Record "Item Journal Line")
    begin
        // Delegar a método centralizado
        ApplyLotRatioIfExists(Rec."Item No.", Rec."Lot No.", Rec."Variant Code",
                              Rec.Quantity, Rec."DUoM Ratio", Rec."DUoM Second Qty");
    end;

    // Procedimiento público: llamado desde DUoMInventorySubscribers (50104)
    // en OnAfterInitItemLedgEntry para aplicar el ratio de lote al ILE.
    procedure TryApplyLotRatioToILE(
        var ItemLedgEntry: Record "Item Ledger Entry";
        ItemJournalLine: Record "Item Journal Line")
    var
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
    begin
        if ItemJournalLine."Lot No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(
                 ItemJournalLine."Item No.", ItemJournalLine."Variant Code",
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;
        ApplyLotRatioToRecord(ItemJournalLine."Item No.", ItemJournalLine."Lot No.",
                              ConversionMode, ItemLedgEntry.Quantity,
                              ItemLedgEntry."DUoM Ratio", ItemLedgEntry."DUoM Second Qty");
    end;

    local procedure ApplyLotRatioIfExists(
        ItemNo: Code[20]; LotNo: Code[50]; VariantCode: Code[10];
        Quantity: Decimal; var DUoMRatio: Decimal; var DUoMSecondQty: Decimal)
    begin
        // Resolver modo efectivo + delegar
        ...
    end;

    local procedure ApplyLotRatioToRecord(
        ItemNo: Code[20]; LotNo: Code[50];
        ConversionMode: Enum "DUoM Conversion Mode";
        Quantity: Decimal; var DUoMRatio: Decimal; var DUoMSecondQty: Decimal)
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
    begin
        if ConversionMode = ConversionMode::Fixed then
            exit; // Fixed: el ratio fijo siempre prevalece
        if not DUoMLotRatio.Get(ItemNo, LotNo) then
            exit; // Sin ratio para este lote: sin cambios
        DUoMRatio := DUoMLotRatio."Actual Ratio";
        // Recalcular usando la cantidad absoluta del registro destino
        DUoMSecondQty := Abs(Quantity) * DUoMLotRatio."Actual Ratio";
    end;
}
```

> **Nota sobre `Access = Internal`:** `TryApplyLotRatioToILE` es público solo para que
> `DUoMInventorySubscribers` (50104) pueda llamarlo desde dentro del mismo app.
> Ambos codeunits pertenecen al mismo PTE, por lo que `Access = Internal` es suficiente.

### RT-02 — Modificar `DUoM Inventory Subscribers` (50104) — `OnAfterInitItemLedgEntry`

El suscriptor actual copia directamente `DUoM Second Qty` desde IJL al ILE:

```al
// COMPORTAMIENTO ACTUAL (incorrecto para multi-lote):
NewItemLedgEntry."DUoM Second Qty" := ItemJournalLine."DUoM Second Qty";
NewItemLedgEntry."DUoM Ratio" := ItemJournalLine."DUoM Ratio";
```

**Nuevo comportamiento:**

```al
// 1. Copiar DUoM Ratio desde IJL
NewItemLedgEntry."DUoM Ratio" := ItemJournalLine."DUoM Ratio";

// 2. Calcular DUoM Second Qty proporcional a la cantidad del ILE (correcto multi-lote)
if ItemJournalLine."DUoM Ratio" <> 0 then
    NewItemLedgEntry."DUoM Second Qty" := Abs(NewItemLedgEntry.Quantity) * ItemJournalLine."DUoM Ratio"
else
    // AlwaysVariable sin ratio: copia directa (comportamiento previo preservado)
    NewItemLedgEntry."DUoM Second Qty" := ItemJournalLine."DUoM Second Qty";

// 3. Override con ratio de lote si corresponde
DUoMLotSubscribers.TryApplyLotRatioToILE(NewItemLedgEntry, ItemJournalLine);
```

> **Compatibilidad:** Para lotes únicos (sin Item Tracking multi-lote), el nuevo cálculo
> `Abs(ILE.Quantity) × DUoM Ratio` produce el mismo resultado que la copia directa,
> por lo que los tests existentes (50209, 50210, 50214, 50216) no deben verse afectados.

### RT-03 — Uso de `Library - Item Tracking` en tests

Para asignar N lotes a una línea de pedido en los tests TDD de Purchase/Sales:

```al
LibraryItemTracking: Codeunit "Library - Item Tracking";

// Asignar Lot A (6 unidades) a una Purchase Line
LibraryItemTracking.CreateItemTrackingLines(
    PurchaseLine, LotNoA, 6);

// Asignar Lot B (4 unidades) a la misma Purchase Line
LibraryItemTracking.CreateItemTrackingLines(
    PurchaseLine, LotNoB, 4);
```

> **VERIFICACIÓN OBLIGATORIA antes de implementar:** confirmar la firma exacta del método
> `CreateItemTrackingLines` (u equivalente) en `Library - Item Tracking` de
> `Tests-TestLibraries` (ID `5d86850b-0d76-4eca-bd7b-951ad998e997`) en BC 27.
> Si el método tiene firma diferente, documentar la alternativa en comentario en el test.
>
> Si `Library - Item Tracking` no expone un método directo para asignar lotes a líneas
> de pedido, la alternativa estándar es crear `Reservation Entry` directamente usando
> `Codeunit "Item Tracking Management"` (6500) o
> `Codeunit "Create Reserv. Entry"` (99000830). Nunca crear Reservation Entry
> manualmente desde cero.

### RT-04 — Artículo de test con item tracking habilitado

Para que BC acepte la asignación de lotes, el artículo debe tener un `Item Tracking
Code` configurado. En los tests usar `Library - Inventory` o el helper estándar:

```al
LibraryInventory.CreateItemTrackingCode(ItemTrackingCode);
ItemTrackingCode.Validate("Lot Specific Tracking", true);
ItemTrackingCode.Validate("Lot Purchase Inbound Tracking", true);
ItemTrackingCode.Validate("Lot Sales Outbound Tracking", true);
ItemTrackingCode.Modify(true);
Item.Validate("Item Tracking Code", ItemTrackingCode.Code);
Item.Modify(true);
```

### RT-05 — Longitud de nombres de objetos (AL0305 ≤ 30 chars)

| Nombre del objeto | Longitud | Estado |
|---|---|---|
| `"DUoM Lot Ratio"` | 14 | ✅ |
| `"DUoM Lot Ratio List"` | 19 | ✅ |
| `"DUoM Lot Subscribers"` | 20 | ✅ |
| `"DUoM Lot Ratio Tests"` | 20 | ✅ |

### RT-06 — Permission sets

`DUoM Lot Ratio = RIMD` ya está en ambos permission sets:
- `app/src/permissionset/DUoMAll.PermissionSet.al` (50100) ✅
- `test/src/permissionset/DUoMTestAll.PermissionSet.al` (50200) ✅

No se requieren cambios en permission sets.

### RT-07 — Localización (obligatorio)

Los textos del codeunit 50108 ya existen en la tabla y página (50102). Si se añaden
nuevos `Label` en el codeunit, ambos XLF deben actualizarse en el mismo PR:
- `app/Translations/DualUoM-BC.en-US.xlf`
- `app/Translations/DualUoM-BC.es-ES.xlf`

### RT-08 — TDD estricto

Escribir el codeunit de test 50217 con todos los tests en estado **fallando** antes de
implementar el código de producción. Seguir el patrón `// [GIVEN] / [WHEN] / [THEN]`.

### RT-09 — Firma del evento `OnAfterValidateEvent` de `Lot No.` en `Item Journal Line`

```al
// Firma verificada BC 27 / runtime 15:
// Item Journal Line (tabla 83) expone el evento de tabla estándar para cualquier campo.
// Lot No. (field 5407) es campo directo en tabla 83 — distinto de Purchase/Sales Line.
[EventSubscriber(ObjectType::Table, Database::"Item Journal Line",
                 'OnAfterValidateEvent', 'Lot No.', false, false)]
local procedure OnAfterValidateItemJnlLineLotNo(
    var Rec: Record "Item Journal Line";
    var xRec: Record "Item Journal Line")
```

### RT-10 — Documentación (obligatorio)

Actualizar en el mismo PR:
- `docs/02-functional-design.md` — sección "Lot-Specific Real Ratio": sustituir el
  texto "Phase 2 — Pendiente" por el diseño implementado con Item Tracking.
- `docs/03-technical-architecture.md` — codeunit 50108 en Object Structure; nota sobre
  recálculo proporcional en `OnAfterInitItemLedgEntry`.
- `docs/04-item-setup-model.md` — jerarquía de resolución con nivel Lote actualizada.
- `docs/06-backlog.md` — Issue 13 marcado ✅ IMPLEMENTADO.
- `docs/TestCoverageAudit.md` — codeunit 50108 y tests 50217 en inventario y matriz.
- `.github/copilot-instructions.md` — si se añaden nuevas reglas de suscriptor (Lot No.
  en IJL confirmado como campo directo).

---

## Tests TDD (codeunit 50217 `"DUoM Lot Ratio Tests"`)

| ID | Escenario | Resultado esperado |
|----|-----------|--------------------|
| **T01** | IJL, `Lot No.` con ratio 0,38, modo Variable | `DUoM Ratio = 0,38`; `DUoM Second Qty = Qty × 0,38` |
| **T02** | IJL, `Lot No.` **sin** ratio registrado, modo Variable | `DUoM Ratio` sin cambios (valor previo conservado) |
| **T03** | IJL, `Lot No.` con ratio, modo **Fixed** | `DUoM Ratio` NO sobreescrito (ratio fijo prevalece) |
| **T04** | Contabilizar Purchase Order, un lote con ratio 0,38, modo Variable → ILE | `ILE."DUoM Ratio" = 0,38`; `ILE."DUoM Second Qty" = ILE.Quantity × 0,38` |
| **T05** | Contabilizar Purchase Order, **dos lotes** (A=6uds ratio 0,38; B=4uds ratio 0,41), modo Variable → 2 ILEs | ILE-A: `DUoM Ratio=0,38`, `DUoM Second Qty=6×0,38=2,28`; ILE-B: `DUoM Ratio=0,41`, `DUoM Second Qty=4×0,41=1,64` |
| **T06** | Contabilizar Sales Order, lote con ratio 0,42, modo Variable → ILE | `ILE."DUoM Ratio" = 0,42`; `ILE."DUoM Second Qty" = Abs(ILE.Quantity) × 0,42` |
| **T07** | `DUoM Lot Ratio`, `Actual Ratio = 0` o `Actual Ratio = -1` | Error de validación con mensaje localizado |

> **T05 es el test más crítico:** verifica el escenario multi-lote que era imposible
> con el diseño anterior (suscriptor en Purchase Line). Requiere `Library - Item Tracking`
> para asignar los dos lotes al pedido de compra antes de contabilizar.

### Ejemplo de estructura para T05

```al
[Test]
procedure PurchasePosting_TwoLots_EachILEHasLotSpecificDUoMRatio()
var
    Item: Record Item;
    ItemTrackingCode: Record "Item Tracking Code";
    Vendor: Record Vendor;
    PurchHeader: Record "Purchase Header";
    PurchLine: Record "Purchase Line";
    ILE: Record "Item Ledger Entry";
    DUoMTestHelpers: Codeunit "DUoM Test Helpers";
    LibraryInventory: Codeunit "Library - Inventory";
    LibraryPurchase: Codeunit "Library - Purchase";
    LibraryItemTracking: Codeunit "Library - Item Tracking";
    LibraryAssert: Codeunit "Library Assert";
    LotNoA: Code[50];
    LotNoB: Code[50];
begin
    // [GIVEN] Artículo con DUoM Variable y Item Tracking por lote
    LibraryInventory.CreateItem(Item);
    LibraryInventory.CreateItemTrackingCode(ItemTrackingCode);
    // configurar Lot-Specific Tracking = true
    Item.Validate("Item Tracking Code", ItemTrackingCode.Code);
    Item.Modify(true);
    DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
        "DUoM Conversion Mode"::Variable, 0.40); // ratio por defecto

    LotNoA := 'LOTE-A';
    LotNoB := 'LOTE-B';
    DUoMTestHelpers.CreateLotRatio(Item."No.", LotNoA, 0.38);
    DUoMTestHelpers.CreateLotRatio(Item."No.", LotNoB, 0.41);

    // [GIVEN] Purchase Order con 10 uds, 2 lotes asignados vía Library - Item Tracking
    LibraryPurchase.CreateVendor(Vendor);
    LibraryPurchase.CreatePurchHeader(PurchHeader,
        PurchHeader."Document Type"::Order, Vendor."No.");
    LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader,
        PurchLine.Type::Item, Item."No.", 10);
    // Asignar lotes usando la librería estándar BC
    LibraryItemTracking.CreateItemTrackingLines(PurchLine, LotNoA, 6);
    LibraryItemTracking.CreateItemTrackingLines(PurchLine, LotNoB, 4);

    // [WHEN] Se contabiliza el pedido (solo recepción)
    LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

    // [THEN] ILE Lote A: DUoM Ratio = 0,38; DUoM Second Qty = 6 × 0,38 = 2,28
    ILE.SetRange("Item No.", Item."No.");
    ILE.SetRange("Lot No.", LotNoA);
    LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba ILE para Lote A');
    LibraryAssert.AreEqual(0.38, ILE."DUoM Ratio", 'ILE Lote A: DUoM Ratio debe ser 0,38');
    LibraryAssert.AreNearlyEqual(2.28, ILE."DUoM Second Qty", 0.001,
        'ILE Lote A: DUoM Second Qty debe ser 6 × 0,38 = 2,28');

    // [THEN] ILE Lote B: DUoM Ratio = 0,41; DUoM Second Qty = 4 × 0,41 = 1,64
    ILE.SetRange("Lot No.", LotNoB);
    LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba ILE para Lote B');
    LibraryAssert.AreEqual(0.41, ILE."DUoM Ratio", 'ILE Lote B: DUoM Ratio debe ser 0,41');
    LibraryAssert.AreNearlyEqual(1.64, ILE."DUoM Second Qty", 0.001,
        'ILE Lote B: DUoM Second Qty debe ser 4 × 0,41 = 1,64');
end;
```

---

## Checklist de validación (Definition of Done)

### Código y tests

- [ ] **T01** — IJL, Variable, lote CON ratio → DUoM Ratio y Second Qty pre-rellenados
- [ ] **T02** — IJL, Variable, lote SIN ratio → DUoM Ratio sin cambios
- [ ] **T03** — IJL, Fixed, lote CON ratio → DUoM Ratio NO sobreescrito
- [ ] **T04** — Purchase posting, lote único con ratio → ILE con ratio de lote
- [ ] **T05** — Purchase posting, 2 lotes con ratios distintos → 2 ILEs correctos ✓ Test crítico
- [ ] **T06** — Sales posting, lote con ratio → ILE con ratio de lote
- [ ] **T07** — `Actual Ratio ≤ 0` → error de validación
- [ ] Tests existentes (50209, 50210, 50214, 50216) siguen pasando sin modificaciones

### Calidad

- [ ] Cero warnings de `PerTenantExtensionCop`, `CodeCop` y `UICop`
- [ ] Sin `with` implícito (`NoImplicitWith`)
- [ ] Sin uso de `Permissions` en codeunits (AL0246)
- [ ] Todos los `Label` tienen propiedad `Comment`
- [ ] Nombres de objetos ≤ 30 caracteres

### Estándar de librerías

- [ ] `Library - Item Tracking` usado en T04, T05 y T06 para asignar lotes
  (NO crear `Reservation Entry` manualmente desde cero)
- [ ] Firma de `Library - Item Tracking` verificada contra BC 27 y documentada en comentario

### Localización

- [ ] `DualUoM-BC.en-US.xlf` actualizado si hay nuevos `Label`
- [ ] `DualUoM-BC.es-ES.xlf` actualizado si hay nuevos `Label`
- [ ] Si no hay nuevos labels: declarar explícitamente "Not applicable" en el PR

### Documentación

- [ ] `docs/02-functional-design.md` — sección Lot-Specific Real Ratio actualizada
- [ ] `docs/03-technical-architecture.md` — codeunit 50108 documentado
- [ ] `docs/04-item-setup-model.md` — jerarquía de resolución con nivel Lote
- [ ] `docs/06-backlog.md` — Issue 13 marcado ✅ IMPLEMENTADO
- [ ] `docs/TestCoverageAudit.md` — codeunit 50108 y 50217 añadidos

---

## Riesgos y limitaciones conocidas

| Riesgo / Limitación | Impacto | Mitigación |
|---------------------|---------|------------|
| Firma exacta de `Library - Item Tracking` en BC 27 pendiente de verificación | Alto si la firma es incorrecta | Verificar en Symbol Reference o Tests-TestLibraries antes de codificar. Documentar con comentario en el test. |
| Modo AlwaysVariable con múltiples lotes **sin** ratios registrados: la segunda cantidad no se distribuye proporcionalmente entre ILEs (se copia el valor total desde IJL) | Bajo — caso de uso poco frecuente | Limitación conocida y documentada. La corrección completa requiere que el usuario registre ratios para cada lote. |
| `OnAfterInitItemLedgEntry`: cambio de copia directa a recálculo proporcional puede afectar escenarios no cubiertos por tests actuales | Medio | Ejecutar todos los tests existentes (50209–50216) tras el cambio y analizar cualquier regresión. |
| `Library - Item Tracking` puede no existir o tener un nombre diferente en `Tests-TestLibraries` BC 27 | Medio | Si no existe, usar `Codeunit "Item Tracking Management"` (6500) + inserción directa en `Reservation Entry` con DataClassification correcta. Documentar la decisión. |

---

## IDs de objetos confirmados

| Objeto | ID | Estado |
|--------|----|--------|
| `DUoM Lot Ratio` (table) | 50102 | ✅ Existe |
| `DUoM Lot Ratio List` (page) | 50102 | ✅ Existe |
| `DUoM Lot Subscribers` (codeunit) | **50108** | ❌ Pendiente de crear |
| `DUoM Lot Ratio Tests` (test codeunit) | **50217** | ❌ Pendiente de crear |

---

## Referencias

- Backlog: `docs/06-backlog.md` — sección "Issue 13 — Ratio real por lote con Item Tracking"
- Diseño funcional: `docs/02-functional-design.md` — "Lot-Specific Real Ratio"
- Arquitectura técnica: `docs/03-technical-architecture.md`
- Modelo de datos: `docs/04-item-setup-model.md`
- Cobertura de tests: `docs/TestCoverageAudit.md`
- Hallazgo previo: `docs/issues/issue-13-lot-ratio.md` — diseño especulativo removido
- Instrucciones agente: `.github/copilot-instructions.md`
