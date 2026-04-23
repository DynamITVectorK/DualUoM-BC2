# DualUoM-BC — Estimación de Esfuerzo y Valoración Económica

> **Fecha de elaboración:** Abril 2026  
> **Última actualización:** Abril 2026 — sincronizado con estado real del repositorio  
> **Estado del repositorio analizado:** BC 27 / runtime 15 · Phase 1 + Phase 2 Issues 11b, 12, 13 + Auditoría TDD + BUG-01 completados  
> **Fee de referencia:** 500 EUR / jornada  
> **Destinatario:** Uso comercial — presentación a cliente

---

## 1. Resumen Ejecutivo

### ¿Qué resuelve esta solución?

**DualUoM-BC** es una extensión PTE (Per-Tenant Extension) para Microsoft Dynamics 365 Business Central SaaS que permite gestionar artículos con **dos unidades de medida independientes** a lo largo de todo el ciclo operativo: compra, venta, inventario y almacén.

El caso de negocio más frecuente es el del sector alimentario, químico, agrícola o metalúrgico, donde un artículo se compra por kilogramos, pero se recibe, almacena o vende por piezas (o viceversa), y el ratio de conversión puede variar por lote.

**Business Central estándar no puede soportar este escenario** de forma nativa: su campo alternativo de UoM solo admite un ratio fijo a nivel de artículo. DualUoM-BC añade, sin modificar el estándar:

- Un campo de segunda cantidad en todas las líneas de documento relevantes.
- Un ratio de conversión almacenado por línea y propagado a movimientos contables.
- Tres modos de conversión: fijo, variable (con ratio por defecto ajustable) y siempre-variable (ratio manual por línea).
- Precisión de redondeo aplicada a la segunda UoM (unidades discretas vs. continuas).
- Trazabilidad completa hasta los históricos de facturas y albaranes.

### ¿Por qué aporta valor?

| Requisito | BC Estándar | DualUoM-BC |
|-----------|-------------|------------|
| Ratio fijo entre dos UoM | ✅ Tabla Item UoM | ✅ Reutilizado |
| Ratio variable por transacción | ❌ | ✅ Campo en línea |
| Siempre-variable (ratio nunca fijo) | ❌ | ✅ Modo AlwaysVariable |
| Soporte de variantes de artículo | ❌ | ✅ Override por variante |
| Ratio real por lote | ❌ | ✅ Tabla `DUoM Lot Ratio` |
| Precio/coste en segunda UoM | ❌ | ✅ `DUoM Unit Price` / `DUoM Unit Cost` |
| Segunda cantidad en líneas de documento | ❌ | ✅ Table extensions |
| Segunda cantidad en movimientos contables | ❌ | ✅ Table extensions ILE + Value Entry |
| Históricos completos con segunda cantidad | ❌ | ✅ 10 table extensions |
| Almacén avanzado (put-away & pick) | ❌ | 🔜 Phase 2 |

### Estado actual del proyecto

El proyecto ha completado **la Fase 1 (MVP) íntegra** más los Issues 11b, 12 y 13 de la Fase 2, junto con la Auditoría TDD y la corrección BUG-01. Existe código AL funcional, una suite de tests automatizados con **114 procedimientos `[Test]`** distribuidos en 16 codeunits de test, y documentación técnica y funcional completa.

La extensión está actualmente en un **estado demostrable y maduro** para la funcionalidad base (compras, ventas, inventario, propagación a históricos, coste/precio en doble UoM y ratio real por lote). Las funcionalidades de almacén avanzado, devoluciones, inventario físico e informes están diseñadas en el backlog pero no implementadas.

### Grado de madurez

| Área | Madurez |
|------|---------|
| Motor de cálculo y configuración por artículo | 🟢 Producción |
| Soporte de variantes de artículo (Item Variants) | 🟢 Producción |
| Compras (pedido, recepción, factura, abono) | 🟢 Producción |
| Ventas (pedido, albarán, factura, abono) | 🟢 Producción |
| Inventario (diario de productos, ILE) | 🟢 Producción |
| Históricos completos (10 table extensions) | 🟢 Producción |
| Precisión de redondeo por UoM | 🟢 Producción |
| Coste/precio en doble UoM (Unit Cost / Unit Price) | 🟢 Producción |
| Ratio real por lote (`DUoM Lot Ratio`) | 🟢 Producción |
| Localización en-US / es-ES | 🟢 Producción |
| Suite de tests automatizados | 🟢 114 tests (16 codeunits) |
| Almacén básico (Warehouse Receipt/Shipment) | 🔴 Pendiente (Phase 2) |
| Almacén dirigido (Put-Away & Pick) | 🔴 Pendiente (Phase 2) |
| Devoluciones (Purchase/Sales Returns) | 🔴 Pendiente (Phase 2) |
| Inventario físico (Phys. Inventory Ledger Entry) | 🔴 Pendiente (Phase 2) |
| Informes (Report Extensions) | 🔴 Pendiente (Phase 2) |

---

## 2. Alcance Funcional del Producto

### 2.1 Qué cubre actualmente

