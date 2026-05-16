# Auditoría de Cobertura de Tests — DualUoM-BC

> **Fecha de auditoría:** 2026-04-20 — Actualizado: 2026-04-29 (Issues 13, 20, 21)
> **Estado del repositorio auditado:** Phase 1 MVP completada

---

## Introducción

Este documento recoge la matriz de cobertura de tests del proyecto DualUoM-BC,
identifica los gaps existentes y propone los codeunits de test necesarios para
cerrar dichos gaps según los niveles de prioridad definidos en el issue de auditoría.

---

## Objetos de Producción — Inventario

| ID | Objeto | Tipo |
|----|--------|------|
| enum 50100 | DUoM Conversion Mode | Enum |
| table 50100 | DUoM Item Setup | Table |
| table 50101 | DUoM Item Variant Setup | Table |
| table 50102 | DUoM Lot Ratio | Table |
| tableextension 50100 | Item (cascade delete) | TableExt |
| tableextension 50110 | Purchase Line | TableExt |
| tableextension 50111 | Sales Line | TableExt |
| tableextension 50112 | Item Journal Line | TableExt |
| tableextension 50113 | Item Ledger Entry | TableExt |
| tableextension 50114 | Purch. Rcpt. Line | TableExt |
| tableextension 50115 | Sales Shipment Line | TableExt |
| tableextension 50116 | Purch. Inv. Line | TableExt |
| tableextension 50117 | Purch. Cr. Memo Line | TableExt |
| tableextension 50118 | Sales Invoice Line | TableExt |
| tableextension 50119 | Sales Cr.Memo Line | TableExt |
| tableextension 50120 | Item Variant (cascade delete) | TableExt |
| tableextension 50121 | DUoM Value Entry Ext (Value Entry) | TableExt |
| tableextension 50122 | DUoM Tracking Spec Ext (Tracking Specification) | TableExt |
| tableextension 50123 | DUoM Reservation Entry Ext (Reservation Entry) | TableExt |
| codeunit 50101 | DUoM Calc Engine | Codeunit |
| codeunit 50102 | DUoM Purchase Subscribers | Codeunit |
| codeunit 50103 | DUoM Sales Subscribers | Codeunit |
| codeunit 50104 | DUoM Inventory Subscribers | Codeunit |
| codeunit 50105 | DUoM Doc Transfer Helper | Codeunit |
| codeunit 50106 | DUoM UoM Helper | Codeunit |
| codeunit 50107 | DUoM Setup Resolver | Codeunit |
| codeunit 50108 | DUoM Lot Subscribers | Codeunit |
| codeunit 50109 | DUoM Tracking Subscribers | Codeunit |
| page 50100 | DUoM Item Setup | Page |
| page 50101 | DUoM Variant Setup List | Page |
| page 50102 | DUoM Lot Ratio List | Page |
| pageextension 50100–50111 | Varios (campos DUoM en forms, incl. Item Tracking Lines) | PageExt |
| permissionset 50100 | DUoM - All | PermissionSet |

---

## Codeunits de Test — Inventario

