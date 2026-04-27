# Backlog — DualUoM-BC

Backlog ordenado para la entrega incremental y controlada del proyecto.
Cada issue está delimitado para poder ser implementado en un único issue enfocado por
GitHub Copilot Coding Agent.

> **Estado actualizado:** 2026-04-20 — sincronizado con el estado real de los objetos
> implementados en el repositorio.

---

## Phase 1 — MVP ✅ COMPLETADA

### Issue 1 — Project Governance Baseline ✅ IMPLEMENTADO

Creación de la base documental del proyecto: visión, alcance, diseño funcional,
arquitectura, estrategia de testing y backlog. Actualización del README y las
copilot-instructions.

### Issue 2 — DUoM Calculation Engine ✅ IMPLEMENTADO

Codeunit `DUoM Calc Engine` (ID 50101):
- `ComputeSecondQty(FirstQty, Ratio, Mode)` con validación de entrada
- Tests unitarios para modos Fixed, Variable, AlwaysVariable y casos límite

**Deliverables:** `DUoMCalcEngine.Codeunit.al` (50101), `DUoMCalcEngineTests.Codeunit.al` (50204)
Codeunit temporal `DualUoM Pipeline Check` (50100) y su test (50200) eliminados.

### Issue 3 — Item DUoM Setup Table and Page ✅ IMPLEMENTADO

Tabla `DUoM Item Setup` (ID 50100) vinculada a `Item` con campos:
`Item No.`, `Dual UoM Enabled`, `Second UoM Code`, `Conversion Mode` (enum 50100),
`Fixed Ratio`.
Diseño adoptado: **tabla/página de setup separada** (Opción B). La tabla `Item` base
no se extiende con campos de configuración DUoM; en su lugar, `Item.TableExt.al`
(tableextension 50100) únicamente añade un trigger `OnDelete` para borrar en cascada
el registro `DUoM Item Setup` huérfano. Esta decisión se mantiene como referencia para
issues futuros (almacén, lotes).

**Deliverables:**
- `DUoMConversionMode.Enum.al` (enum 50100)
- `DUoMItemSetup.Table.al` (table 50100) con `GetOrCreate()` y `ValidateSetup()`
- `DUoMItemSetup.Page.al` (page 50100) — tarjeta de configuración por artículo
- `DUoMItemCardExt.PageExt.al` (pageextension 50100) — acción en Item Card
- `Item.TableExt.al` (tableextension 50100) — cascade delete
- Tests: `DUoMItemSetupTests.Codeunit.al` (50201), `DUoMItemCardOpeningTests.Codeunit.al` (50202),
  `DUoMItemDeleteTests.Codeunit.al` (50203)

### Issue 4 — Purchase Line DUoM Fields ✅ IMPLEMENTADO

Extensión de `Purchase Line` con campos `DUoM Second Qty` y `DUoM Ratio`.
Extensión del subformulario de pedido de compra para mostrar los campos.
Suscriptor `OnAfterValidateEvent` en `Quantity` de `Purchase Line` llama al Calc Engine.

**Deliverables:** `DUoMPurchaseLine.TableExt.al` (50110), `DUoMPurchaseOrderSubform.PageExt.al` (50101),
`DUoMPurchaseSubscribers.Codeunit.al` (50102), `DUoMPurchaseTests.Codeunit.al` (50205)

### Issue 5 — Purchase Posting — ILE Second Qty ✅ IMPLEMENTADO

Propagación de campos DUoM desde `Purchase Line` hasta `Item Ledger Entry`.
Estrategia de propagación real (BC 27 / runtime 15):

1. `OnPostItemJnlLineOnAfterCopyDocumentFields` (Codeunit `Purch.-Post`) copia los
   campos DUoM de `Purchase Line` al `Item Journal Line` antes de contabilizar.
2. `OnAfterInitItemLedgEntry` (Codeunit `Item Jnl.-Post Line`) copia los campos DUoM
   del `Item Journal Line` al nuevo ILE antes del `Insert()` — sin necesidad de `Modify()`.

**Nota:** NO se usa `OnAfterInsertItemLedgEntry` ni se traza desde ILE hacia atrás.
La propagación es hacia adelante, antes del Insert, lo que evita problemas de permisos
Modify sobre tablas base en SaaS.

**Deliverables:** `DUoMItemLedgerEntry.TableExt.al` (50113), incluido en
`DUoMInventorySubscribers.Codeunit.al` (50104)

### Issue 6 — Sales Line DUoM Fields ✅ IMPLEMENTADO

Extensión de `Sales Line` con campos `DUoM Second Qty` y `DUoM Ratio`.
Extensión del subformulario de pedido de venta para mostrar los campos.
Suscriptor `OnAfterValidateEvent` en `Quantity` de `Sales Line` llama al Calc Engine.

**Deliverables:** `DUoMSalesLine.TableExt.al` (50111), `DUoMSalesOrderSubform.PageExt.al` (50102),
`DUoMSalesSubscribers.Codeunit.al` (50103), `DUoMSalesTests.Codeunit.al` (50206)

### Issue 7 — Sales Posting — ILE Second Qty ✅ IMPLEMENTADO

Propagación de campos DUoM desde `Sales Line` hasta `Item Ledger Entry`.
Misma estrategia que Issue 5 (propagación hacia adelante):