- **Setup por artículo:** activación DUoM, segunda UoM, modo de conversión, ratio fijo.
- **Setup por variante de artículo:** override opcional por `Item Variant` (Second UoM Code, Conversion Mode, Fixed Ratio).
- **Resolución jerárquica:** `Item Setup` → `Variant Override` → `Lot Ratio`, centralizada en `DUoM Setup Resolver`.
- **Pedidos de compra:** campos Segunda Qty, Ratio y Coste Unitario DUoM visibles y editables en líneas.
- **Recepciones de compra:** segunda cantidad y coste propagados al registrar.
- **Facturas y abonos de compra registrados:** segunda cantidad y coste trazados en histórico.
- **Pedidos de venta:** campos Segunda Qty, Ratio y Precio Unitario DUoM en líneas.
- **Albaranes de venta:** segunda cantidad y precio propagados al registrar.
- **Facturas y abonos de venta registrados:** segunda cantidad y precio trazados en histórico.
- **Diario de productos:** segunda cantidad en líneas y propagación al ILE.
- **Movimiento de producto (ILE):** segunda cantidad y ratio inmutables tras contabilización.
- **Value Entry:** segunda cantidad propagada para trazabilidad contable completa.
- **Ratio real por lote:** tabla `DUoM Lot Ratio` con ratio medido por lote; al asignar lote en `Item Journal Line` se aplica automáticamente; en contabilización con N lotes cada ILE recibe su parte proporcional con override por ratio de lote.
- **Precisión de redondeo:** `DUoM Second Qty` se redondea al paso mínimo de la UoM secundaria.
- **Localización completa** en inglés y español (todos los textos de UI traducidos).
- **Subformulario UoM editable:** `Qty. Rounding Precision` editable en `Item Units of Measure` cuando no existen movimientos para esa UoM concreta del artículo.

### 2.2 Qué cubrirá con la siguiente fase (Phase 2 pendiente)

- **Almacén básico:** extensión de `Warehouse Receipt Line` y `Warehouse Shipment Line`.
- **Almacén dirigido (WMS):** extensión de `Warehouse Activity Line` (put-away y pick).
- **Devoluciones:** `Purchase Return Order`, `Sales Return Order`, históricos de devolución.
- **Inventario físico:** `Phys. Inventory Ledger Entry` con segunda cantidad.
- **Informes:** extensión de informes estándar de recepción, albarán y valoración de inventario.

### 2.3 Qué queda fuera de alcance (permanente)

- Producción (Production Orders, Output Journal, Routing).
- Proyectos (Job Planning Lines, Job Ledger Entries).
- Gestión de Servicio (Service Orders, Service Items).
- Integración con básculas u hardware externo.
- Intercompany con segunda cantidad.

---

## 3. Estado Actual del Desarrollo

### 3.1 Funcionalidades implementadas (evidencia en código)

| Área | Objetos AL | Tests |
|------|-----------|-------|
| Enum `DUoM Conversion Mode` (50100) | `DUoMConversionMode.Enum.al` | — |
| Tabla `DUoM Item Setup` (50100) | `DUoMItemSetup.Table.al` (160 líneas) | `DUoMItemSetupTests` (9 tests), `DUoMItemCardOpeningTests` (4 tests), `DUoMItemDeleteTests` (2 tests) |
| Tabla `DUoM Item Variant Setup` (50101) | `DUoMItemVariantSetup.Table.al` (106 líneas) | `DUoMVariantTests` (15 tests), `DUoMVariantDelTests` (3 tests) |
| Tabla `DUoM Lot Ratio` (50102) | `DUoMLotRatio.Table.al` (58 líneas) | `DUoMLotRatioTests` (8 tests) |
| Motor de cálculo `DUoM Calc Engine` (50101) | `DUoMCalcEngine.Codeunit.al` (83 líneas) | `DUoMCalcEngineTests` (16 tests) |
| Helper de UoM `DUoM UoM Helper` (50106) | `DUoMUoMHelper.Codeunit.al` (54 líneas) | `DUoMUoMHelperTests` (7 tests) |
| Resolver jerárquico `DUoM Setup Resolver` (50107) | `DUoMSetupResolver.Codeunit.al` (64 líneas) | Cubierto en Variant Tests y posting tests |
| Extensión `Purchase Line` (50110) | `DUoMPurchaseLine.TableExt.al` (93 líneas) | `DUoMPurchaseTests` (9 tests), `DUoMVarModePostTests` (4 tests) |
| Extensión `Sales Line` (50111) | `DUoMSalesLine.TableExt.al` (92 líneas) | `DUoMSalesTests` (8 tests), `DUoMVarModePostTests` |
| Extensión `Item Journal Line` (50112) | `DUoMItemJournalLine.TableExt.al` (57 líneas) | `DUoMInventoryTests` (6 tests) |
| Extensión `Item Ledger Entry` (50113) | `DUoMItemLedgerEntry.TableExt.al` (24 líneas) | `DUoMILEIntegrationTests` (6 tests E2E) |
| Extensión `Value Entry` (50121) | `DUoMValueEntry.TableExt.al` (19 líneas) | `DUoMCostPriceTests` (8 tests) |
| Extensiones históricos compra (50114, 50116, 50117) | 3 table extensions | `DUoMILEIntegrationTests`, `DUoMInvCrMemoPostTests` |
| Extensiones históricos venta (50115, 50118, 50119) | 3 table extensions | `DUoMILEIntegrationTests`, `DUoMInvCrMemoPostTests` (5 tests E2E) |
| Ext. cascada `Item Variant` (50120) | `DUoMItemVariant.TableExt.al` (14 líneas) | `DUoMVariantDelTests` (3 tests) |
| Suscriptores compra (50102) | `DUoMPurchaseSubscribers.Codeunit.al` (100 líneas) | Cubierto en DUoMPurchaseTests |
| Suscriptores venta (50103) | `DUoMSalesSubscribers.Codeunit.al` (100 líneas) | Cubierto en DUoMSalesTests |
| Suscriptores inventario/ILE/Value Entry (50104) | `DUoMInventorySubscribers.Codeunit.al` (281 líneas) | Cubierto en múltiples codeunits de test |
| Suscriptores lote/IJL (50108) | `DUoMLotSubscribers.Codeunit.al` (101 líneas) | `DUoMLotRatioTests` |
| Helper de copia entre líneas (50105) | `DUoMDocTransferHelper.Codeunit.al` (107 líneas) | Cubierto en tests E2E |
| Pages (3: setup artículo, variantes, lotes) | IDs 50100–50102 | — |
| Page extensions (12 extensiones de página) | IDs 50100–50111 | `DUoMItemUoMRoundTests` (4 tests) |
| Permission sets app y test | `DUoMAll.PermissionSet.al`, `DUoMTestAll.PermissionSet.al` | — |
| Localización completa | 109 `trans-unit` en en-US y es-ES XLF | — |
| Manual de usuario | `docs/manual-usuario.md` | — |