| ID | Nombre | Objeto(s) cubierto(s) |
|----|--------|-----------------------|
| 50201 | DUoM Item Setup Tests | DUoM Item Setup (validaciones, triggers) |
| 50202 | DUoM Item Card Opening Tests | DUoM Item Setup.GetOrCreate() |
| 50203 | DUoM Item Delete Tests | Item.TableExt (cascade delete) |
| 50204 | DUoM Calc Engine Tests | DUoM Calc Engine (todos los modos y casos límite) |
| 50205 | DUoM Purchase Tests | DUoM Purchase Subscribers (todos los modos, rounding) |
| 50206 | DUoM Sales Tests | DUoM Sales Subscribers (todos los modos, rounding) |
| 50207 | DUoM Inventory Tests | DUoM Inventory Subscribers (ItemJnl, ILE campos) |
| 50208 | DUoM Test Helpers | Helper compartido (factoría de datos) — no es test |
| 50209 | DUoM ILE Integration Tests | ILE, PurchRcptLine, SalesShipLine (modo Fixed) |
| 50210 | DUoM Inv CrMemo Post Tests | PurchInvLine, PurchCrMemoLine, SalesInvLine, SalesCrMemoLine |
| 50211 | DUoM Variant Tests | DUoM Setup Resolver, Purchase/Sales Line con variante |
| 50212 | DUoM Item UoM Round Tests | DUoM Item UoM Subform (editabilidad Qty. Rounding Precision) |
| 50213 | DUoM UoM Helper Tests | DUoM UoM Helper (GetSecondUoMRoundingPrecision, GetRoundingPrecisionByUoMCode) |
| 50214 | DUoM Variable Mode Post Tests | Tests E2E en modos Variable y AlwaysVariable (compra y venta) |
| 50215 | DUoM Variant Del Tests | Item Variant TableExt (cascade delete de DUoM Item Variant Setup) |
| 50216 | DUoM Cost Price Tests | DUoM Unit Cost / DUoM Unit Price, propagación a históricos, DUoM Second Qty en Value Entry |
| 50217 | DUoM Lot Ratio Tests | DUoM Lot Ratio (table), DUoM Lot Subscribers (Issue 13) |
| 50218 | DUoM Item Tracking Tests | DUoM Tracking Subscribers, DUoM Tracking Spec Ext, DUoM Item Tracking Lines (Issue 22) |
| 50219 | DUoM Purch Tracking Persist | DUoM Reservation Entry Ext, TrackingSpec ↔ RE persistencia E2E |
| 50220 | DUoM Tracking Coherence Tests | DUoM Tracking Coherence Mgt (validación coherencia buffer) |
| 50221 | DUoM Purch Tracking Post Tests | Posting con tracking por lote → ILE |
| 50222 | DUoM Purch Track Close Tests | Cierre Item Tracking Lines |
| 50223 | DUoM Purch Track Val Tests | Validación DUoM en tracking |
| 50224 | DUoM Pstd Item Trk. Tests | Líneas de tracking registradas (solo lectura) |
| 50225 | DUoM Purch Sync Tests | Sincronización línea compra con tracking DUoM |
| 50226 | DUoM Purch Lot Ratio Tests | Ratio por lote desde Purchase Order (T-PURCH-LOT-*) |
| 50227 | DUoM Undo Rcpt Shpt Tests | Undo recepción/albarán con DUoM (signo correcto) |
| 50228 | DUoM Sign Mgt Tests | DUoM Sign Mgt — NormalizeILESign, ApplyMovementSign, etc. |
| 50229 | DUoM Doc Audit Tests | Auditoría propagación: DUoM Unit Cost/Price en históricos, signo ILE y VE en abonos |
| 50230 | DUoM Copy Item Tests | DUoM Copy Item Mgt. — Fixed, Variable, variantes, idempotencia (Issue 34) |

---

## Matriz de Cobertura

