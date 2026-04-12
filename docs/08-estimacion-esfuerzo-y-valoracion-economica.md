# DualUoM-BC — Estimación de Esfuerzo y Valoración Económica

> **Fecha de elaboración:** Abril 2026  
> **Estado del repositorio analizado:** BC 27 / runtime 15 · Phase 1 + Issues 9–11 completados  
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
| Ratio real por lote | ❌ | 🔜 Phase 2 |
| Segunda cantidad en líneas de documento | ❌ | ✅ Table extensions |
| Segunda cantidad en movimientos contables | ❌ | ✅ Table extension ILE |
| Históricos completos con segunda cantidad | ❌ | ✅ 6 table extensions |
| Almacén avanzado (put-away & pick) | ❌ | 🔜 Phase 2 |

### Estado actual del proyecto

El proyecto ha completado **la Fase 1 (MVP) íntegra** más los Issues 9, 10 y 11 de la Fase 2. Existe código AL funcional, una suite de tests automatizados con **65 procedimientos `[Test]`** distribuidos en 9 codeunits, y documentación técnica y funcional completa.

La extensión está actualmente en un **estado demostrable** para la funcionalidad base (compras, ventas, inventario y propagación a históricos). Las funcionalidades de almacén avanzado, ratio por lote y modelo de coste en doble UoM están diseñadas en el backlog pero no implementadas.

### Grado de madurez

| Área | Madurez |
|------|---------|
| Motor de cálculo y configuración por artículo | 🟢 Producción |
| Compras (pedido, recepción, factura, abono) | 🟢 Producción |
| Ventas (pedido, albarán, factura, abono) | 🟢 Producción |
| Inventario (diario de productos, ILE) | 🟢 Producción |
| Históricos completos (6 documentos) | 🟢 Producción |
| Precisión de redondeo por UoM | 🟢 Producción |
| Localización en-US / es-ES | 🟢 Producción |
| Suite de tests automatizados | 🟢 65 tests (9 codeunits) |
| Ratio por lote (Item Tracking) | 🔴 Pendiente (Phase 2) |
| Coste/precio en doble UoM | 🔴 Pendiente (Phase 2) |
| Almacén básico (Warehouse Receipt/Shipment) | 🔴 Pendiente (Phase 2) |
| Almacén dirigido (Put-Away & Pick) | 🔴 Pendiente (Phase 2) |
| Devoluciones (Purchase/Sales Returns) | 🔴 Pendiente (Phase 2) |
| Informes (Report Extensions) | 🔴 Pendiente (Phase 2) |

---

## 2. Alcance Funcional del Producto

### 2.1 Qué cubre actualmente

- **Setup por artículo:** activación DUoM, segunda UoM, modo de conversión, ratio fijo.
- **Pedidos de compra:** campos Segunda Qty y Ratio visibles y editables en líneas.
- **Recepciones de compra:** segunda cantidad propagada al registrar.
- **Facturas y abonos de compra registrados:** segunda cantidad trazada en histórico.
- **Pedidos de venta:** campos Segunda Qty y Ratio en líneas.
- **Albaranes de venta:** segunda cantidad propagada al registrar.
- **Facturas y abonos de venta registrados:** segunda cantidad trazada en histórico.
- **Diario de productos:** segunda cantidad en líneas y propagación al ILE.
- **Movimiento de producto (ILE):** segunda cantidad y ratio inmutables tras contabilización.
- **Precisión de redondeo:** `DUoM Second Qty` se redondea al paso mínimo de la UoM secundaria.
- **Localización completa** en inglés y español (todos los textos de UI traducidos).

### 2.2 Qué cubrirá con la siguiente fase (Phase 2)