**Total objetos AL de producción:** 1 enum, 3 tablas, 13 table extensions, 8 codeunits, 3 páginas, 12 page extensions, 1 permission set = **41 objetos**  
**Total objetos AL de test:** 16 codeunits de test + 1 helper + 1 permission set = **18 objetos**  
**Total líneas AL (producción):** ~2.577 líneas  
**Total líneas AL (test):** ~4.425 líneas  
**Total tests `[Test]`:** 114 procedimientos de test

### 3.2 Deuda técnica y consolidación pendiente

| Ref. | Hallazgo | Impacto | Estado |
|------|---------|---------|--------|
| General | `useCompilerFolder=true` en CI impide ejecución de tests en Actions (solo compila) | Tests no se ejecutan automáticamente en CI → riesgo de regresión silenciosa | ⚠️ Pendiente — coste CI si se activa Docker runner |
| Auditoría MVP | Huecos TDD: modos Variable y AlwaysVariable en posting completo | Cobertura de escenarios críticos | ✅ Cerrado — `DUoMVarModePostTests` (50214) |
| Auditoría MVP | Tests `OnValidate DUoM Ratio` (recálculo al cambiar ratio en línea) | Riesgo de regresión si se modifica la lógica | ✅ Cerrado — cubierto en `DUoMPurchaseTests`, `DUoMSalesTests` y `DUoMVarModePostTests` |
| Auditoría MVP | `Caption` ausente en campos de table extensions | UI en inglés sin XLF aplicado | ✅ Cerrado — captions añadidos en auditoría MVP |
| Auditoría MVP | Page extension `Item Journal` ausente | Sin visibilidad de campos DUoM en diario | ✅ Cerrado — `DUoMItemJournalExt.PageExt.al` (50103) creado |
| BUG-01 | `Qty. Rounding Precision` no editable en subformulario UoM | No se puede configurar precisión de redondeo desde la UI | ✅ Cerrado — `DUoMItemUoMSubform.PageExt.al` (50110) |

### 3.3 Funcionalidades pendientes (Phase 2 continuación)

| Issue | Bloque | Estado |
|-------|--------|--------|
| 14 | Almacén básico (`Warehouse Receipt Line`, `Warehouse Shipment Line`) | ❌ No implementado |
| 15 | Almacén dirigido WMS (`Warehouse Activity Line`, Put-Away & Pick) | ❌ No implementado |
| 16 | Devoluciones (Purchase/Sales Returns, Return Shipment/Receipt) | ❌ No implementado |
| 17 | Inventario físico (`Phys. Inventory Ledger Entry`) | ❌ No implementado |
| 18 | Informes (Report Extensions) | ❌ No implementado |

---

## 4. Estimación de Esfuerzo

La estimación es **bottom-up** por bloques funcionales. Una jornada equivale a 8 horas de trabajo efectivo. Se asume un perfil de consultor/desarrollador Business Central Senior con experiencia en extensiones AL SaaS.

### 4.1 Trabajo ya realizado (valoración del esfuerzo invertido)

> Esta sección no implica facturación retroactiva. Sirve para cuantificar el valor ya materializado en el proyecto y apoyar la conversación comercial con el cliente.