| Objeto de Producción | Tests unitarios | Tests integración | Cobertura | Observaciones |
|----------------------|----------------|-------------------|-----------|---------------|
| DUoM Conversion Mode (enum) | ✅ 50204 | — | **Completa** | Cubierto implícitamente en todos los tests que usan el enum |
| DUoM Item Setup (table 50100) | ✅ 50201, 50202, 50203 | — | **Completa** | ValidateSetup, GetOrCreate, cascade delete, triggers |
| DUoM Item Variant Setup (table 50101) | ✅ 50211 | — | **Completa** | Resolver y Purchase/Sales Line cubiertos; cascade delete cubierto en 50215 |
| Item.TableExt (cascade delete) | ✅ 50203 | — | **Completa** | |
| Item Variant.TableExt (cascade delete) | ✅ 50215 | — | **Completa** | OnDelete cubierto en 3 tests de cascade delete |
| DUoM Purchase Line (TableExt) | ✅ 50205 | ✅ 50209, 50210, 50214 | **Completa** | E2E cubre Fixed (50209, 50210) y Variable/AlwaysVariable (50214) |
| DUoM Sales Line (TableExt) | ✅ 50206 | ✅ 50209, 50210, 50214 | **Completa** | E2E cubre Fixed (50209, 50210) y Variable (50214) |
| DUoM Item Journal Line (TableExt) | ✅ 50207 | ✅ 50209 | **Completa** | |
| DUoM Item Ledger Entry (TableExt) | ✅ 50207 | ✅ 50209, 50229 | **Completa** | E2E cubre Fixed (50209) y Variable/AlwaysVariable (50214); signo abonos (50229 T-AUDIT-04/05) |
| DUoM Purch. Rcpt. Line (TableExt) | — | ✅ 50209, 50216 | **Completa** | Fixed (50209), DUoM Unit Cost propagado (50216 T05) |
| DUoM Sales Shipment Line (TableExt) | — | ✅ 50209, 50216 | **Completa** | Fixed (50209), DUoM Unit Price propagado (50216 T06) |
| DUoM Purch. Inv. Line (TableExt) | — | ✅ 50210, 50229 | **Completa** | DUoM Second Qty + Ratio (50210), DUoM Unit Cost (50229 T-AUDIT-01) |
| DUoM Purch. Cr. Memo Line (TableExt) | — | ✅ 50210, 50229 | **Completa** | DUoM Second Qty + Ratio (50210), DUoM Unit Cost (50229 T-AUDIT-02) |
| DUoM Sales Invoice Line (TableExt) | — | ✅ 50210, 50216 | **Completa** | DUoM Unit Price propagado (50216 T06) |
| DUoM Sales Cr.Memo Line (TableExt) | — | ✅ 50210, 50229 | **Completa** | DUoM Second Qty + Ratio (50210), DUoM Unit Price (50229 T-AUDIT-03) |
| DUoM Value Entry Ext (TableExt 50121) | — | ✅ 50216, 50229 | **Completa** | DUoM Second Qty tras compra (T07) y venta (T08); signo abonos (50229 T-AUDIT-06/07) |
| DUoM Tracking Spec Ext (TableExt 50122) | ✅ 50218 | ✅ 50218 (T05, T06) | **Completa** | T01–T04 unitarios, T05 E2E coherencia buffer→ILE, T06 modelo 1:N (Issue 22) |
| DUoM Reservation Entry Ext (TableExt 50123) | — | ✅ 50219, 50221 | **Completa** | Persistencia y recarga TrackingSpec ↔ Reservation Entry cubiertas en tests E2E de tracking; la tabla es fuente de verdad per-lote del documento vivo |
| DUoM Calc Engine (cu 50101) | ✅ 50204 | — | **Completa** | Todos los modos, casos límite, rounding |
| DUoM Purchase Subscribers (cu 50102) | ✅ 50205 | ✅ 50209, 50210, 50214 | **Completa** | Variable y AlwaysVariable cubiertos en 50214 |
| DUoM Sales Subscribers (cu 50103) | ✅ 50206 | ✅ 50209, 50210, 50214 | **Completa** | Variable cubierto en 50214 |
| DUoM Inventory Subscribers (cu 50104) | ✅ 50207 | ✅ 50209, 50216, 50229 | **Completa** | Subscriber ILE y Value Entry cubiertos; signo abonos verificado (50229) |
| DUoM Doc Transfer Helper (cu 50105) | ❌ Ninguno directo | ✅ 50209, 50210, 50216, 50229 | **Indirecta** | Cubierto vía E2E incluyendo los 6 flujos de copia; sin tests unitarios aislados (GAP P2) |
| DUoM UoM Helper (cu 50106) | ✅ 50213 | Indirecta | **Completa** | 7 tests unitarios directos (GAP P0-01 cerrado) |
| DUoM Setup Resolver (cu 50107) | ✅ 50211 | — | **Completa** | Jerarquía Item→Variante cubierta |
| DUoM Lot Ratio (table 50102) | ✅ 50217 | — | **Completa** | Validación Actual Ratio ≤ 0 cubierta; aplicación de ratio durante posting cubierta (T04–T10) |
| DUoM Lot Subscribers (cu 50108) | ✅ 50217 | — | **Completa** | Helper de ratio por lote cubierto en T04–T10/T12. `TryApplyLotRatioToILE` se conserva para tests de bajo nivel; el flujo productivo usa `Tracking Specification / Reservation Entry → IJL → ILE`. |
| DUoM Tracking Subscribers (cu 50109) | ✅ 50218 | ✅ 50218 (T05, T06) | **Completa** | T01–T04 unitarios (Lot No./Qty (Base) subscribers), T05 E2E, T06 modelo 1:N, T07 sin DUoM activo (Issue 22) |
| DUoM Copy Item Mgt. (cu 50128) | ✅ 50230 | — | **Completa** | T-COPYITEM-01..06: Fixed, Variable, variantes, omisión variante no existente, idempotencia, sin DUoM (Issue 34) |
| DUoM Item Setup Page | — | — | **N/A** | Las page extensions se testean vía UI/E2E; fuera de alcance unitario |
| DUoM Item UoM Subform (pageext) | ✅ 50212 | — | **Completa** | Condición de editabilidad Qty. Rounding Precision |
| DUoM permissionset 50100 | — | — | **N/A** | Verificado implícitamente por tests E2E con TestPermissions |