1. `OnPostItemJnlLineOnAfterCopyDocumentFields` (Codeunit `Sales-Post`) copia DUoM
   de `Sales Line` al `Item Journal Line`.
2. `OnAfterInitItemLedgEntry` (Codeunit `Item Jnl.-Post Line`) copia al ILE.

**Deliverables:** incluido en `DUoMInventorySubscribers.Codeunit.al` (50104)

### Issue 8 — Item Journal DUoM Fields and Posting ✅ IMPLEMENTADO

Extensión de `Item Journal Line` con campos DUoM.
Suscriptor `OnAfterValidateEvent` en `Quantity` del diario para auto-calcular.
Extensión del subformulario del diario de productos para mostrar los campos.
`OnAfterInitItemLedgEntry` cubre también las contabilizaciones manuales por diario.

**Deliverables:** `DUoMItemJournalLine.TableExt.al` (50112),
`DUoMItemJournalExt.PageExt.al` (pageextension 50103), `DUoMInventoryTests.Codeunit.al` (50207)

### Issue 9 — Campos DUoM en líneas de documentos registrados + tests E2E Phase 1 ✅ IMPLEMENTADO

Campos `DUoM Second Qty` y `DUoM Ratio` en `Purch. Rcpt. Line` y `Sales Shipment Line`
mediante table extensions. Propagación desde las líneas de pedido origen mediante
**eventos de inicialización de tabla** (BC 27 / runtime 15) — NO eventos de codeunit:

- `OnAfterInitFromPurchLine` en **Table `"Purch. Rcpt. Line"`**: copia DUoM de
  `Purchase Line` a `Purch. Rcpt. Line` durante la inicialización del registro de destino.
- `OnAfterInitFromSalesLine` en **Table `"Sales Shipment Line"`**: copia DUoM de
  `Sales Line` a `Sales Shipment Line` durante la inicialización.

La lógica de copia está centralizada en `DUoM Doc Transfer Helper` (50105) — thin subscriber pattern.
Subformularios de documentos registrados muestran los campos (solo lectura).
Tests E2E cubren el ciclo completo: creación de pedido → contabilización → verificación en
líneas registradas e ILE.

**Nota de diseño:** Los eventos `OnBeforePurchRcptLineInsert` y `OnBeforeInsertShipmentLine`
**no existen** en BC 27 y causarían AL0280/AL0282. Usar siempre los eventos de tabla listados.

**Deliverables:**
- `DUoMPurchRcptLine.TableExt.al` (50114), `DUoMSalesShipmentLine.TableExt.al` (50115)
- `DUoMDocTransferHelper.Codeunit.al` (50105) — helper de copia de campos DUoM entre líneas
- Subscribers en `DUoMInventorySubscribers.Codeunit.al` (50104):
  `OnAfterInitFromPurchLine` (Table `"Purch. Rcpt. Line"`),
  `OnAfterInitFromSalesLine` (Table `"Sales Shipment Line"`)
- `DUoMPostedPurchRcptSubform.PageExt.al` (50104) extiende `Posted Purchase Rcpt. Subform`
- `DUoMPostedSalesShipSubform.PageExt.al` (50105) extiende `Posted Sales Shpt. Subform`
- `DUoMILEIntegrationTests.Codeunit.al` (50209) — tests E2E de contabilización completa

### Issue 10 — Propagar DUoM a históricos de facturas y abonos ✅ IMPLEMENTADO

Campos `DUoM Second Qty` y `DUoM Ratio` en las cuatro líneas de documentos históricos
registrados de factura y abono de compra y venta, mediante table extensions.
Propagación desde las líneas de pedido origen usando **eventos de inicialización de tabla**
(BC 27 / runtime 15):

- `OnAfterInitFromPurchLine` en **Table `"Purch. Inv. Line"`**: copia DUoM de `Purchase Line`
  a la factura de compra registrada durante la inicialización.
- `OnAfterInitFromPurchLine` en **Table `"Purch. Cr. Memo Line"`**: ídem para abono de compra.
- `OnAfterInitFromSalesLine` en **Table `"Sales Invoice Line"`**: copia DUoM de `Sales Line`
  a la factura de venta registrada.
- `OnAfterInitFromSalesLine` en **Table `"Sales Cr.Memo Line"`**: ídem para abono de venta.

> **IMPORTANTE — firma BC 27:** En los eventos de Sales (`Sales Invoice Line` y
> `Sales Cr.Memo Line`), el parámetro `var` de destino es el **PRIMER** parámetro de la
> firma, a diferencia de los eventos de Purchase donde es el **ÚLTIMO**. Verificar siempre
> la firma exacta en el código fuente BC 27 antes de añadir un suscriptor.

La lógica de copia está centralizada en `DUoM Doc Transfer Helper` (50105) — thin subscriber pattern.
Subformularios de históricos muestran los campos (solo lectura).