| Bloque | Descripción | Jornadas |
|--------|-------------|----------|
| Issue 1 — Gobierno del proyecto | Documentación base, visión, alcance, arquitectura, testing, backlog, CI/CD | 3,0 |
| Issue 2 — Motor de cálculo | `DUoM Calc Engine`, enum, 16 tests unitarios | 2,0 |
| Issue 3 — Setup por artículo | Tabla `DUoM Item Setup`, página, extensión `Item`, cascade delete, 15 tests | 3,0 |
| Issue 4 — Líneas de compra | Table ext `Purchase Line`, page ext subformulario, suscriptor, 9 tests | 2,0 |
| Issue 5 — Posting compra → ILE | Propagación `Purchase Line` → `Item Journal Line` → ILE, sin Modify() | 2,5 |
| Issue 6 — Líneas de venta | Table ext `Sales Line`, page ext, suscriptor, 8 tests | 2,0 |
| Issue 7 — Posting venta → ILE | Propagación `Sales Line` → ILE | 1,5 |
| Issue 8 — Diario de productos | Table ext `Item Journal Line`, page ext, suscriptor, 6 tests | 2,0 |
| Issue 9 — Históricos rcpt/ship | Table extensions + suscriptores `OnAfterInitFrom*`, page extensions, 6 tests E2E | 3,0 |
| Issue 10 — Históricos fact/abono | 4 table extensions, 4 suscriptores, 4 page extensions, 5 tests E2E | 3,5 |
| Issue 11 — Precisión de redondeo | `ComputeSecondQtyRounded`, `DUoM UoM Helper`, triggers OnValidate, tests | 2,5 |
| Issue 11b — Item Variants | `DUoM Item Variant Setup`, `DUoM Setup Resolver`, jerarquía item→variante, página, 15 tests | 3,5 |
| Deuda técnica (Auditoría MVP + TDD + BUG-01) | Captions, page ext Item Journal, tests Variable mode, tests UoM Helper, Item UoM Subform editable | 3,0 |
| Issue 12 — Coste/precio DUoM | `DUoM Unit Price` en venta, `DUoM Unit Cost` en compra, derivación, `Value Entry` ext, 8 tests | 5,0 |
| Issue 13 — Ratio por lote | `DUoM Lot Subscribers`, recálculo proporcional en ILE, 8 tests, corrección multi-lote | 4,0 |
| Localización en-US / es-ES | 109 `trans-unit` en dos XLF, captions, tooltips, labels con Comment | 2,0 |
| Manual de usuario | Documento funcional completo para usuario de negocio | 1,5 |
| Hardening SaaS y auditoría | Correcciones de firma de eventos BC 27, permisos IndirectInsert, CI cost decisions | 2,5 |
| **TOTAL YA REALIZADO** | | **48,0 jornadas** |

### 4.2 Trabajo pendiente para cerrar una versión vendible (Phase 2 continuación)

| Bloque | Descripción | Jornadas | Observaciones |
|--------|-------------|----------|---------------|
| Issue 14 — Almacén básico | `Warehouse Receipt/Shipment Line` ext, suscriptores, page exts, tests E2E | 5,0 | Verificar eventos BC 27; complejidad moderada-alta |
| Issue 17 — Inventario físico | `Phys. Inventory Ledger Entry` ext, lógica journal, tests | 2,0 | Relativamente independiente |
| Soporte deploy + release | Packaging .app, documentación de instalación, permissionsets finales, test de smoke en tenant real | 2,0 | Necesario antes de cliente |
| **TOTAL PENDIENTE VENDIBLE** | | **9,0 jornadas** | |

### 4.3 Trabajo opcional / futuras fases

| Bloque | Descripción | Jornadas | Observaciones |
|--------|-------------|----------|---------------|
| Issue 15 — WMS Directed Pick | `Warehouse Activity Line` ext, put-away & pick, suscriptores, tests | 6,0 | Alta complejidad; requiere Issue 14 |
| Issue 16 — Devoluciones | `Return Shipment/Receipt Line`, suscriptores, page exts, tests | 4,0 | Moderada; requiere Issues 9–11 |
| Issue 18 — Informes | Report extensions en recepciones, albaranes, valoración inventario | 3,0 | Complejidad baja-media; valor comercial alto |
| Integración Item Tracking avanzado | Multi-lote en línea, trazabilidad por serial number | 4,0 | Solo si el cliente usa tracking por serie |
| Mejoras UX | Factoid box en Item Card, filtros, FlowFields para totales | 2,0 | Diferenciador comercial |
| Performance & hardening | Optimización de queries, índices en table extensions, upgrade codeunit | 2,0 | Recomendable antes de go-live masivo |
| Documentación avanzada | Guía de partner, documentación de API pública, changelog formal | 1,5 | Útil para distribución como ISV |
| **TOTAL OPCIONALES** | | **22,5 jornadas** | |

---

## 5. Valoración Económica

**Fee por jornada: 500 EUR**

### 5.1 Resumen de bloques

| Bloque | Jornadas | Importe |
|--------|----------|---------|
| A. Trabajo ya realizado | 48,0 | 24.000 EUR |
| B. Cierre de versión vendible | 9,0 | 4.500 EUR |
| C. Opcionales / fases futuras | 22,5 | 11.250 EUR |
| **TOTAL GLOBAL** | **79,5** | **39.750 EUR** |

