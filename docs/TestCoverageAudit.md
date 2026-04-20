# Auditoría de Cobertura de Tests — DualUoM-BC

> **Fecha de auditoría:** 2026-04-20
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
| codeunit 50101 | DUoM Calc Engine | Codeunit |
| codeunit 50102 | DUoM Purchase Subscribers | Codeunit |
| codeunit 50103 | DUoM Sales Subscribers | Codeunit |
| codeunit 50104 | DUoM Inventory Subscribers | Codeunit |
| codeunit 50105 | DUoM Doc Transfer Helper | Codeunit |
| codeunit 50106 | DUoM UoM Helper | Codeunit |
| codeunit 50107 | DUoM Setup Resolver | Codeunit |
| page 50100 | DUoM Item Setup | Page |
| page 50101 | DUoM Variant Setup List | Page |
| pageextension 50100–50111 | Varios (campos DUoM en forms) | PageExt |
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

---

## Matriz de Cobertura

| Objeto de Producción | Tests unitarios | Tests integración | Cobertura | Observaciones |
|----------------------|----------------|-------------------|-----------|---------------|
| DUoM Conversion Mode (enum) | ✅ 50204 | — | **Completa** | Cubierto implícitamente en todos los tests que usan el enum |
| DUoM Item Setup (table 50100) | ✅ 50201, 50202, 50203 | — | **Completa** | ValidateSetup, GetOrCreate, cascade delete, triggers |
| DUoM Item Variant Setup (table 50101) | Parcial 50211 | — | **Parcial** | Resolver y Purchase/Sales Line cubiertos; cascade delete NO cubierto |
| Item.TableExt (cascade delete) | ✅ 50203 | — | **Completa** | |
| Item Variant.TableExt (cascade delete) | ❌ Ninguno | — | **GAP P1** | OnDelete no tiene test propio |
| DUoM Purchase Line (TableExt) | ✅ 50205 | ✅ 50209, 50210 | **Completa** | E2E solo cubre modo Fixed |
| DUoM Sales Line (TableExt) | ✅ 50206 | ✅ 50209, 50210 | **Completa** | E2E solo cubre modo Fixed |
| DUoM Item Journal Line (TableExt) | ✅ 50207 | ✅ 50209 | **Completa** | |
| DUoM Item Ledger Entry (TableExt) | ✅ 50207 | ✅ 50209 | **Completa** | E2E solo cubre modo Fixed |
| DUoM Purch. Rcpt. Line (TableExt) | — | ✅ 50209 | **Completa** | Solo modo Fixed en E2E |
| DUoM Sales Shipment Line (TableExt) | — | ✅ 50209 | **Completa** | Solo modo Fixed en E2E |
| DUoM Purch. Inv. Line (TableExt) | — | ✅ 50210 | **Completa** | Solo modo Fixed en E2E |
| DUoM Purch. Cr. Memo Line (TableExt) | — | ✅ 50210 | **Completa** | Solo modo Fixed en E2E |
| DUoM Sales Invoice Line (TableExt) | — | ✅ 50210 | **Completa** | Solo modo Fixed en E2E |
| DUoM Sales Cr.Memo Line (TableExt) | — | ✅ 50210 | **Completa** | Solo modo Fixed en E2E |
| DUoM Calc Engine (cu 50101) | ✅ 50204 | — | **Completa** | Todos los modos, casos límite, rounding |
| DUoM Purchase Subscribers (cu 50102) | ✅ 50205 | ✅ 50209, 50210 | **Completa** | E2E solo cubre modo Fixed |
| DUoM Sales Subscribers (cu 50103) | ✅ 50206 | ✅ 50209, 50210 | **Completa** | E2E solo cubre modo Fixed |
| DUoM Inventory Subscribers (cu 50104) | ✅ 50207 | ✅ 50209 | **Buena** | Subscriber ILE testeado indirectamente |
| DUoM Doc Transfer Helper (cu 50105) | ❌ Ninguno directo | ✅ 50209, 50210 | **Indirecta** | Cubierto vía E2E; sin tests unitarios aislados |
| DUoM UoM Helper (cu 50106) | ❌ Ninguno | Indirecta | **GAP P0** | Ningún test unitario directo; usado en todos los flujos de rounding |
| DUoM Setup Resolver (cu 50107) | ✅ 50211 | — | **Completa** | Jerarquía Item→Variante cubierta |
| DUoM Item Setup Page | — | — | **N/A** | Las page extensions se testean vía UI/E2E; fuera de alcance unitario |
| DUoM Item UoM Subform (pageext) | ✅ 50212 | — | **Completa** | Condición de editabilidad Qty. Rounding Precision |
| DUoM permissionset 50100 | — | — | **N/A** | Verificado implícitamente por tests E2E con TestPermissions |