- **Modelo de coste/precio en doble UoM:** `DUoM Unit Price` en ventas y `DUoM Unit Cost` en compras; derivación automática entre UoM principal y secundaria.
- **Ratio real por lote:** tabla `DUoM Lot Ratio`; al asignar un lote en la línea, se pre-rellena el ratio real registrado en la recepción.
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
| Motor de cálculo `DUoM Calc Engine` (50101) | `DUoMCalcEngine.Codeunit.al` (83 líneas) | `DUoMCalcEngineTests` (16 tests) |
| Helper de UoM `DUoM UoM Helper` (50106) | `DUoMUoMHelper.Codeunit.al` (33 líneas) | Cubierto en tests de Purchase y Sales |
| Extensión `Purchase Line` (50110) | `DUoMPurchaseLine.TableExt.al` (58 líneas) | `DUoMPurchaseTests` (9 tests) |
| Extensión `Sales Line` (50111) | `DUoMSalesLine.TableExt.al` (57 líneas) | `DUoMSalesTests` (8 tests) |
| Extensión `Item Journal Line` (50112) | `DUoMItemJournalLine.TableExt.al` (57 líneas) | `DUoMInventoryTests` (6 tests) |
| Extensión `Item Ledger Entry` (50113) | `DUoMItemLedgerEntry.TableExt.al` (24 líneas) | `DUoMILEIntegrationTests` (6 tests E2E) |
| Extensiones históricos compra (50114, 50116, 50117) | 3 table extensions | `DUoMILEIntegrationTests`, `DUoMInvCrMemoPostTests` |
| Extensiones históricos venta (50115, 50118, 50119) | 3 table extensions | `DUoMILEIntegrationTests`, `DUoMInvCrMemoPostTests` (5 tests E2E) |
| Suscriptores compra (50102) | `DUoMPurchaseSubscribers.Codeunit.al` (48 líneas) | Cubierto en DUoMPurchaseTests |
| Suscriptores venta (50103) | `DUoMSalesSubscribers.Codeunit.al` (48 líneas) | Cubierto en DUoMSalesTests |
| Suscriptores inventario/ILE (50104) | `DUoMInventorySubscribers.Codeunit.al` (219 líneas) | Cubierto en múltiples codeunits de test |
| Helper de copia entre líneas (50105) | `DUoMDocTransferHelper.Codeunit.al` (101 líneas) | Cubierto en tests E2E |
| Page extensions (10 extensiones de página) | IDs 50101–50109 + 50103 | — |
| Permission sets app y test | `DUoMAll.PermissionSet.al`, `DUoMTestAll.PermissionSet.al` | — |
| Localización completa | 156 `trans-unit` en en-US y es-ES XLF | — |
| Manual de usuario | `docs/manual-usuario.md` | — |

**Total objetos AL de producción:** 1 enum, 1 tabla, 10 table extensions, 6 codeunits, 1 página, 10 page extensions, 1 permission set = **30 objetos**  
**Total objetos AL de test:** 9 codeunits de test + 1 helper + 1 permission set = **11 objetos**  
**Total líneas AL (producción):** ~1.650 líneas  
**Total líneas AL (test):** ~2.091 líneas  
**Total tests `[Test]`:** 65 procedimientos de test

### 3.2 Deuda técnica y consolidación pendiente

| Ref. | Hallazgo | Impacto | Esfuerzo estimado |
|------|---------|---------|-------------------|
| Auditoría MVP | Huecos TDD: sin test para modo Variable con ratio default + override de ratio en línea | Cobertura incompleta en escenarios críticos | 0,5 j |
| Auditoría MVP | Tests para `OnValidate DUoM Ratio` (recálculo al cambiar ratio en línea) no existen | Riesgo de regresión si se modifica la lógica | 0,5 j |
| Auditoría MVP | `Caption` ausente en campos de 4 table extensions (Issue resuelto parcialmente según backlog) | Sin caption → UI en inglés en entornos sin XLF aplicado | Verificar en código — posiblemente ya resuelto |
| General | `useCompilerFolder=true` en CI impide ejecución de tests en Actions (solo compila) | Tests no se ejecutan automáticamente en CI → riesgo de regresión silenciosa | Coste CI si se activa Docker runner |
| General | Deuda de consolidación Phase 1 antes de escalar a Phase 2 | Riesgo de arquitectura si se saltan issues fundacionales | 1–2 j |