### 5.2 Desglose detallado

| # | Bloque | Jornadas | 500 EUR/j | Subtotal |
|---|--------|----------|-----------|----------|
| 1 | Gobierno del proyecto y documentación base | 3,0 | 500 | 1.500 EUR |
| 2 | Motor de cálculo y enum | 2,0 | 500 | 1.000 EUR |
| 3 | Setup por artículo (tabla, página, tests) | 3,0 | 500 | 1.500 EUR |
| 4 | Líneas de compra (table/page ext + tests) | 2,0 | 500 | 1.000 EUR |
| 5 | Posting compra → ILE | 2,5 | 500 | 1.250 EUR |
| 6 | Líneas de venta (table/page ext + tests) | 2,0 | 500 | 1.000 EUR |
| 7 | Posting venta → ILE | 1,5 | 500 | 750 EUR |
| 8 | Diario de productos | 2,0 | 500 | 1.000 EUR |
| 9 | Históricos rcpt/ship (E2E) | 3,0 | 500 | 1.500 EUR |
| 10 | Históricos fact/abono (E2E) | 3,5 | 500 | 1.750 EUR |
| 11 | Precisión de redondeo | 2,5 | 500 | 1.250 EUR |
| 12 | Item Variants (jerarquía item→variante) | 3,5 | 500 | 1.750 EUR |
| 13 | Deuda técnica (Auditoría MVP + TDD + BUG-01) | 3,0 | 500 | 1.500 EUR |
| 14 | Coste/precio en doble UoM | 5,0 | 500 | 2.500 EUR |
| 15 | Ratio real por lote (Issue 13) | 4,0 | 500 | 2.000 EUR |
| 16 | Localización en-US / es-ES | 2,0 | 500 | 1.000 EUR |
| 17 | Manual de usuario | 1,5 | 500 | 750 EUR |
| 18 | Hardening SaaS y auditoría | 2,5 | 500 | 1.250 EUR |
| **Subtotal — Realizado** | | **48,0** | | **24.000 EUR** |
| 19 | Almacén básico (Issue 14) | 5,0 | 500 | 2.500 EUR |
| 20 | Inventario físico (Issue 17) | 2,0 | 500 | 1.000 EUR |
| 21 | Soporte deploy y release | 2,0 | 500 | 1.000 EUR |
| **Subtotal — Cierre vendible** | | **9,0** | | **4.500 EUR** |
| 22 | WMS Directed Put-Away & Pick | 6,0 | 500 | 3.000 EUR |
| 23 | Devoluciones purchase/sales | 4,0 | 500 | 2.000 EUR |
| 24 | Informes (report extensions) | 3,0 | 500 | 1.500 EUR |
| 25 | Item Tracking avanzado | 4,0 | 500 | 2.000 EUR |
| 26 | Mejoras UX | 2,0 | 500 | 1.000 EUR |
| 27 | Performance & hardening | 2,0 | 500 | 1.000 EUR |
| 28 | Documentación avanzada (ISV) | 1,5 | 500 | 750 EUR |
| **Subtotal — Opcionales** | | **22,5** | | **11.250 EUR** |
| **TOTAL GLOBAL** | | **79,5** | | **39.750 EUR** |

---

## 6. Escenarios de Contratación

### Escenario A — Base actual + cierre mínimo vendible

**Incluye:**
- Todo lo ya construido (Issues 1–13 + 11b completados): motor de cálculo, setup por artículo y variante, compras, ventas, inventario, históricos completos, precisión de redondeo, coste/precio en doble UoM, ratio por lote, localización.
- Soporte de deploy y entrega del `.app` al cliente.

**Excluye:** almacén, devoluciones, informes, WMS avanzado.

| Concepto | Jornadas | Importe |
|----------|----------|---------|
| Trabajo ya realizado | 48,0 j | *(inversión ya materializada)* |
| Cierre mínimo vendible (deploy + hardening) | 2,0 j | **1.000 EUR** |
| **Total a contratar** | **2,0 j** | **1.000 EUR** |

**Para qué tipo de cliente encaja:**
Empresas que compran y venden artículos con doble UoM sin procesos de almacén avanzado. Ideal como primera implantación para validar el valor y el fit funcional antes de comprometer una inversión mayor. Con Issues 12 y 13 ya completados, este escenario incluye trazabilidad de ratio por lote y coste/precio en segunda UoM.

---

### Escenario B — Versión recomendada (Phase 2 core completa)

**Incluye:**
- Todo el Escenario A.
- Almacén básico (Issue 14): `Warehouse Receipt` y `Shipment Line` con segunda cantidad.
- Inventario físico (Issue 17).
- Informes estándar con segunda cantidad (Issue 18).

**Excluye:** WMS dirigido (put-away & pick), devoluciones avanzadas, Item Tracking multi-lote.

| Concepto | Jornadas | Importe |
|----------|----------|---------|
| Trabajo ya realizado | 48,0 j | *(inversión ya materializada)* |
| Cierre vendible mínimo (Escenario A) | 2,0 j | 1.000 EUR |
| Almacén básico (Issue 14) | 5,0 j | 2.500 EUR |
| Inventario físico (Issue 17) | 2,0 j | 1.000 EUR |
| Informes (Issue 18) | 3,0 j | 1.500 EUR |
| **Total a contratar** | **12,0 j** | **6.000 EUR** |

