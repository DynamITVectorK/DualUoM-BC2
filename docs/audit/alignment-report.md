# Informe de Alineación de Documentación
_Generado: 2026-04-22_

## Resumen

Auditoría completa del repositorio DualUoM-BC. Se inventariaron todos los objetos AL
(`app/src/` y `test/src/`) y se compararon con el contenido de todos los archivos `.md`.
Los cambios se agrupan por archivo y tipo de discrepancia.

---

## Cambios realizados

| Archivo modificado | Qué cambió | Motivo |
|--------------------|------------|--------|
| `docs/TestCoverageAudit.md` | Añadida `tableextension 50121 "DUoM Value Entry Ext"` al inventario de objetos de producción | Objeto implementado en Issue 12 pero ausente del inventario |
| `docs/TestCoverageAudit.md` | Añadida fila de `tableextension 50120 "DUoM Item Variant Ext"` al inventario (estaba en el código pero no en la tabla) | Omisión en el inventario de producción |
| `docs/TestCoverageAudit.md` | Añadidos codeunits de test 50213–50216 al inventario de test codeunits | Todos implementados pero no listados en el documento |
| `docs/TestCoverageAudit.md` | Actualizada la matriz de cobertura: DUoM Item Variant Setup (table 50101) pasa de "Parcial" a "Completa" | El cascade delete ya tiene test en codeunit 50215 |
| `docs/TestCoverageAudit.md` | Actualizada la matriz de cobertura: Item Variant.TableExt pasa de "GAP P1" a "Completa (50215)" | Codeunit 50215 implementado y funcional |
| `docs/TestCoverageAudit.md` | Actualizada la matriz de cobertura: DUoM UoM Helper (cu 50106) pasa de "GAP P0" a "Completa (50213)" | Codeunit 50213 implementado y funcional |
| `docs/TestCoverageAudit.md` | Añadida fila `DUoM Value Entry Ext (TableExt 50121)` a la matriz de cobertura | Objeto implementado sin fila correspondiente en la matriz |
| `docs/TestCoverageAudit.md` | Actualizadas filas Purchase/Sales Line, ILE, PurchRcptLine, etc. con referencias a 50214 y 50216 | Los tests de modo Variable/AlwaysVariable y coste/precio ya existen |
| `docs/TestCoverageAudit.md` | GAP-P0-01, GAP-P0-02 y GAP-P1-01 marcados como **CERRADOS** con descripción de solución implementada | Los tres gaps tienen codeunit de test funcional |
| `docs/TestCoverageAudit.md` | Tabla P2 de gaps: eliminadas las entradas `DualUoMPurchInvoiceCostTest`, `DualUoMSalesPriceTest` y `DualUoMValueEntryTest` | Cubiertos por codeunit 50216 (tests T01–T08) e implementados en Issue 12 |
| `docs/TestCoverageAudit.md` | Añadida tabla "Estado Actual del Test Suite" con los 16 codeunits de test | Resumen del estado real tras todas las implementaciones |
| `docs/03-technical-architecture.md` | Corregido el principio SaaS sobre propagación en posting: de `"OnBefore*Insert"` a `"eventos de inicialización de tabla (OnAfterInit*)"` | El código usa `OnAfterInitFromPurchLine` / `OnAfterInitFromSalesLine` en tablas destino, no `OnBefore*Insert` en codeunits. El patrón `OnBefore*Insert` nunca se implementó y varios de esos eventos no existen en BC 27 (véase Issue 10) |
| `docs/06-backlog.md` | Issue 3: corregido ID de `DUoMItemCardExt.PageExt.al` de `(pageextension 50103)` a `(pageextension 50100)` | El archivo AL declara `pageextension 50100 "DUoM Item Card Ext"` |
| `docs/06-backlog.md` | Issue 8: añadido ID `(pageextension 50103)` a `DUoMItemJournalExt.PageExt.al` | El ID faltaba en la lista de deliverables |
| `docs/06-backlog.md` | Issue 12: corregido permiso `tabledata "Value Entry" = RIMD` a `tabledata "Value Entry" = R` | El permission set `DUoM - All` (50100) y `DUoM - Test All` (50200) solo otorgan permiso de lectura (`R`) sobre `Value Entry` (tabla estándar; la extensión solo escribe el campo a través de un evento antes del Insert) |
| `docs/01-scope-mvp.md` | Eliminado "Value entry propagation (for costing accuracy)" de la lista Phase 2 | Implementado en Issue 12 (`DUoM Value Entry Ext`, tableextension 50121, subscriber `OnAfterInitValueEntry` en codeunit 50104) |