---

## Gaps Identificados

> Los gaps P0 y P1-01 han sido **cerrados** en PRs anteriores. Se documentan aquí
> para referencia histórica y como verificación de que los codeunits de test existen
> en el repositorio. El único gap abierto es P1-02 (reclasificado a P2).

### P0 — MVP Crítico (CERRADOS)

#### GAP-P0-01: DUoM UoM Helper sin tests unitarios directos ✅ CERRADO

**Descripción:** `codeunit 50106 "DUoM UoM Helper"` tiene dos métodos públicos
(`GetSecondUoMRoundingPrecision` y `GetRoundingPrecisionByUoMCode`) que son llamados
en todos los flujos de validación de cantidad donde interviene el redondeo de la UoM
secundaria. No existía ningún test unitario que verificara su comportamiento de forma aislada.

**Solución implementada:** `DUoMUoMHelperTests` (50213) — 7 tests unitarios que cubren
todos los escenarios de fallback y el camino feliz. `Access = Internal` → `Access = Public`
en el codeunit para habilitar la llamada directa desde el test app.

**Fichero:** `test/src/codeunit/DUoMUoMHelperTests.Codeunit.al` (ID: 50213)

---

#### GAP-P0-02: Tests de integración en modo Variable y AlwaysVariable ausentes ✅ CERRADO

**Descripción:** Todos los tests E2E existentes en `DUoM ILE Integration Tests` (50209) y
`DUoM Inv CrMemo Post Tests` (50210) utilizaban exclusivamente el modo `Fixed`. El modo
`Variable` y el modo `AlwaysVariable` no estaban cubiertos en el flujo completo de contabilización.

**Solución implementada:** `DUoM Variable Mode Post Tests` (50214) — 4 tests de integración:
compra Variable (ratio por defecto), compra Variable (ratio sobreescrito), compra AlwaysVariable
(valores manuales), venta Variable.

**Fichero:** `test/src/codeunit/DUoMVarModePostTests.Codeunit.al` (ID: 50214)

---

### P1 — Fase 2 (CERRADO)

#### GAP-P1-01: Borrado en cascada de DUoM Item Variant Setup sin test ✅ CERRADO

**Descripción:** `tableextension 50120 "DUoM Item Variant Ext"` implementa un trigger
`OnDelete` que borra en cascada el registro `DUoM Item Variant Setup` cuando se elimina
la `Item Variant` correspondiente. Esta lógica de integridad referencial no tenía test.

**Solución implementada:** `DUoM Variant Del Tests` (50215) — 3 tests que verifican:
eliminación con setup existente, eliminación sin setup (sin error), y que eliminar una
variante no afecta al setup de otra variante del mismo artículo.

**Fichero:** `test/src/codeunit/DUoMVariantDelTests.Codeunit.al` (ID: 50215)

---

#### GAP-P1-02: DUoM Doc Transfer Helper sin tests unitarios aislados

**Descripción:** `codeunit 50105 "DUoM Doc Transfer Helper"` centraliza la copia de campos
DUoM entre líneas de documento (6 métodos para los 6 flujos de contabilización). No tiene
tests unitarios propios; está cubierto de forma indirecta a través de los tests
de integración 50209, 50210 y 50216.

**Prioridad P2:** La cobertura indirecta vía E2E es sólida. Se mantiene como P2.

---

### P2 — Mejora Futura / Fuera de Alcance MVP

Los siguientes tests corresponden a funcionalidad aún no implementada (Phase 2 y posteriores):