**Para qué tipo de cliente encaja:**
Empresas con almacén básico y necesidad de trazabilidad por lote. Sectores típicos: alimentario, químico, agrícola. Esta versión cubre el 80% de los casos de uso reales y es la **recomendación principal** para la primera implantación comercial.

---

### Escenario C — Versión ampliada / avanzada (Phase 2 + Phase 3)

**Incluye:**
- Todo el Escenario B.
- WMS dirigido: put-away y pick con segunda cantidad (Issue 15).
- Devoluciones de compra y venta con segunda cantidad (Issue 16).
- Mejoras UX (factoid box, FlowFields, filtros avanzados).
- Performance hardening y upgrade codeunit.
- Documentación avanzada para distribución como ISV.

| Concepto | Jornadas | Importe |
|----------|----------|---------|
| Trabajo ya realizado | 48,0 j | *(inversión ya materializada)* |
| Escenario B (a contratar) | 12,0 j | 6.000 EUR |
| WMS Directed (Issue 15) | 6,0 j | 3.000 EUR |
| Devoluciones (Issue 16) | 4,0 j | 2.000 EUR |
| Mejoras UX | 2,0 j | 1.000 EUR |
| Performance & hardening | 2,0 j | 1.000 EUR |
| Documentación ISV | 1,5 j | 750 EUR |
| **Total a contratar** | **27,5 j** | **13.750 EUR** |

**Para qué tipo de cliente encaja:**
Empresas con WMS avanzado (Directed Put-Away & Pick activo en BC), alto volumen de movimientos de almacén, o ISV/partner que quieran distribuir la extensión como producto propio en AppSource.

---

## 7. Supuestos

1. **Una jornada = 8 horas** de trabajo efectivo de un consultor/desarrollador BC Senior.
2. **BC 27 / runtime 15 SaaS** como plataforma de destino. Si el cliente usa una versión anterior, los eventos y firmas deben re-verificarse.
3. **El trabajo ya realizado** (48,0 j) representa el valor acumulado en el repositorio. No se incluye en ninguna facturación futura salvo que se contemple en el modelo comercial del partner.
4. **Entorno de desarrollo y test** disponible para el developer (tenant BC sandbox o Business Central container Windows 2022). Si el cliente no lo provee, añadir ~1 j para configuración.
5. **No se incluye** consultoría funcional de fit-gap con el cliente, formación a usuarios, ni implantación en producción más allá del packaging y publicación del `.app`.
6. **Localización:** el alcance actual cubre en-US y es-ES. Idiomas adicionales requieren ~0,5 j por idioma.
7. **Tests TDD obligatorios** para cada nuevo bloque: el coste de testing ya está incluido en las estimaciones de cada issue.
8. **CI/CD con AL-Go:** la configuración actual usa `workflow_dispatch` manual. Si el cliente requiere CI automático en PR (push/PR triggers con runner Docker), añadir ~1 j de configuración y el coste de minutos de GitHub Actions.
9. **Item Tracking avanzado** (multi-lote en línea, serial numbers) no está estimado en detalle. Si el cliente usa Item Tracking con serial numbers, el Issue 13 puede requerir +1–2 j adicionales.
10. **WMS avanzado** (Escenario C) es la parte más incierta. La estimación de Issue 15 asume una instalación BC estándar con Directed Put-Away & Pick. Configuraciones no estándar pueden aumentar el esfuerzo.

---

## 8. Riesgos y Condicionantes

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------|---------|------------|
| **Cambio de firma de eventos BC 27** entre minor releases | Baja | Alto | Verificar cada suscriptor contra `microsoft/ALAppExtensions` antes de implementar. Ya documentado en el proyecto como norma obligatoria. |
| **WMS Directed Put-Away & Pick** — alta complejidad de flujo | Alta | Alto | Reservar tiempo adicional (+2 j contingencia) si el cliente tiene un almacén complejo. Realizar fit-gap antes de estimar en firme. |
| **Posting de devoluciones** — eventos de BC 27 para return flows pueden diferir | Media | Medio | Verificar nombres y firmas de eventos en BC Symbol Reference antes del Issue 16. |
| **CI sin ejecución automática de tests** — `useCompilerFolder=true` impide Docker en Actions | Alta | Medio | Los tests solo se ejecutan localmente. Riesgo de regresión silenciosa en PR. Mitigable activando runner windows-2022 con Docker para CI pleno (coste ~2-4 USD/run). |
| **Warehouse events BC 27** — los nombres de eventos y páginas pueden diferir de versiones anteriores | Media | Alto | Verificar con BC Symbol Reference. Ya existe precedente documentado en Issues 9–10 (eventos de tabla vs codeunit). |
| **Históricos de devolución** — los nombres de páginas BC 27 para return documents pueden haber cambiado | Baja | Bajo | Verificar con BC Symbol Reference. Ya existe precedente en el proyecto (Issues 9–10). |
| **Coste de BC SaaS sandbox** para demos/validación | — | Bajo | Usar tenant de prueba del partner o demo de Microsoft. |