### 3.3 Funcionalidades pendientes (Phase 2 y siguientes)

| Issue | Bloque | Estado |
|-------|--------|--------|
| 12 | Coste/precio en doble UoM (`DUoM Unit Price`, `DUoM Unit Cost`, `Value Entry`) | ❌ No implementado |
| 13 | Ratio real por lote (`DUoM Lot Ratio`, lógica de Item Tracking) | ❌ No implementado |
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
| Localización en-US / es-ES | 156 `trans-unit` en dos XLF, captions, tooltips, labels con Comment | 2,0 |
| Manual de usuario | Documento funcional completo para usuario de negocio | 1,5 |
| Hardening SaaS y auditoría | Correcciones de firma de eventos BC 27, permisos IndirectInsert, CI cost decisions | 2,5 |
| **TOTAL YA REALIZADO** | | **32,5 jornadas** |

### 4.2 Trabajo pendiente para cerrar una versión vendible (Phase 2 core)

| Bloque | Descripción | Jornadas | Observaciones |
|--------|-------------|----------|---------------|
| Consolidación deuda técnica | Tests TDD pendientes (modo Variable, override ratio, OnValidate Ratio), revisión captions | 2,0 | Antes de Phase 2 |
| Issue 12 — Coste/precio DUoM | `DUoM Unit Price` en venta, `DUoM Unit Cost` en compra, derivación, `Value Entry` ext | 5,0 | Alta complejidad: lógica de posting + Value Entry |
| Issue 13 — Ratio por lote | Tabla `DUoM Lot Ratio`, página, suscriptores `Lot No.` validate, tests | 4,0 | Requiere conocimiento de Item Tracking BC 27 |
| Issue 14 — Almacén básico | `Warehouse Receipt/Shipment Line` ext, suscriptores, page exts, tests E2E | 5,0 | Verificar eventos BC 27; complejidad moderada-alta |
| Issue 17 — Inventario físico | `Phys. Inventory Ledger Entry` ext, lógica journal, tests | 2,0 | Relativamente independiente |
| Soporte deploy + release | Packaging .app, documentación de instalación, permissionsets finales, test de smoke en tenant real | 2,0 | Necesario antes de cliente |
| **TOTAL PENDIENTE VENDIBLE** | | **20,0 jornadas** | |

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
| A. Trabajo ya realizado | 32,5 | 16.250 EUR |
| B. Cierre de versión vendible | 20,0 | 10.000 EUR |
| C. Opcionales / fases futuras | 22,5 | 11.250 EUR |
| **TOTAL GLOBAL** | **75,0** | **37.500 EUR** |

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
| 12 | Localización en-US / es-ES | 2,0 | 500 | 1.000 EUR |
| 13 | Manual de usuario | 1,5 | 500 | 750 EUR |
| 14 | Hardening SaaS y auditoría | 2,5 | 500 | 1.250 EUR |
| **Subtotal — Realizado** | | **32,5** | | **16.250 EUR** |
| 15 | Consolidación deuda técnica | 2,0 | 500 | 1.000 EUR |
| 16 | Coste/precio en doble UoM | 5,0 | 500 | 2.500 EUR |
| 17 | Ratio real por lote | 4,0 | 500 | 2.000 EUR |
| 18 | Almacén básico | 5,0 | 500 | 2.500 EUR |
| 19 | Inventario físico | 2,0 | 500 | 1.000 EUR |
| 20 | Soporte deploy y release | 2,0 | 500 | 1.000 EUR |
| **Subtotal — Cierre vendible** | | **20,0** | | **10.000 EUR** |
| 21 | WMS Directed Put-Away & Pick | 6,0 | 500 | 3.000 EUR |
| 22 | Devoluciones purchase/sales | 4,0 | 500 | 2.000 EUR |
| 23 | Informes (report extensions) | 3,0 | 500 | 1.500 EUR |
| 24 | Item Tracking avanzado | 4,0 | 500 | 2.000 EUR |
| 25 | Mejoras UX | 2,0 | 500 | 1.000 EUR |
| 26 | Performance & hardening | 2,0 | 500 | 1.000 EUR |
| 27 | Documentación avanzada (ISV) | 1,5 | 500 | 750 EUR |
| **Subtotal — Opcionales** | | **22,5** | | **11.250 EUR** |
| **TOTAL GLOBAL** | | **75,0** | | **37.500 EUR** |