---

## Gaps Identificados

### P0 — MVP Crítico

#### GAP-P0-01: DUoM UoM Helper sin tests unitarios directos

**Descripción:** `codeunit 50106 "DUoM UoM Helper"` tiene dos métodos públicos
(`GetSecondUoMRoundingPrecision` y `GetRoundingPrecisionByUoMCode`) que son llamados
en todos los flujos de validación de cantidad donde interviene el redondeo de la UoM
secundaria. No existe ningún test unitario que verifique su comportamiento de forma aislada.

**Impacto:** Sin tests unitarios directos, una regresión en la lógica de fallback (cuando
el registro `Item Unit of Measure` no existe o el código de UoM es vacío) podría pasar
desapercibida hasta la ejecución de tests de integración, alargando el ciclo de detección.

**Solución propuesta:** Crear `DUoMUoMHelperTests` (50213) con 7 tests unitarios que cubran
todos los escenarios de fallback y el camino feliz. Cambiar `Access = Internal` → `Access = Public`
en el codeunit para habilitar la llamada directa desde el test app (patrón ya aplicado a
`DUoM Setup Resolver` en PR #102 y a `DUoM Calc Engine` desde su creación).

**Fichero propuesto:** `test/src/codeunit/DUoMUoMHelperTests.Codeunit.al` (ID: 50213)

---

#### GAP-P0-02: Tests de integración en modo Variable y AlwaysVariable ausentes

**Descripción:** Todos los tests E2E existentes en `DUoM ILE Integration Tests` (50209) y
`DUoM Inv CrMemo Post Tests` (50210) utilizan exclusivamente el modo `Fixed`. El modo
`Variable` (con ratio por defecto del artículo y con ratio sobreescrito en línea) y el modo
`AlwaysVariable` (con valores introducidos manualmente) no están cubiertos en el flujo
completo de contabilización.

**Impacto:** Un fallo en la copia de campos DUoM durante la contabilización en modos
Variable o AlwaysVariable no sería detectado por el test suite actual. Estos modos son
críticos para el escenario de negocio principal (lechuga variable por lote).

**Solución propuesta:** Crear `DUoM Variable Mode Post Tests` (50214) con 4 tests de
integración: compra Variable (ratio por defecto), compra Variable (ratio sobreescrito),
compra AlwaysVariable (valores manuales), venta Variable.

**Fichero propuesto:** `test/src/codeunit/DUoMVarModePostTests.Codeunit.al` (ID: 50214)

---

### P1 — Fase 2

#### GAP-P1-01: Borrado en cascada de DUoM Item Variant Setup sin test

**Descripción:** `tableextension 50120 "DUoM Item Variant Ext"` implementa un trigger
`OnDelete` que borra en cascada el registro `DUoM Item Variant Setup` cuando se elimina
la `Item Variant` correspondiente. Esta lógica de integridad referencial no tiene ningún
test que la verifique.

**Impacto:** Un fallo en el cascade delete dejaría registros huérfanos en
`DUoM Item Variant Setup`, lo que podría provocar comportamiento inesperado al resolver
la jerarquía Item→Variante para artículos cuya variante ya no existe.

**Solución propuesta:** Crear `DUoM Variant Del Tests` (50215) con 3 tests que verifiquen:
eliminación con setup existente, eliminación sin setup (sin error), y que eliminar una
variante no afecta al setup de otra variante del mismo artículo.

**Fichero propuesto:** `test/src/codeunit/DUoMVariantDelTests.Codeunit.al` (ID: 50215)

---

#### GAP-P1-02: DUoM Doc Transfer Helper sin tests unitarios aislados

**Descripción:** `codeunit 50105 "DUoM Doc Transfer Helper"` centraliza la copia de campos
DUoM entre líneas de documento (6 métodos para los 6 flujos de contabilización). No tiene
tests unitarios propios; está cubierto únicamente de forma indirecta a través de los tests
de integración 50209 y 50210.

**Impacto:** Los tests de integración verifican el resultado final pero no cubren casos
límite del helper (p. ej., `"skip when both zero"` — el comportamiento de no copiar cuando
ambos campos son cero). Un cambio en la lógica de copia podría no ser detectado hasta
los tests E2E.

**Solución propuesta:** Cambiar `Access = Internal` → `Access = Public` en codeunit 50105
y crear `DUoM Doc Transfer Tests` (50216) con tests unitarios en memoria para los 6 métodos.

**Prioridad actualizada a P2:** Dado que la cobertura indirecta via E2E es sólida, se
reclasifica como P2 para priorizar los gaps con mayor riesgo de regresión no detectada.

---

### P2 — Mejora Futura / Fuera de Alcance MVP

Los siguientes tests corresponden a funcionalidad aún no implementada (Phase 2 y posteriores):

| Test propuesto | Área funcional | Motivo de exclusión del PR |
|----------------|----------------|---------------------------|
| DualUoMLotRatioAssignTest | Item Tracking / Lotes | Funcionalidad no implementada (Phase 2) |
| DualUoMLotRatioRecallTest | Item Tracking / Lotes | Funcionalidad no implementada (Phase 2) |
| DualUoMLotRatioMismatchTest | Item Tracking / Lotes | Funcionalidad no implementada (Phase 2) |
| DualUoMPurchInvoiceCostTest | Coste en doble UoM | Funcionalidad no implementada |
| DualUoMSalesPriceTest | Precio en doble UoM | Funcionalidad no implementada |
| DualUoMWhseReceiptTest | WMS — Warehouse Receipt | Funcionalidad no implementada (Phase 2) |
| DualUoMWhsePutawayTest | WMS — Put-away | Funcionalidad no implementada (Phase 2) |
| DualUoMWhsePickTest | WMS — Pick | Funcionalidad no implementada (Phase 2) |
| DualUoMWhseShipmentTest | WMS — Shipment | Funcionalidad no implementada (Phase 2) |
| DualUoMWhseRegisterTest | WMS — Warehouse Entry | Funcionalidad no implementada (Phase 2) |
| DualUoMValueEntryTest | Value Entry | Funcionalidad no implementada |

---

## Entregables de este PR

| Fichero | Tipo | Prioridad |
|---------|------|-----------|
| `docs/TestCoverageAudit.md` | Documentación | — |
| `app/src/codeunit/DUoMUoMHelper.Codeunit.al` | Cambio Access=Public | P0 |
| `test/src/codeunit/DUoMUoMHelperTests.Codeunit.al` (50213) | Tests unitarios nuevos | P0 |
| `test/src/codeunit/DUoMVarModePostTests.Codeunit.al` (50214) | Tests integración nuevos | P0 |
| `test/src/codeunit/DUoMVariantDelTests.Codeunit.al` (50215) | Tests unitarios nuevos | P1 |

---

## Actualización de la Documentación

Los cambios de este PR actualizan:
- `docs/TestCoverageAudit.md` (nuevo)
- `docs/06-backlog.md` (nueva entrada para la auditoría TDD)