---

## 9. Recomendación Comercial

### ¿Qué ofrecer primero?

**Recomendación principal: Escenario B — Versión recomendada (12 jornadas adicionales / 6.000 EUR).**

El proyecto tiene una base técnica excepcionalmente sólida. La Fase 1 completa más los módulos de coste/precio y ratio por lote ya existen y son demostrables. El esfuerzo incremental para llegar a una versión comercialmente completa (con almacén básico e informes) es muy bajo en relación al valor total del producto.

**Discurso comercial recomendado:**

> *"La extensión DualUoM-BC está construida y madura. No partimos de cero: el motor de cálculo, la integración con el ciclo completo de compra y venta, la trazabilidad en históricos, el coste y precio en segunda UoM, el ratio real por lote y la localización ya funcionan y están testeados con 114 pruebas automatizadas. La inversión para cerrar una versión completamente vendible es de solo 6.000 EUR, que cubre los módulos de almacén básico e informes. El cliente obtiene una solución production-ready en BC SaaS sin modificar el estándar, upgrade-safe y con TDD completo."*

### ¿Qué dejar como opcional?

- **WMS Directed Pick** (Issue 15): solo si el cliente usa Directed Put-Away & Pick activo. Es la parte más compleja y costosa. Deferirla a una segunda fase reduce el riesgo del proyecto inicial.
- **Devoluciones** (Issue 16): funcionalidad importante pero no bloqueante para la mayoría de implantaciones iniciales.
- **Documentación ISV / AppSource**: solo si el objetivo es distribuir como producto de catálogo.
- **Item Tracking avanzado** (serial numbers): solo si el cliente lo usa activamente.

### ¿Qué tiene más sentido comercial?

1. **Fase 0 — Fit-gap gratuito o a coste simbólico:** una sesión de ~0,5 j con el cliente para validar que los módulos cubiertos encajan con su operativa real. Evita sorpresas.
2. **Fase 1 — Entrega del núcleo ya construido** como demostración tangible del valor. Instalar en sandbox del cliente, walkthrough funcional.
3. **Fase 2 — Contrato de cierre** para los issues pendientes (Escenario A o B según el perfil del cliente).
4. **Fase 3 — Opciones a medida** según las necesidades específicas del cliente (WMS, devoluciones, informes, localización adicional).

---

## 10. Anexo Técnico Resumido

### Objetos AL implementados (producción)

| Tipo | ID | Nombre | Descripción |
|------|----|--------|-------------|
| Enum | 50100 | `DUoM Conversion Mode` | Fixed / Variable / AlwaysVariable |
| Table | 50100 | `DUoM Item Setup` | Configuración DUoM por artículo |
| Table | 50101 | `DUoM Item Variant Setup` | Override DUoM por variante de artículo |
| Table | 50102 | `DUoM Lot Ratio` | Ratio real medido por número de lote |
| TableExt | 50100 | `Item.TableExt` | Cascade delete del setup al borrar artículo |
| TableExt | 50110 | `DUoM Purchase Line Ext` | Segunda Qty, Ratio y Unit Cost DUoM en compra |
| TableExt | 50111 | `DUoM Sales Line Ext` | Segunda Qty, Ratio y Unit Price DUoM en venta |
| TableExt | 50112 | `DUoM Item Journal Line Ext` | Segunda Qty y Ratio en diario de productos |
| TableExt | 50113 | `DUoM Item Ledger Entry Ext` | Segunda Qty y Ratio en ILE (inmutable) |
| TableExt | 50114 | `DUoM Purch. Rcpt. Line Ext` | Histórico recepciones de compra (+ Unit Cost) |
| TableExt | 50115 | `DUoM Sales Shipment Line Ext` | Histórico albaranes de venta (+ Unit Price) |
| TableExt | 50116 | `DUoM Purch. Inv. Line Ext` | Histórico facturas de compra (+ Unit Cost) |
| TableExt | 50117 | `DUoM Purch. Cr. Memo Line Ext` | Histórico abonos de compra (+ Unit Cost) |
| TableExt | 50118 | `DUoM Sales Inv. Line Ext` | Histórico facturas de venta (+ Unit Price) |
| TableExt | 50119 | `DUoM Sales Cr.Memo Line Ext` | Histórico abonos de venta (+ Unit Price) |
| TableExt | 50120 | `DUoM Item Variant Ext` | Cascade delete variant setup al borrar variante |
| TableExt | 50121 | `DUoM Value Entry Ext` | Segunda Qty en Value Entry (trazabilidad contable) |
| Codeunit | 50101 | `DUoM Calc Engine` | Motor de cálculo (Fixed/Variable/AlwaysVar + Rounding) |
| Codeunit | 50102 | `DUoM Purchase Subscribers` | Suscriptores del flujo de compras (Qty + Variant) |
| Codeunit | 50103 | `DUoM Sales Subscribers` | Suscriptores del flujo de ventas (Qty + Variant) |
| Codeunit | 50104 | `DUoM Inventory Subscribers` | Suscriptores ILE, Value Entry, diario, históricos |
| Codeunit | 50105 | `DUoM Doc Transfer Helper` | Lógica centralizada de copia entre líneas |
| Codeunit | 50106 | `DUoM UoM Helper` | Precisión de redondeo por artículo/UoM |
| Codeunit | 50107 | `DUoM Setup Resolver` | Resolución jerárquica item → variante → lote |
| Codeunit | 50108 | `DUoM Lot Subscribers` | Suscriptor IJL `Lot No.` + `TryApplyLotRatioToILE` |
| Page | 50100 | `DUoM Item Setup` | Tarjeta de configuración DUoM por artículo |
| Page | 50101 | `DUoM Variant Setup List` | Lista de overrides DUoM por variante |
| Page | 50102 | `DUoM Lot Ratio List` | Lista de ratios reales por lote |
| PageExt | 50100 | `DUoM Item Card Ext` | Acciones DUoM en Item Card (setup, variantes) |
| PageExt | 50101 | `DUoM Purchase Order Subform` | Líneas de pedido de compra |
| PageExt | 50102 | `DUoM Sales Order Subform` | Líneas de pedido de venta |
| PageExt | 50103 | `DUoM Item Journal Ext` | Diario de productos |
| PageExt | 50104 | `DUoM Posted Rcpt. Subform` | Recepciones registradas (solo lectura) |
| PageExt | 50105 | `DUoM Posted Ship. Subform` | Albaranes registrados (solo lectura) |
| PageExt | 50106 | `DUoM Pstd Purch Inv Subform` | Facturas de compra registradas (solo lectura) |
| PageExt | 50107 | `DUoM Pstd Purch CrM Subform` | Abonos de compra registrados (solo lectura) |
| PageExt | 50108 | `DUoM Pstd Sales Inv Subform` | Facturas de venta registradas (solo lectura) |
| PageExt | 50109 | `DUoM Pstd Sales CrM Subform` | Abonos de venta registrados (solo lectura) |
| PageExt | 50110 | `DUoM Item UoM Subform` | Subformulario UoM: `Qty. Rounding Precision` editable |
| PageExt | 50111 | `DUoM Item Ledger Entry` | Movimientos de producto con Segunda Qty |
| PermSet | 50100 | `DUoM - All` | Permisos completos para usuarios DUoM |