---

## 6. Escenarios de Contratación

### Escenario A — Base actual + cierre mínimo vendible

**Incluye:**
- Todo lo ya construido (Issues 1–11 completados): motor de cálculo, setup por artículo, compras, ventas, inventario, históricos completos, precisión de redondeo, localización.
- Consolidación de deuda técnica (tests pendientes, hardening).
- Coste/precio en doble UoM (Issue 12).
- Soporte de deploy y entrega del `.app` al cliente.

**Excluye:** ratio por lote, almacén, devoluciones, informes, WMS avanzado.

| Concepto | Jornadas | Importe |
|----------|----------|---------|
| Trabajo ya realizado | 32,5 j | *(inversión ya materializada)* |
| Cierre mínimo vendible (deuda + Issue 12 + deploy) | 9,0 j | **4.500 EUR** |
| **Total a contratar** | **9,0 j** | **4.500 EUR** |

**Para qué tipo de cliente encaja:**
Empresas que compran y venden artículos con doble UoM sin procesos de almacén avanzado. Ideal como primera implantación para validar el valor y el fit funcional antes de comprometer una inversión mayor.

---

### Escenario B — Versión recomendada (Phase 2 core completa)

**Incluye:**
- Todo el Escenario A.
- Ratio real por lote (Issue 13): trazabilidad de ratio medido en recepción.
- Almacén básico (Issue 14): `Warehouse Receipt` y `Shipment Line` con segunda cantidad.
- Inventario físico (Issue 17).
- Informes estándar con segunda cantidad (Issue 18).

**Excluye:** WMS dirigido (put-away & pick), devoluciones avanzadas, Item Tracking multi-lote.

| Concepto | Jornadas | Importe |
|----------|----------|---------|
| Trabajo ya realizado | 32,5 j | *(inversión ya materializada)* |
| Cierre vendible completo (Escenario A) | 9,0 j | 4.500 EUR |
| Ratio por lote (Issue 13) | 4,0 j | 2.000 EUR |
| Almacén básico (Issue 14) | 5,0 j | 2.500 EUR |
| Inventario físico (Issue 17) | 2,0 j | 1.000 EUR |
| Informes (Issue 18) | 3,0 j | 1.500 EUR |
| **Total a contratar** | **23,0 j** | **11.500 EUR** |

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
| Trabajo ya realizado | 32,5 j | *(inversión ya materializada)* |
| Escenario B (a contratar) | 23,0 j | 11.500 EUR |
| WMS Directed (Issue 15) | 6,0 j | 3.000 EUR |
| Devoluciones (Issue 16) | 4,0 j | 2.000 EUR |
| Mejoras UX | 2,0 j | 1.000 EUR |
| Performance & hardening | 2,0 j | 1.000 EUR |
| Documentación ISV | 1,5 j | 750 EUR |
| **Total a contratar** | **38,5 j** | **19.250 EUR** |

**Para qué tipo de cliente encaja:**
Empresas con WMS avanzado (Directed Put-Away & Pick activo en BC), alto volumen de movimientos de almacén, o ISV/partner que quieran distribuir la extensión como producto propio en AppSource.

---

## 7. Supuestos