---

## Elementos marcados como Planificados (en docs pero aún no en código)

| Archivo doc | Elemento | Notas |
|-------------|----------|-------|
| `docs/06-backlog.md` | Issue 13 — Ratio real por lote (`DUoM Lot Ratio` table, `DUoMLotSubscribers`) | No implementado; correcto que figure como pendiente |
| `docs/06-backlog.md` | Issue 14 — Warehouse Receipt and Shipment DUoM Fields | No implementado; correcto que figure como pendiente |
| `docs/06-backlog.md` | Issue 15 — Directed Put-Away and Pick DUoM Fields | No implementado; correcto que figure como pendiente |
| `docs/06-backlog.md` | Issue 16 — Return Orders DUoM | No implementado; correcto que figure como pendiente |
| `docs/06-backlog.md` | Issue 17 — Physical Inventory DUoM | No implementado; correcto que figure como pendiente |
| `docs/01-scope-mvp.md` | Phase 2: Lot-specific real ratio, Physical inventory, Warehouse, Reporting | No implementados; correctos como pendientes |
| `docs/TestCoverageAudit.md` | P2 gaps: WMS tests, Lot Ratio tests | No implementados; correctos como pendientes en tabla P2 |

---

## Nuevas secciones añadidas (en código pero sin documentación previa)

| Archivo doc | Elemento añadido | Objeto AL fuente |
|-------------|-----------------|-----------------|
| `docs/TestCoverageAudit.md` | Fila de inventario `tableextension 50121 "DUoM Value Entry Ext"` | `app/src/tableextension/DUoMValueEntry.TableExt.al` (50121) |
| `docs/TestCoverageAudit.md` | Fila de inventario `tableextension 50120 "DUoM Item Variant Ext"` | `app/src/tableextension/DUoMItemVariant.TableExt.al` (50120) |
| `docs/TestCoverageAudit.md` | Fila de inventario codeunit 50213 `DUoM UoM Helper Tests` | `test/src/codeunit/DUoMUoMHelperTests.Codeunit.al` |
| `docs/TestCoverageAudit.md` | Fila de inventario codeunit 50214 `DUoM Variable Mode Post Tests` | `test/src/codeunit/DUoMVarModePostTests.Codeunit.al` |
| `docs/TestCoverageAudit.md` | Fila de inventario codeunit 50215 `DUoM Variant Del Tests` | `test/src/codeunit/DUoMVariantDelTests.Codeunit.al` |
| `docs/TestCoverageAudit.md` | Fila de inventario codeunit 50216 `DUoM Cost Price Tests` | `test/src/codeunit/DUoMCostPriceTests.Codeunit.al` |
| `docs/TestCoverageAudit.md` | Fila de cobertura `DUoM Value Entry Ext (TableExt 50121)` en la matriz | `app/src/tableextension/DUoMValueEntry.TableExt.al` |
| `docs/TestCoverageAudit.md` | Tabla "Estado Actual del Test Suite" (resumen de los 16 codeunits) | Todos los codeunits en `test/src/codeunit/` |
| `docs/audit/alignment-report.md` | Este informe de auditoría | Requerido por el issue de alineación docs-código |

---

## Inventario de objetos AL verificado

### Tablas custom