**Deliverables:**
- `DUoMPurchInvLine.TableExt.al` (50116), `DUoMPurchCrMemoLine.TableExt.al` (50117)
- `DUoMSalesInvLine.TableExt.al` (50118), `DUoMSalesCrMemoLine.TableExt.al` (50119)
- Nuevos métodos en `DUoMDocTransferHelper.Codeunit.al` (50105): `CopyFromPurchLineToPurchInvLine`,
  `CopyFromPurchLineToPurchCrMemoLine`, `CopyFromSalesLineToSalesInvLine`, `CopyFromSalesLineToSalesCrMemoLine`
- Nuevos suscriptores en `DUoMInventorySubscribers.Codeunit.al` (50104)
- `DUoMPostedPurchInvSubform.PageExt.al` (50106), `DUoMPostedPurchCrMemoSubform.PageExt.al` (50107)
- `DUoMPostedSalesInvSubform.PageExt.al` (50108), `DUoMPostedSalesCrMemoSubform.PageExt.al` (50109)
- `DUoMInvCrMemoPostTests.Codeunit.al` (50210) — 5 tests E2E de facturación y abono

---

### Auditoría TDD — Revisión de cobertura de pruebas ✅ IMPLEMENTADO

**Objetivo:** revisar la cobertura de pruebas del proyecto DualUoM-BC, identificar los gaps
existentes y crear los codeunits de test necesarios para cerrar dichos gaps.

Resultado:
- Nuevo documento `docs/TestCoverageAudit.md` con la matriz de cobertura completa y el
  análisis de gaps clasificados por prioridad (P0/P1/P2).
- Gap P0-01 cerrado: `DUoM UoM Helper` (50106) cambiado de `Access = Internal` a
  `Access = Public` para permitir tests unitarios directos desde el test app.
  Nuevo codeunit `DUoM UoM Helper Tests` (50213) — 7 tests unitarios para ambos métodos
  del helper (`GetSecondUoMRoundingPrecision`, `GetRoundingPrecisionByUoMCode`).
- Gap P0-02 cerrado: nuevo codeunit `DUoM Variable Mode Post Tests` (50214) — 4 tests
  de integración que cubren los modos Variable y AlwaysVariable en el flujo completo de
  contabilización (compra y venta), complementando los tests Fixed ya existentes en 50209.
- Gap P1-01 cerrado: nuevo codeunit `DUoM Variant Del Tests` (50215) — 3 tests que
  verifican el borrado en cascada de `DUoM Item Variant Setup` cuando se elimina la
  `Item Variant` correspondiente (trigger `OnDelete` en tableextension 50120).
- Gaps P1-02 y P2 documentados en `TestCoverageAudit.md` para futuros issues.

**Deliverables:**
- `docs/TestCoverageAudit.md` — matriz de cobertura y análisis de gaps
- `app/src/codeunit/DUoMUoMHelper.Codeunit.al` (50106) — `Access = Internal` → `Access = Public`
- `test/src/codeunit/DUoMUoMHelperTests.Codeunit.al` (codeunit 50213) — 7 tests P0
- `test/src/codeunit/DUoMVarModePostTests.Codeunit.al` (codeunit 50214) — 4 tests P0
- `test/src/codeunit/DUoMVariantDelTests.Codeunit.al` (codeunit 50215) — 3 tests P1

---

## Phase 2 — Funcionalidad extendida

> **Siguiente issue recomendado:** Issue 12 — Modelo de coste/precio en doble UoM.
> Es independiente de warehouse y lotes, por lo que puede comenzarse inmediatamente
> una vez completado Issue 11.

### Issue 11b — Soporte Item Variants (jerarquía Item → Variant) ✅ IMPLEMENTADO

**Objetivo:** extender la solución DUoM para soportar Item Variants con un modelo de
override opcional: el artículo mantiene la configuración base, y cada variante puede
sobreescribir campos concretos (Second UoM Code, Conversion Mode, Fixed Ratio) sin
necesidad de duplicar toda la configuración.

Alcance implementado:
- Nueva tabla `DUoM Item Variant Setup` (50101) con clave `(Item No., Variant Code)`.
  Campos: `Second UoM Code`, `Conversion Mode`, `Fixed Ratio`. No incluye
  `Dual UoM Enabled` (el master switch siempre vive en el item setup).
- Nuevo codeunit `DUoM Setup Resolver` (50107) que encapsula la lógica jerárquica:
  Item Setup (master switch) → Variant Override → Item defaults. Todos los
  suscriptores y triggers de tabla usan este resolver.
- Nueva página `DUoM Variant Setup List` (50101) — lista de overrides por variante,
  abierta desde el Item Card con un nuevo filtro por Item No.
- Acción `DUoM Variant Overrides` añadida a `DUoM Item Card Ext` (pageextension 50100).
- TableExtension `DUoM Item Variant Ext` (50120) sobre `Item Variant` con trigger
  `OnDelete` para borrado en cascada del override DUoM de esa variante.
- `DUoM Purchase Subscribers` (50102): suscriptor para `Variant Code` validate añadido;
  suscriptor de `Quantity` refactorizado para usar el resolver.
- `DUoM Sales Subscribers` (50103): mismo patrón que compras.
- `DUoM Inventory Subscribers` (50104): suscriptor de `Quantity` en Item Journal Line
  refactorizado para usar el resolver con `Variant Code`.
- `DUoM UoM Helper` (50106): nuevo método `GetRoundingPrecisionByUoMCode(ItemNo, SecondUoMCode)`
  para obtener la precisión de redondeo a partir de un código UoM ya resuelto.