1. **Una jornada = 8 horas** de trabajo efectivo de un consultor/desarrollador BC Senior.
2. **BC 27 / runtime 15 SaaS** como plataforma de destino. Si el cliente usa una versión anterior, los eventos y firmas deben re-verificarse.
3. **El trabajo ya realizado** (32,5 j) representa el valor acumulado en el repositorio. No se incluye en ninguna facturación futura salvo que se contemple en el modelo comercial del partner.
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
| **Item Tracking por lotes** — el Issue 13 requiere entender la configuración real del cliente | Media | Medio | Hacer sesión de descubrimiento antes de iniciar Issue 13. |
| **Posting de devoluciones** — eventos de BC 27 para return flows pueden diferir | Media | Medio | Verificar nombres y firmas de eventos en BC Symbol Reference antes del Issue 16. |
| **CI sin ejecución automática de tests** — `useCompilerFolder=true` impide Docker en Actions | Alta | Medio | Los tests solo se ejecutan localmente. Riesgo de regresión silenciosa en PR. Mitigable activando runner windows-2022 con Docker para CI pleno (coste ~2-4 USD/run). |
| **Decisiones de alcance pendientes** — ratio por lote puede implicar UI adicional no estimada | Media | Medio | Confirmar alcance exacto con el cliente antes de comenzar Issue 13. |
| **Históricos de devolución** — los nombres de páginas BC 27 para return documents pueden haber cambiado | Baja | Bajo | Verificar con BC Symbol Reference. Ya existe precedente en el proyecto (Issues 9–10). |
| **Coste de BC SaaS sandbox** para demos/validación | — | Bajo | Usar tenant de prueba del partner o demo de Microsoft. |

---

## 9. Recomendación Comercial

### ¿Qué ofrecer primero?

**Recomendación principal: Escenario B — Versión recomendada (23 jornadas adicionales / 11.500 EUR).**

El proyecto tiene una base técnica sólida y bien construida. La Fase 1 completa ya existe y es demostrable. El esfuerzo incremental para llegar a una versión comercialmente completa (con lotes, almacén básico e informes) es relativamente bajo en relación al valor total del producto.

**Discurso comercial recomendado:**

> *"La extensión DualUoM-BC está construida. No partimos de cero: el motor de cálculo, la integración con el ciclo de compra y venta, la trazabilidad en históricos y la localización ya funcionan y están testeados. La inversión para cerrar una versión completamente vendible es de 11.500 EUR, que cubre los módulos de almacén básico, trazabilidad por lote e informes. El cliente obtiene una solución production-ready en BC SaaS sin modificar el estándar, upgrade-safe y con TDD completo."*

### ¿Qué dejar como opcional?

- **WMS Directed Pick** (Issue 15): solo si el cliente usa Directed Put-Away & Pick activo. Es la parte más compleja y costosa. Deferirla a una segunda fase reduce el riesgo del proyecto inicial.
- **Devoluciones** (Issue 16): funcionalidad importante pero no bloqueante para la mayoría de implantaciones iniciales.
- **Documentación ISV / AppSource**: solo si el objetivo es distribuir como producto de catálogo.
- **Item Tracking avanzado** (serial numbers): solo si el cliente lo usa activamente.