| ID | Nombre | Campos clave |
|----|--------|--------------|
| table 50100 | `DUoM Item Setup` | Item No. (PK), Dual UoM Enabled, Second UoM Code, Conversion Mode, Fixed Ratio |
| table 50101 | `DUoM Item Variant Setup` | Item No. (PK), Variant Code (PK), Second UoM Code, Conversion Mode, Fixed Ratio |

### Enums

| ID | Nombre | Valores |
|----|--------|---------|
| enum 50100 | `DUoM Conversion Mode` | Fixed (0), Variable (1), AlwaysVariable (2) |

### Codeunits de producción

| ID | Nombre | Access | Métodos públicos relevantes |
|----|--------|--------|----------------------------|
| 50101 | `DUoM Calc Engine` | Public | `ComputeSecondQty`, `ComputeSecondQtyRounded` |
| 50102 | `DUoM Purchase Subscribers` | Internal | Subscribers: Quantity validate, Variant Code validate en Purchase Line |
| 50103 | `DUoM Sales Subscribers` | Internal | Subscribers: Quantity validate, Variant Code validate en Sales Line |
| 50104 | `DUoM Inventory Subscribers` | Internal | Subscribers: Item Journal Qty, OnPurchPostCopy, OnSalesPostCopy, OnAfterInitFrom* (6 tablas históricas), OnAfterInitItemLedgEntry, OnAfterInitValueEntry |
| 50105 | `DUoM Doc Transfer Helper` | Internal | CopyFromPurchLineToPurchRcptLine, CopyFromSalesLineToShipLine, CopyFromPurchLineToPurchInvLine, CopyFromPurchLineToPurchCrMemoLine, CopyFromSalesLineToSalesInvLine, CopyFromSalesLineToSalesCrMemoLine |
| 50106 | `DUoM UoM Helper` | Public | `GetSecondUoMRoundingPrecision(ItemNo)`, `GetRoundingPrecisionByUoMCode(ItemNo, SecondUoMCode)` |
| 50107 | `DUoM Setup Resolver` | Public | `GetEffectiveSetup(ItemNo, VariantCode, var SecondUoMCode, var ConversionMode, var FixedRatio): Boolean` |

### TableExtensions

| ID | Nombre | Extiende | Campos/Triggers DUoM |
|----|--------|----------|----------------------|
| 50100 | `DUoM Item TableExt` | Item | OnDelete (cascade delete DUoM Item Setup) |
| 50110 | `DUoM Purchase Line Ext` | Purchase Line | DUoM Second Qty (50100), DUoM Ratio (50101), DUoM Unit Cost (50102) |
| 50111 | `DUoM Sales Line Ext` | Sales Line | DUoM Second Qty (50100), DUoM Ratio (50101), DUoM Unit Price (50102) |
| 50112 | `DUoM Item Journal Line Ext` | Item Journal Line | DUoM Second Qty (50100), DUoM Ratio (50101) |
| 50113 | `DUoM Item Ledger Entry Ext` | Item Ledger Entry | DUoM Second Qty (50100), DUoM Ratio (50101) |
| 50114 | `DUoM Purch. Rcpt. Line Ext` | Purch. Rcpt. Line | DUoM Second Qty (50100), DUoM Ratio (50101), DUoM Unit Cost (50102) |
| 50115 | `DUoM Sales Shipment Line Ext` | Sales Shipment Line | DUoM Second Qty (50100), DUoM Ratio (50101), DUoM Unit Price (50102) |
| 50116 | `DUoM Purch. Inv. Line Ext` | Purch. Inv. Line | DUoM Second Qty (50100), DUoM Ratio (50101), DUoM Unit Cost (50102) |
| 50117 | `DUoM Purch. Cr. Memo Line Ext` | Purch. Cr. Memo Line | DUoM Second Qty (50100), DUoM Ratio (50101), DUoM Unit Cost (50102) |
| 50118 | `DUoM Sales Inv. Line Ext` | Sales Invoice Line | DUoM Second Qty (50100), DUoM Ratio (50101), DUoM Unit Price (50102) |
| 50119 | `DUoM Sales Cr.Memo Line Ext` | Sales Cr.Memo Line | DUoM Second Qty (50100), DUoM Ratio (50101), DUoM Unit Price (50102) |
| 50120 | `DUoM Item Variant Ext` | Item Variant | OnDelete (cascade delete DUoM Item Variant Setup) |
| 50121 | `DUoM Value Entry Ext` | Value Entry | DUoM Second Qty (50100) |