### Objetos de test implementados

| ID | Nombre | Tests |
|----|--------|-------|
| 50201 | `DUoM Item Setup Tests` | 9 tests (setup, validación, GetOrCreate) |
| 50202 | `DUoM Item Card Opening Tests` | 4 tests (apertura página desde Item Card) |
| 50203 | `DUoM Item Delete Tests` | 2 tests (cascade delete artículo) |
| 50204 | `DUoM Calc Engine Tests` | 16 tests (Fixed/Variable/AlwaysVar/Rounding/edge cases) |
| 50205 | `DUoM Purchase Tests` | 9 tests (validate Qty, modos, rounding) |
| 50206 | `DUoM Sales Tests` | 8 tests (validate Qty, modos, rounding) |
| 50207 | `DUoM Inventory Tests` | 6 tests (diario de productos) |
| 50208 | `DUoM Test Helpers` | Helper compartido (sin `[Test]`) |
| 50209 | `DUoM ILE Integration Tests` | 6 tests E2E (posting completo → ILE + rcpt/ship) |
| 50210 | `DUoM Inv CrMemo Post Tests` | 5 tests E2E (factura y abono compra/venta) |
| 50211 | `DUoM Variant Tests` | 15 tests (jerarquía item→variante, override, resolver) |
| 50212 | `DUoM Item UoM Round Tests` | 4 tests (editabilidad `Qty. Rounding Precision`) |
| 50213 | `DUoM UoM Helper Tests` | 7 tests (GetSecondUoMRoundingPrecision, GetRoundingPrecisionByUoMCode) |
| 50214 | `DUoM Var Mode Post Tests` | 4 tests E2E (posting Variable y AlwaysVariable) |
| 50215 | `DUoM Variant Del Tests` | 3 tests (cascade delete variante → setup DUoM) |
| 50216 | `DUoM Cost Price Tests` | 8 tests (Unit Cost/Price DUoM, derivación, propagación) |
| 50217 | `DUoM Lot Ratio Tests` | 8 tests (ratio por lote en IJL, ILE proporcional, multi-lote) |
| 50200 | `DUoM - Test All` (PermSet) | Permisos para tests |
| **TOTAL** | | **114 tests** |

### Áreas pendientes principales

| Área | Issue | Complejidad |
|------|-------|-------------|
| Almacén básico | 14 | Alta (eventos warehouse BC 27) |
| WMS Directed Pick | 15 | Muy alta (Activity Line, flujos complejos) |
| Devoluciones | 16 | Media |
| Inventario físico | 17 | Baja-media |
| Informes | 18 | Baja-media |

---

*Documento elaborado en abril de 2026 a partir del análisis del repositorio `DynamITVectorK/DualUoM-BC2`. Las estimaciones son orientativas y están sujetas a revisión tras un análisis de fit-gap con el cliente final.*