- `DUoMPurchaseLine.TableExt.al` y `DUoMSalesLine.TableExt.al` (50110, 50111):
  triggers `OnValidate` de `DUoM Ratio` y `DUoM Second Qty` refactorizados para usar
  el resolver y el nuevo método de rounding del helper.
- Permission sets `DUoM - All` (50100) y `DUoM - Test All` (50200): entrada
  `tabledata "DUoM Item Variant Setup" = RIMD` añadida.
- `DUoM Test Helpers` (50208): métodos `CreateVariantSetup` y `DeleteVariantSetupIfExists`.
- 8 tests en nuevo codeunit `DUoM Variant Tests` (50211).
- Documentación actualizada: `docs/04-item-setup-model.md`, `docs/06-backlog.md`.

**Limitaciones conocidas:**
- Soporte warehouse (Warehouse Receipt, Shipment, Activity Lines) queda para Issue 14/15.
  El resolver está preparado para ser extendido con un tercer nivel de jerarquía (Lot).
- Soporte de lotes (jerarquía Lot override) queda para Issue 13.
- XLF (traducciones): los IDs correctos de los nuevos trans-units se generan por el
  compilador AL; deben extraerse del artefacto `DualUoM-BC.g.xlf` tras la primera
  compilación CI y commitearse en ambos XLF. Ver `docs/07-localization.md`.

**Deliverables:**
- `DUoMItemVariantSetup.Table.al` (table 50101)
- `DUoMSetupResolver.Codeunit.al` (codeunit 50107)
- `DUoMVariantSetupList.Page.al` (page 50101)
- `DUoMItemVariant.TableExt.al` (tableextension 50120)
- `DUoMPurchaseSubscribers.Codeunit.al` (50102) — refactorizado + subscriber Variant Code
- `DUoMSalesSubscribers.Codeunit.al` (50103) — refactorizado + subscriber Variant Code
- `DUoMInventorySubscribers.Codeunit.al` (50104) — refactorizado
- `DUoMUoMHelper.Codeunit.al` (50106) — nuevo método GetRoundingPrecisionByUoMCode
- `DUoMPurchaseLine.TableExt.al` (50110), `DUoMSalesLine.TableExt.al` (50111) — actualizados
- `DUoMItemCardExt.PageExt.al` (50100) — acción DUoM Variant Overrides
- `DUoMAll.PermissionSet.al` (50100), `DUoMTestAll.PermissionSet.al` (50200) — actualizados
- `DUoMTestHelpers.Codeunit.al` (50208) — métodos variant
- `DUoMVariantTests.Codeunit.al` (codeunit 50211) — 8 tests
- `docs/04-item-setup-model.md`, `docs/06-backlog.md`

### Issue 11 — Aplicar Rounding Precision de la UoM secundaria a `DUoM Second Qty` ✅ IMPLEMENTADO

**Objetivo:** aplicar el campo `Qty. Rounding Precision` de la tabla `Item Unit of Measure`
de BC 27 al cálculo y a la entrada manual de `DUoM Second Qty`, evitando valores físicamente
incoherentes como 11,5 PCS cuando la segunda UoM es discreta.

Alcance implementado:
- Nueva sobrecarga `ComputeSecondQtyRounded(FirstQty, Ratio, Mode, RoundingPrecision)` en
  `DUoM Calc Engine` (50101). Cuando `RoundingPrecision = 0` usa fallback `0.00001`.
  Para `AlwaysVariable` devuelve siempre 0 sin redondeo. La firma original
  `ComputeSecondQty` se mantiene sin cambios (compatibilidad hacia atrás).
- Nuevo `codeunit 50106 "DUoM UoM Helper"` con `GetSecondUoMRoundingPrecision(ItemNo)`
  que lee `ItemUnitOfMeasure."Qty. Rounding Precision"` para la segunda UoM del ítem y
  devuelve 0 como fallback.
- `DUoMPurchaseSubscribers` (50102) y `DUoMSalesSubscribers` (50103) usan
  `ComputeSecondQtyRounded` con la precisión obtenida de `DUoMUoMHelper`.
- Trigger `OnValidate` añadido al campo `DUoM Second Qty` en `DUoMPurchaseLine`,
  `DUoMSalesLine` y `DUoMItemJournalLine` para redondear la entrada manual del usuario.
- Trigger `OnValidate` de `DUoM Ratio` en las tres table extensions actualizado para
  usar `ComputeSecondQtyRounded`.
- 4 tests unitarios para `ComputeSecondQtyRounded` en `DUoMCalcEngineTests` (50204).
- 2 tests E2E de integración (compra y venta) que crean un `Item Unit of Measure` con
  `Qty. Rounding Precision = 1` y verifican que `DUoM Second Qty` = 12 (no 11,5) tras
  validar Qty = 10 con ratio 1,15.

**Deliverables:**
- `DUoMCalcEngine.Codeunit.al` (50101) — nueva sobrecarga `ComputeSecondQtyRounded`
- `DUoMUoMHelper.Codeunit.al` (50106) — helper de precisión de redondeo
- `DUoMPurchaseSubscribers.Codeunit.al` (50102), `DUoMSalesSubscribers.Codeunit.al` (50103) — actualizados
- `DUoMPurchaseLine.TableExt.al` (50110), `DUoMSalesLine.TableExt.al` (50111),
  `DUoMItemJournalLine.TableExt.al` (50112) — triggers `OnValidate` en `DUoM Second Qty`