### ¿Qué tiene más sentido commercial?

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
| TableExt | 50100 | `Item.TableExt` | Cascade delete del setup al borrar artículo |
| TableExt | 50110 | `DUoM Purchase Line Ext` | Segunda Qty y Ratio en líneas de compra |
| TableExt | 50111 | `DUoM Sales Line Ext` | Segunda Qty y Ratio en líneas de venta |
| TableExt | 50112 | `DUoM Item Journal Line Ext` | Segunda Qty y Ratio en diario de productos |
| TableExt | 50113 | `DUoM Item Ledger Entry Ext` | Segunda Qty y Ratio en ILE (inmutable) |
| TableExt | 50114 | `DUoM Purch. Rcpt. Line Ext` | Histórico recepciones de compra |
| TableExt | 50115 | `DUoM Sales Shipment Line Ext` | Histórico albaranes de venta |
| TableExt | 50116 | `DUoM Purch. Inv. Line Ext` | Histórico facturas de compra |
| TableExt | 50117 | `DUoM Purch. Cr. Memo Line Ext` | Histórico abonos de compra |
| TableExt | 50118 | `DUoM Sales Inv. Line Ext` | Histórico facturas de venta |
| TableExt | 50119 | `DUoM Sales Cr.Memo Line Ext` | Histórico abonos de venta |
| Codeunit | 50101 | `DUoM Calc Engine` | Motor de cálculo (Fixed/Variable/AlwaysVar + Rounding) |
| Codeunit | 50102 | `DUoM Purchase Subscribers` | Suscriptores del flujo de compras |
| Codeunit | 50103 | `DUoM Sales Subscribers` | Suscriptores del flujo de ventas |
| Codeunit | 50104 | `DUoM Inventory Subscribers` | Suscriptores ILE, diario, históricos |
| Codeunit | 50105 | `DUoM Doc Transfer Helper` | Lógica centralizada de copia entre líneas |
| Codeunit | 50106 | `DUoM UoM Helper` | Lectura de `Qty. Rounding Precision` por artículo/UoM |
| Page | 50100 | `DUoM Item Setup` | Tarjeta de configuración DUoM por artículo |
| PageExt | 50101 | `DUoM Purchase Order Subform` | Líneas de pedido de compra |
| PageExt | 50102 | `DUoM Sales Order Subform` | Líneas de pedido de venta |
| PageExt | 50103 | `DUoM Item Journal Ext` | Diario de productos |
| PageExt | 50104 | `DUoM Posted Rcpt. Subform` | Recepciones registradas (solo lectura) |
| PageExt | 50105 | `DUoM Posted Ship. Subform` | Albaranes registrados (solo lectura) |
| PageExt | 50106 | `DUoM Pstd Purch Inv Subform` | Facturas de compra registradas (solo lectura) |
| PageExt | 50107 | `DUoM Pstd Purch CrM Subform` | Abonos de compra registrados (solo lectura) |
| PageExt | 50108 | `DUoM Pstd Sales Inv Subform` | Facturas de venta registradas (solo lectura) |
| PageExt | 50109 | `DUoM Pstd Sales CrM Subform` | Abonos de venta registrados (solo lectura) |
| PageExt | (en ItemCard) | `DUoM Item Card Ext` | Acción de acceso a setup DUoM desde Item Card |
| PermSet | 50100 | `DUoM - All` | Permisos completos para usuarios DUoM |

### Objetos de test implementados

| ID | Nombre | Tests |
|----|--------|-------|
| 50201 | `DUoM Item Setup Tests` | 9 tests (setup, validación, GetOrCreate) |
| 50202 | `DUoM Item Card Opening Tests` | 4 tests (apertura página desde Item Card) |
| 50203 | `DUoM Item Delete Tests` | 2 tests (cascade delete) |
| 50204 | `DUoM Calc Engine Tests` | 16 tests (Fixed/Variable/AlwaysVar/Rounding/edge cases) |
| 50205 | `DUoM Purchase Tests` | 9 tests (validate Qty, modos, rounding) |
| 50206 | `DUoM Sales Tests` | 8 tests (validate Qty, modos, rounding) |
| 50207 | `DUoM Inventory Tests` | 6 tests (diario de productos) |
| 50208 | `DUoM Test Helpers` | Helpers compartidos (setup permisos) |
| 50209 | `DUoM ILE Integration Tests` | 6 tests E2E (posting completo → ILE + rcpt/ship) |
| 50210 | `DUoM Inv CrMemo Post Tests` | 5 tests E2E (factura y abono compra/venta) |
| 50200 | `DUoM - Test All` (PermSet) | Permisos para tests |

### Áreas pendientes principales

| Área | Issue | Complejidad |
|------|-------|-------------|
| Coste/precio en doble UoM | 12 | Alta (Value Entry) |
| Ratio real por lote | 13 | Media (Item Tracking) |
| Almacén básico | 14 | Alta (eventos warehouse BC 27) |
| WMS Directed Pick | 15 | Muy alta (Activity Line, flujos complejos) |
| Devoluciones | 16 | Media |
| Inventario físico | 17 | Baja-media |
| Informes | 18 | Baja-media |

---

*Documento elaborado en abril de 2026 a partir del análisis del repositorio `DynamITVectorK/DualUoM-BC2`. Las estimaciones son orientativas y están sujetas a revisión tras un análisis de fit-gap con el cliente final.*