### PageExtensions

| ID | Nombre | Extiende | Campos DUoM visibles |
|----|--------|----------|----------------------|
| 50100 | `DUoM Item Card Ext` | Item Card | Acciones: DUoMSetup, DUoMVariantSetup (Navigation) |
| 50101 | `DUoM Purchase Order Subform` | Purchase Order Subform | DUoM Second Qty (editable según modo), DUoM Ratio, DUoM Unit Cost |
| 50102 | `DUoM Sales Order Subform` | Sales Order Subform | DUoM Second Qty (editable según modo), DUoM Ratio, DUoM Unit Price |
| 50103 | `DUoM Item Journal Ext` | Item Journal | DUoM Second Qty (editable solo en AlwaysVariable), DUoM Ratio |
| 50104 | `DUoM Posted Rcpt. Subform` | Posted Purchase Rcpt. Subform | DUoM Second Qty, DUoM Ratio, DUoM Unit Cost (solo lectura) |
| 50105 | `DUoM Posted Ship. Subform` | Posted Sales Shpt. Subform | DUoM Second Qty, DUoM Ratio, DUoM Unit Price (solo lectura) |
| 50106 | `DUoM Pstd Purch Inv Subform` | Posted Purch. Invoice Subform | DUoM Second Qty, DUoM Ratio, DUoM Unit Cost (solo lectura) |
| 50107 | `DUoM Pstd Purch CrM Subform` | Posted Purch. Cr. Memo Subform | DUoM Second Qty, DUoM Ratio, DUoM Unit Cost (solo lectura) |
| 50108 | `DUoM Pstd Sales Inv Subform` | Posted Sales Invoice Subform | DUoM Second Qty, DUoM Ratio, DUoM Unit Price (solo lectura) |
| 50109 | `DUoM Pstd Sales CrM Subform` | Posted Sales Cr. Memo Subform | DUoM Second Qty, DUoM Ratio, DUoM Unit Price (solo lectura) |
| 50110 | `DUoM Item UoM Subform` | Item Units of Measure | Qty. Rounding Precision (editable si no hay ILE ni WH Entry para esa UdM) |
| 50111 | `DUoM Item Ledger Entry` | Item Ledger Entries | DUoM Second Qty, DUoM Ratio (solo lectura) |

### Permission Sets

| ID | Nombre | Tablas |
|----|--------|--------|
| permissionset 50100 | `DUoM - All` | tabledata "DUoM Item Setup" = RIMD; tabledata "DUoM Item Variant Setup" = RIMD; tabledata "Value Entry" = R |
| permissionset 50200 | `DUoM - Test All` | tabledata "DUoM Item Setup" = RIMD; tabledata "DUoM Item Variant Setup" = RIMD; tabledata "Value Entry" = R |

### Rangos de ID realmente utilizados

| Tipo | IDs usados |
|------|------------|
| Tables (app) | 50100–50101 |
| Enums (app) | 50100 |
| Codeunits (app) | 50101–50107 |
| Pages (app) | 50100–50101 |
| TableExtensions (app) | 50100, 50110–50121 |
| PageExtensions (app) | 50100–50111 |
| PermissionSets (app) | 50100 |
| Test Codeunits | 50201–50216 (excl. 50208 helper) |
| PermissionSets (test) | 50200 |