- `DUoMCalcEngineTests.Codeunit.al` (50204), `DUoMPurchaseTests.Codeunit.al` (50205),
  `DUoMSalesTests.Codeunit.al` (50206) — nuevos tests

### Issue BUG-01 — Qty. Rounding Precision no visible ni editable en Item Units of Measure ✅ IMPLEMENTADO

**Objetivo:** corregir que el campo `Qty. Rounding Precision` de la tabla `Item Unit of Measure`
no aparezca por defecto en el subformulario de unidades de medida del artículo y sea de solo
lectura al añadirlo mediante personalización.

**Causa raíz:** la página estándar de BC 27 `"Item Units of Measure"` (page 5404) solo expone
`Qty. Rounding Precision` para la UoM base a través de una variable de página en el grupo
`"Current Base Unit of Measure"`. Para las UoM alternativas el campo está completamente ausente
del repeater. Al añadirlo mediante Personalizar, el runtime de BC lo muestra sin expresión
`Editable` explícita, lo que junto con la validación de tabla (que lanza error si existen
movimientos de almacén) lo hace aparecer como no editable.

**Bug corregido (BUG-01b):** la implementación inicial filtraba `Item Ledger Entry` solo
por `Item No.`, por lo que cualquier artículo con transacciones contabilizadas en *cualquier*
UoM aparecía como no editable en *todas* sus UoMs. Además, no se verificaban los `Warehouse Entry`.

**Solución implementada:**
- Nueva `pageextension 50110 "DUoM Item UoM Subform"` sobre `"Item Units of Measure"`.
- Añade `Qty. Rounding Precision` al repeater (visible por defecto) con
  `Editable = IsQtyRndPrecisionEditable`.
- La expresión de edición se calcula en `OnAfterGetRecord` por la combinación exacta
  `(Item No., Unit of Measure Code)`: el campo es editable solo cuando no existen
  `Item Ledger Entry` **ni** `Warehouse Entry` para esa UoM concreta del artículo.
  Transacciones en otras UoMs del mismo artículo no afectan la editabilidad de esta línea.
- 4 tests unitarios en `DUoM Item UoM Round Tests` (50212):
  (a) sin entradas → editable; (b) ILE para esa UoM → no editable;
  (c) ILE para otra UoM → editable; (d) WH entry para esa UoM → no editable.

**Deliverables:**
- `DUoMItemUoMSubform.PageExt.al` (pageextension 50110)
- `DUoMItemUoMRoundTests.Codeunit.al` (codeunit 50212) — 4 tests
- `DualUoM-BC.en-US.xlf` y `DualUoM-BC.es-ES.xlf` — trans-unit del ToolTip añadido
- `docs/06-backlog.md` actualizado

---

### Issue 12 — Modelo de coste/precio en doble UoM ✅ IMPLEMENTADO

**Objetivo:** permitir que el precio unitario y el coste se expresen también en términos
de la segunda unidad de medida, y que el importe de línea se calcule correctamente.

Alcance implementado:
- Campo `DUoM Unit Price` (Decimal) en `DUoM Sales Line Ext` (50111): derivación automática
  de `Unit Price` desde/hacia `DUoM Unit Price` cuando el ratio está disponible.
- Campo `DUoM Unit Cost` (Decimal) en `DUoM Purchase Line Ext` (50110): derivación automática
  de `Direct Unit Cost` desde/hacia `DUoM Unit Cost` cuando el ratio está disponible.
- Propagación de `DUoM Unit Cost` a históricos de compra: `DUoMPurchRcptLine.TableExt.al` (50114),
  `DUoMPurchInvLine.TableExt.al` (50116), `DUoMPurchCrMemoLine.TableExt.al` (50117).
- Propagación de `DUoM Unit Price` a históricos de venta: `DUoMSalesShipmentLine.TableExt.al` (50115),
  `DUoMSalesInvLine.TableExt.al` (50118), `DUoMSalesCrMemoLine.TableExt.al` (50119).
- Nueva tableextension `DUoM Value Entry Ext` (50121) sobre `Value Entry` con campo `DUoM Second Qty`
  para trazabilidad contable completa.
- Suscriptor `OnAfterInitValueEntry` en `DUoM Inventory Subscribers` (50104) para propagar
  `DUoM Second Qty` desde `Item Journal Line` a `Value Entry` — sin Modify().
- Visibilidad en páginas de pedido (editables) y documentos históricos (solo lectura).
- Permission sets `DUoM - All` (50100) y `DUoM - Test All` (50200) actualizados con
  `tabledata "Value Entry" = R`.
- Tests TDD: `DUoM Cost Price Tests` (codeunit 50216), 8 tests T01–T08.

**Deliverables:** `DUoMPurchaseLine.TableExt.al`, `DUoMSalesLine.TableExt.al`,
`DUoMValueEntry.TableExt.al` (50121), históricos de compra/venta actualizados,
`DUoMDocTransferHelper.Codeunit.al`, `DUoMInventorySubscribers.Codeunit.al`,
pageextensions 50101, 50102, 50104–50109, permission sets, XLF, `DUoMCostPriceTests.Codeunit.al` (50216)