| Test propuesto | Área funcional | Motivo de exclusión |
|----------------|----------------|---------------------|
| DualUoMWhseReceiptTest | WMS — Warehouse Receipt | Funcionalidad no implementada (Phase 2, Issue 14) |
| DualUoMWhsePutawayTest | WMS — Put-away | Funcionalidad no implementada (Phase 2, Issue 15) |
| DualUoMWhsePickTest | WMS — Pick | Funcionalidad no implementada (Phase 2, Issue 15) |
| DualUoMWhseShipmentTest | WMS — Shipment | Funcionalidad no implementada (Phase 2, Issue 14) |
| DualUoMWhseRegisterTest | WMS — Warehouse Entry | Funcionalidad no implementada (Phase 2) |
| DUoM Doc Transfer Helper unit tests | Doc Transfer Helper (aislado) | GAP P1-02 reclasificado a P2 |

> **Nota:** Los tests de coste/precio en doble UoM (DualUoMPurchInvoiceCostTest,
> DualUoMSalesPriceTest) y el test de Value Entry (DualUoMValueEntryTest) han sido
> **implementados** en `DUoM Cost Price Tests` (codeunit 50216, tests T01–T08).
> Los huecos adicionales identificados en la auditoría (DUoM Unit Cost en Purch. Inv. Line
> y Purch. Cr. Memo Line, DUoM Unit Price en Sales Cr. Memo Line, signo ILE/VE en abonos)
> han sido **cerrados** en `DUoM Doc Audit Tests` (codeunit 50229, tests T-AUDIT-01–07).
> Quedan retirados de esta tabla de gaps.

---

## Estado Actual del Test Suite

> **Última actualización:** Issue 34 — Copy Item DUoM — 2026-05-16

| Codeunit | ID | Tests | Estado |
|----------|----|-------|--------|
| DUoM Item Setup Tests | 50201 | 9 tests | ✅ |
| DUoM Item Card Opening Tests | 50202 | 4 tests | ✅ |
| DUoM Item Delete Tests | 50203 | 2 tests | ✅ |
| DUoM Calc Engine Tests | 50204 | 16 tests | ✅ |
| DUoM Purchase Tests | 50205 | 11 tests | ✅ |
| DUoM Sales Tests | 50206 | 10 tests | ✅ |
| DUoM Inventory Tests | 50207 | 6 tests | ✅ |
| DUoM Test Helpers | 50208 | — (helper) | ✅ |
| DUoM ILE Integration Tests | 50209 | 23 tests E2E | ✅ |
| DUoM Inv CrMemo Post Tests | 50210 | 5 tests E2E | ✅ |
| DUoM Variant Tests | 50211 | 15 tests | ✅ |
| DUoM Item UoM Round Tests | 50212 | 4 tests | ✅ |
| DUoM UoM Helper Tests | 50213 | 7 tests | ✅ |
| DUoM Variable Mode Post Tests | 50214 | 4 tests | ✅ |
| DUoM Variant Del Tests | 50215 | 3 tests | ✅ |
| DUoM Cost Price Tests | 50216 | 8 tests (T01–T08) | ✅ |
| DUoM Lot Ratio Tests | 50217 | 13 tests | ✅ |
| DUoM Item Tracking Tests | 50218 | 27 tests | ✅ |
| DUoM Purch Tracking Persist | 50219 | 16 tests E2E | ✅ |
| DUoM Tracking Coherence Tests | 50220 | 17 tests | ✅ |
| DUoM Purch Tracking Post Tests | 50221 | 5 tests E2E | ✅ |
| DUoM Purch Track Close Tests | 50222 | 3 tests | ✅ |
| DUoM Purch Track Val Tests | 50223 | 4 tests | ✅ |
| DUoM Pstd Item Trk. Tests | 50224 | 2 tests | ✅ |
| DUoM Purch Sync Tests | 50225 | 5 tests | ✅ |
| DUoM Purch Lot Ratio Tests | 50226 | 9 tests | ✅ |
| DUoM Undo Rcpt Shpt Tests | 50227 | 5 tests | ✅ |
| DUoM Sign Mgt Tests | 50228 | 23 tests | ✅ |
| DUoM Doc Audit Tests | 50229 | 7 tests (T-AUDIT-01–07) | ✅ |
| DUoM Copy Item Tests | 50230 | 6 tests (T-COPYITEM-01–06) | ✅ |
| **TOTAL** | | **269 tests** | |