### Issue 13 — Ratio real por lote con Item Tracking ✅ IMPLEMENTADO

**Objetivo:** almacenar y recuperar el ratio de conversión real (medido al pesaje o recepción)
asociado a un número de lote específico, integrado con el estándar de Item Tracking de BC 27.

**Hallazgo arquitectónico resuelto (2026-04-22):**
- En BC 27, `Lot No.` **no es campo directo** en `Purchase Line` (tabla 39) ni en `Sales Line`
  (tabla 37). Los lotes se gestionan a través de `Item Tracking Lines` / `Reservation Entry`.
- `Lot No.` **sí es campo directo** en `Item Journal Line` (tabla 83).
- El override por lote en ILE se implementa en `OnAfterInitItemLedgEntry` (proporcional).

**Deliverables:**
- `DUoM Lot Subscribers` (codeunit 50108): suscriptor IJL Lot No. + método `TryApplyLotRatioToILE`
- `DUoM Inventory Subscribers` (50104) modificado: recálculo proporcional en `OnAfterInitItemLedgEntry`
- `DUoM Lot Ratio Tests` (test codeunit 50217): 7 tests (T01–T07)
- Documentación actualizada: `docs/02-functional-design.md`, `docs/03-technical-architecture.md`,
  `docs/04-item-setup-model.md`, `docs/TestCoverageAudit.md`

**Dependencias:** Issue 12 completado. Issues 14/15 pueden ejecutarse en paralelo.

### Issue 20 — Eliminar asunciones 1:1 línea/lote y consolidar modelo 1:N ✅ IMPLEMENTADO

**Objetivo:** auditar y refactorizar todo el repositorio para eliminar cualquier asunción
funcional, técnica o de pruebas basada en que `1 línea origen BC = 1 lote`.
Consolidar el modelo correcto: `1 línea origen = N lotes (vía Item Tracking)`.

**Bug corregido:** En `OnAfterInitItemLedgEntry`, cuando `DUoM Ratio = 0` (modo AlwaysVariable
sin ratio genérico) y el `ItemJournalLine` tenía `Lot No.` asignado (multi-lote), el código
copiaba el total `DUoM Second Qty` de la línea a cada ILE. Esto era incorrecto: en un escenario
multi-lote, el total de la línea no puede asignarse a cada ILE individual sin ratio de lote.
Con la corrección, el ILE queda con `DUoM Second Qty = 0` en ese caso (limitación documentada),
evitando que datos incorrectos contaminen los registros de inventario.

**Nuevos tests (T08–T10) en `DUoM Lot Ratio Tests` (codeunit 50217):**
- T08: UNA sola línea IJL con DOS lotes vía Item Tracking → cada ILE tiene su ratio de lote
  (verdadero escenario 1:N de BC, diferente de T05 que usa dos líneas IJL separadas).
- T09: Suma de `DUoM Second Qty` de todos los ILEs = total esperado (coherencia 1:N).
- T10: AlwaysVariable + multi-lote sin ratio de lote → ILE `DUoM Second Qty = 0`
  (verifica que la corrección elimina el bug de copia incorrecta del total).

**Documentación actualizada:**
- `docs/02-functional-design.md`: sección "Regla de diseño: línea origen como agregado — modelo 1:N"
  con limitación conocida de AlwaysVariable + multi-lote sin ratio de lote.
- `docs/03-technical-architecture.md`: corrección de "PHASE 2 — PENDIENTE" en `DUoM Lot Ratio` (50102),
  nueva sección "Modelo 1:N — Línea origen como agregado" con principios y restricciones.
- `docs/06-backlog.md`: Issue 13 actualizado (T01–T07 → T01–T10), Issue 20 añadido.
- `docs/issues/issue-20-multilot-1n-refactor.md`: documentación del issue completa.

**Deliverables:**
- `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al` (50104) — corrección `OnAfterInitItemLedgEntry`
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` (50217) — 3 nuevos tests T08–T10
- `docs/02-functional-design.md`, `docs/03-technical-architecture.md`, `docs/06-backlog.md`
- `docs/issues/issue-20-multilot-1n-refactor.md`

### Issue 154 — Fix: ratio real por lote no se aplica al validar Lot No. en Item Journal Line ✅ IMPLEMENTADO

**Objetivo:** corregir la regresión funcional por la que `DUoM Ratio` quedaba en `0,40` (ratio
por defecto del artículo) en lugar de `0,38` (ratio real del lote) al validar `"Lot No."` en
un `Item Journal Line` de un artículo en modo Variable con ratio de lote registrada.

**Causa raíz:** El suscriptor `OnAfterValidateItemJnlLineLotNo` llamaba a
`Rec.Validate("DUoM Ratio", 0.38)` tras encontrar el ratio de lote. En BC 27, esta validación
anidada dentro de un `OnAfterValidateEvent` puede restaurar el valor por defecto del artículo,
impidiendo que el ratio de lote `0,38` se persista en el buffer del registro llamante.

**Corrección:** Renombrado `ApplyLotRatioIfExists` → `TryApplyLotRatioIfExists` (Boolean) y
`ApplyLotRatioToRecord` → `TryApplyLotRatioToRecord` (Boolean). El suscriptor ahora sólo
actualiza los campos DUoM con asignación directa (`:=`) cuando `TryApplyLotRatioIfExists`
devuelve `true`, evitando la validación anidada que restauraba el ratio por defecto.

**Nuevo test T11:** `T11_VariableMode_LotWithRatio_DUoMFieldsPreFilled` con precondiciones
reforzadas que verifican explícitamente que el ratio de lote prevalece sobre el ratio por defecto.

**Deliverables:**
- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` (50108) — corrección subscriber + helpers Boolean
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` (50217) — nuevo test T11
- `docs/06-backlog.md`, `docs/issues/issue-154-fix-lot-ratio-subscriber-validate.md`

### Issue 14 — Warehouse Basic Documents DUoM Fields

**Objetivo:** extender los documentos de entrada y salida de almacén básico con campos DUoM.

Alcance:
- Table extension en `Warehouse Receipt Line` con `DUoM Second Qty` y `DUoM Ratio`.
- Table extension en `Warehouse Shipment Line` con los mismos campos.
- Page extensions en los subformularios de entrada/salida de almacén para mostrar los campos.
- Suscriptores para propagar DUoM desde `Purchase Line` / `Sales Line` al crear las líneas
  de almacén (evento adecuado de BC 27, a verificar contra símbolos antes de implementar).
- Propagación desde `Warehouse Receipt Line` / `Warehouse Shipment Line` hacia `ILE` al
  contabilizar (a través del camino `Warehouse Entry` si procede, o directo a `Item Journal Line`).
- Actualizar permission sets.
- Tests TDD:
  - Crear un Warehouse Receipt desde un Purchase Order con DUoM → verificar campos propagados.
  - Contabilizar Warehouse Receipt → verificar ILE con `DUoM Second Qty`.
  - Crear un Warehouse Shipment desde un Sales Order con DUoM → verificar campos.
  - Contabilizar Warehouse Shipment → verificar ILE.

**Dependencias:** Issues 1–11 completados. Issue 12 recomendado antes para consistencia de coste.
**Nota:** Verificar nombres exactos de páginas BC 27 antes de crear page extensions
(`Warehouse Receipt Subform`, `Warehouse Shipment Subform`) usando el BC Symbol Reference.

### Issue 15 — Directed Put-Away and Pick DUoM Fields

**Objetivo:** extender los documentos de actividad de almacén dirigido (put-away y pick)
con campos DUoM para seguimiento de segunda cantidad en movimientos internos.

Alcance:
- Table extension en `Warehouse Activity Line` con `DUoM Second Qty` y `DUoM Ratio`.
- Page extension en el subformulario de put-away/pick para mostrar los campos (solo lectura).
- Propagación desde `Warehouse Receipt Line` / `Warehouse Shipment Line` al crear las
  líneas de actividad (evento adecuado de BC 27, a verificar).
- Tests TDD:
  - Crear put-away desde Warehouse Receipt con DUoM → verificar campos en actividad.
  - Crear pick desde Warehouse Shipment con DUoM → verificar campos.

**Dependencias:** Issue 14 completado.

### Issue 16 — Documentos de devolución DUoM

**Objetivo:** soportar DUoM en órdenes de devolución de compra y venta.

Alcance:
- Extender `Return Shipment Line` con campos DUoM (table extension).
- Extender `Return Receipt Line` con campos DUoM (table extension).
- Suscriptores para propagar DUoM al contabilizar devoluciones:
  - `Purchase Return Order` → `Return Shipment Line` → ILE
  - `Sales Return Order` → `Return Receipt Line` → ILE
- Extender las páginas de subformulario de documentos de devolución registrados.
- Actualizar permission sets.
- Tests TDD:
  - Crear Purchase Return Order con DUoM → contabilizar → verificar Return Shipment Line e ILE.
  - Crear Sales Return Order con DUoM → contabilizar → verificar Return Receipt Line e ILE.

**Dependencias:** Issues 1–11. Issue 12 recomendado.
**Nota:** Verificar nombres exactos de páginas BC 27 antes de implementar.

### Issue 17 — Physical Inventory DUoM

**Objetivo:** permitir el recuento de inventario físico expresando cantidades en segunda UoM.

Alcance:
- Extender `Phys. Inventory Ledger Entry` con `DUoM Second Qty`.
- Extender `Item Journal Line` (modo recuento físico) — ya extendida; verificar si
  se requiere lógica adicional para el flujo de inventario físico.
- Tests TDD: crear línea de diario de recuento físico con segunda cantidad → contabilizar
  → verificar movimiento de producto.

**Dependencias:** Issue 8 completado (Item Journal ya extendido).

### Issue 18 — Reporting Extensions

**Objetivo:** añadir columnas de segunda cantidad y segunda UoM a los informes estándar clave.

Alcance (report extensions en BC 27):
- Informe de recepción de compra (Purchase Receipt): añadir `DUoM Second Qty` y `DUoM Ratio`
  en líneas, con header de segunda UoM.
- Informe de albarán de venta (Sales Shipment): ídem.
- Informe de valoración de inventario: añadir columna de segunda cantidad total.
- Tests: verificar que los campos se incluyen en los datasets de informe (unit tests de dataset).

**Dependencias:** Issues 9 y 12 recomendados antes.

---

## Phase 3 / Futuro

- Orden de traslado DUoM (`Transfer Order`) — Issue 18+
- Órdenes de montaje DUoM (`Assembly Order`) — si entra en scope
- ~~Integración con Item Tracking avanzado (multi-lote en línea)~~ ✅ Resuelto en Issue 20

---

## Notes

- Los issues deben implementarse en el orden indicado; los posteriores dependen de los anteriores.
- **TDD obligatorio:** cada issue debe incluir tests en fallo antes de escribir el código de producción.
- ~~The `DualUoM Pipeline Check` codeunit (ID 50100) and its test (ID 50200) are
  temporary and will be deleted when Issue 2 (Calc Engine) is merged.~~ ✅ Eliminados.
- El Calc Engine usa ID 50101; los tests del Calc Engine usan ID 50204.
  Los IDs 50201–50203 están ya usados por `DUoM Item Setup Tests`,
  `DUoM Item Card Opening Tests` y `DUoM Item Delete Tests`.
- **Localización:** todos los nuevos objetos con texto visible por el usuario deben incluir
  Labels con `Comment` y tener ambos XLF (`en-US` y `es-ES`) actualizados en el mismo PR.
  Ver `docs/07-localization.md` para el flujo completo.
- **Localización Phase 1 (Issues 2–10):** ✅ Todos los trans-units de los nuevos objetos
  (Codeunit 50101, PageExtensions 50101/50102/50104–50109, TableExtensions 50114–50119)
  están en ambos XLF con IDs verificados mediante `LanguageFileUtilities.GetNameHash`
  del compilador AL (runtime 15).
- **Localización Issue 11 (Rounding Precision):** ✅ `DUoM UoM Helper` (50106) no introduce
  cadenas de usuario visibles (sin `Label`). No se requieren nuevas entradas XLF.
- **IDs de test codeunit usados en Phase 1:** 50201–50208 (tests unitarios e integración),
  50209 (`DUoM ILE Integration Tests`, tests E2E de contabilización) y
  50210 (`DUoM Inv CrMemo Post Tests`, tests E2E de facturación y abono).
  **Issue 11b:** `DUoM Variant Tests` usa ID 50211.
  **IDs libres para Phase 2:** 50212+ para nuevos codeunits de test.
- **Rango de IDs de objetos de producción:** 50100–50199.
  IDs ya asignados en Phase 1 + Issues 11/11b:
  - tablas: 50100 (`DUoM Item Setup`), 50101 (`DUoM Item Variant Setup`)
  - enums: 50100
  - codeunits: 50101–50107 (50107 = `DUoM Setup Resolver`)
  - pages: 50100 (`DUoM Item Setup`), 50101 (`DUoM Variant Setup List`)
  - pageextensions: 50100–50109
  - tableextensions: 50100, 50110–50120 (50120 = `DUoM Item Variant Ext`)
  IDs libres para Phase 2 (Issue 12+): tableextensions 50121+, codeunits 50108+, pages 50102+.
- **Eventos BC 27 — referencia de firma verificada:**
  - Purch. Rcpt. Line init: `OnAfterInitFromPurchLine` en Table `"Purch. Rcpt. Line"` — var ÚLTIMO
  - Purch. Inv. Line init: `OnAfterInitFromPurchLine` en Table `"Purch. Inv. Line"` — var ÚLTIMO
  - Purch. Cr. Memo Line init: `OnAfterInitFromPurchLine` en Table `"Purch. Cr. Memo Line"` — var ÚLTIMO
  - Sales Shipment Line init: `OnAfterInitFromSalesLine` en Table `"Sales Shipment Line"` — var ÚLTIMO
  - Sales Invoice Line init: `OnAfterInitFromSalesLine` en Table `"Sales Invoice Line"` — var **PRIMERO**
  - Sales Cr.Memo Line init: `OnAfterInitFromSalesLine` en Table `"Sales Cr.Memo Line"` — var **PRIMERO**
  - ILE init: `OnAfterInitItemLedgEntry` en Codeunit `"Item Jnl.-Post Line"`
  - Item Journal Line copy (purchase): `OnPostItemJnlLineOnAfterCopyDocumentFields` en Codeunit `"Purch.-Post"`
  - Item Journal Line copy (sales): `OnPostItemJnlLineOnAfterCopyDocumentFields` en Codeunit `"Sales-Post"`
  - **Antes de añadir cualquier nuevo suscriptor**, verificar firma en BC 27 contra
    `microsoft/ALAppExtensions` o el Symbol Reference de VS Code.
- **Patrón thin subscriber + helper centralizado:** toda la lógica de copia de campos
  DUoM entre líneas debe delegarse a `DUoM Doc Transfer Helper` (50105). Los suscriptores
  son siempre delegadores. Esto aplica a todos los issues de Phase 2.
- **Permission sets:** cada nueva tabla requiere entrada `tabledata ... = RIMD` en
  `DUoMAll.PermissionSet.al` (50100) Y en `DUoMTestAll.PermissionSet.al` (50200) en el mismo PR.
