# DualUoM-BC — Blueprint Técnico WMS Avanzado

> **Estado:** Borrador aprobado · Versión 1.0 · Mayo 2026
>
> **Propósito:** Diseño técnico detallado para la implementación de DUoM en los flujos de
> almacén avanzado de Business Central (Issues 14 y 15 y tareas futuras). Este documento
> es el prerequisito obligatorio antes de comenzar cualquier código de producción WMS.

---

## Índice

1. [Alcance de este documento](#1-alcance-de-este-documento)
2. [Objetos estándar BC objetivo](#2-objetos-estándar-bc-objetivo)
3. [Mapa de propagación DUoM por flujo](#3-mapa-de-propagación-duom-por-flujo)
4. [Eventos estándar candidatos por objeto](#4-eventos-estándar-candidatos-por-objeto)
5. [Riesgos de permisos y performance SaaS](#5-riesgos-de-permisos-y-performance-saas)
6. [Estrategia de tests mínimos WMS](#6-estrategia-de-tests-mínimos-wms)
7. [Plan de implementación incremental](#7-plan-de-implementación-incremental)
8. [In / Out scope del primer incremento WMS](#8-in--out-scope-del-primer-incremento-wms)
9. [Referencias](#9-referencias)

---

## 1. Alcance de este documento

Este blueprint cubre el diseño técnico de la integración DUoM con el subsistema de
**almacén avanzado** de Business Central 27 (runtime 15), incluyendo:

- Almacén básico: `Warehouse Receipt` / `Warehouse Shipment` (Issue 14).
- Almacén dirigido: `Warehouse Activity Line` con Put-Away y Pick (Issue 15).
- Entradas de almacén (`Warehouse Entry`) como paso intermedio.
- Tareas futuras: soporte N-lotes en almacén, documentos registrados de almacén.

### Dependencias previas completadas

| Issue | Descripción | Estado |
|-------|-------------|--------|
| 1–10 (Phase 1 MVP) | Flujo completo compra/venta/diario → ILE → históricos | ✅ |
| 11 | Rounding precision en DUoM Second Qty | ✅ |
| 11b | Jerarquía Item → Variante con DUoM Setup Resolver | ✅ |
| 12 | DUoM Unit Cost y Unit Price en líneas y históricos | ✅ |
| 13 | DUoM Lot Ratio (tabla 50102), TryApplyLotRatioToILE | ✅ |
| 20/21 | Modelo 1:N consolidado, patrón OnAfterCopyTracking* | ✅ |
| 22/23 | Tracking Specification y Reservation Entry con DUoM | ✅ |

---

## 2. Objetos estándar BC objetivo

### 2.1 Objetos de almacén básico (Issue 14)

| Objeto BC | Tabla | ID tabla | Descripción funcional |
|-----------|-------|----------|-----------------------|
| `Warehouse Receipt Header` | `Warehouse Receipt Header` | 7316 | Cabecera del documento de recepción |
| `Warehouse Receipt Line` | `Warehouse Receipt Line` | 7317 | Líneas de recepción; se crean desde `Purchase Line` |
| `Warehouse Shipment Header` | `Warehouse Shipment Header` | 7320 | Cabecera del documento de expedición |
| `Warehouse Shipment Line` | `Warehouse Shipment Line` | 7321 | Líneas de expedición; se crean desde `Sales Line` |
| `Posted Whse. Receipt Header` | `Posted Whse. Receipt Header` | 7332 | Cabecera de recepción de almacén registrada |
| `Posted Whse. Receipt Line` | `Posted Whse. Receipt Line` | 7333 | Líneas registradas; potencial para Phase 3 |
| `Posted Whse. Shipment Header` | `Posted Whse. Shipment Header` | 7324 | Cabecera de expedición registrada |
| `Posted Whse. Shipment Line` | `Posted Whse. Shipment Line` | 7325 | Líneas registradas; potencial para Phase 3 |

> **Nota de fase:** Los documentos `Posted Whse. Receipt Line` y `Posted Whse. Shipment Line`
> se evalúan durante Issue 14. Si el evento de posting no expone estos registros con `var`
> antes del `Insert()`, se posponerán a una tarea futura.

### 2.2 Objetos de almacén dirigido (Issue 15)

| Objeto BC | Tabla | ID tabla | Descripción funcional |
|-----------|-------|----------|-----------------------|
| `Warehouse Activity Header` | `Warehouse Activity Header` | 5765 | Cabecera de actividad (Put-Away / Pick / Movement) |
| `Warehouse Activity Line` | `Warehouse Activity Line` | 5767 | Líneas de put-away, pick y movimiento |
| `Registered Whse. Activity Hdr.` | `Registered Whse. Activity Hdr.` | 7307 | Cabecera de actividad registrada |
| `Registered Whse. Activity Line` | `Registered Whse. Activity Line` | 7308 | Líneas registradas; potencial para Phase 3 |

### 2.3 Objetos intermedios y de movimiento

| Objeto BC | Tabla | ID tabla | Descripción funcional |
|-----------|-------|----------|-----------------------|
| `Warehouse Entry` | `Warehouse Entry` | 7312 | Movimientos definitivos de almacén (inmutables) |
| `Warehouse Journal Line` | `Warehouse Journal Line` | 7311 | Buffer para crear Warehouse Entries |
| `Item Journal Line` | `Item Journal Line` | 83 | Ya extendido (50112) — puente hacia ILE en posting |

### 2.4 Relación con la arquitectura existente

La cadena de propagación DUoM existente en Phase 1 es:

```
Purchase Line ──► Purch. Rcpt. Line ──► Item Journal Line ──► ILE
Sales Line    ──► Sales Shipment Line ──► Item Journal Line ──► ILE
```

Con almacén habilitado, esta cadena se extiende:

```
Purchase Line ──► Warehouse Receipt Line ──► [Whse.-Post Receipt] ──► Item Journal Line ──► ILE
Sales Line    ──► Warehouse Shipment Line ──► [Whse.-Post Shipment] ──► Item Journal Line ──► ILE
```

Con almacén dirigido, se añade un nivel intermedio:

```
Warehouse Receipt Line ──► Warehouse Activity Line (Put-Away) ──► Warehouse Entry
Warehouse Shipment Line ──► Warehouse Activity Line (Pick) ──► [Post Shipment] ──► ILE
```

---

## 3. Mapa de propagación DUoM por flujo

### 3.1 Flujo de compra con Warehouse Receipt

```
┌─────────────────────┐
│   Purchase Order    │
│   Purchase Line     │  DUoM Second Qty = X
│   DUoM Ratio = R    │  DUoM Ratio = R
└──────────┬──────────┘
           │ [Whse.-Get Receipt] crea líneas
           ▼
┌─────────────────────┐
│  Warehouse Receipt  │
│  Receipt Line       │  DUoM Second Qty = X  ← propagar desde Purchase Line
│                     │  DUoM Ratio = R       ← propagar desde Purchase Line
└──────────┬──────────┘
           │ [Whse.-Post Receipt] contabiliza
           ├──► Posted Whse. Receipt Line  (potencial Phase 3)
           ▼
┌─────────────────────┐
│  Item Journal Line  │  DUoM Second Qty = X  ← propagar desde Receipt Line
│  (buffer posting)   │  DUoM Ratio = R
└──────────┬──────────┘
           │ OnAfterInitItemLedgEntry (codeunit 50104, ya implementado)
           ▼
┌─────────────────────┐
│ Item Ledger Entry   │  DUoM Second Qty = X  ✓
│                     │  DUoM Ratio = R       ✓
└─────────────────────┘
```

**Campos a propagar en cada salto:**

| Salto | Origen | Destino | Campos |
|-------|--------|---------|--------|
| 1 | `Purchase Line.DUoM Second Qty` | `Warehouse Receipt Line.DUoM Second Qty` | Second Qty, Ratio |
| 2 | `Warehouse Receipt Line.DUoM Second Qty` | `Item Journal Line.DUoM Second Qty` | Second Qty, Ratio |
| 3 | `Item Journal Line.DUoM Second Qty` | `ILE.DUoM Second Qty` | ya implementado (50104) |

### 3.2 Flujo de venta con Warehouse Shipment

```
┌─────────────────────┐
│    Sales Order      │
│    Sales Line       │  DUoM Second Qty = Y
│    DUoM Ratio = R   │  DUoM Ratio = R
└──────────┬──────────┘
           │ [Whse.-Get Shipment] crea líneas
           ▼
┌─────────────────────┐
│ Warehouse Shipment  │
│  Shipment Line      │  DUoM Second Qty = Y  ← propagar desde Sales Line
│                     │  DUoM Ratio = R       ← propagar desde Sales Line
└──────────┬──────────┘
           │ [Whse.-Post Shipment] contabiliza
           ├──► Posted Whse. Shipment Line (potencial Phase 3)
           ▼
┌─────────────────────┐
│  Item Journal Line  │  DUoM Second Qty = Y  ← propagar desde Shipment Line
│  (buffer posting)   │  DUoM Ratio = R
└──────────┬──────────┘
           │ OnAfterInitItemLedgEntry (codeunit 50104, ya implementado)
           ▼
┌─────────────────────┐
│ Item Ledger Entry   │  DUoM Second Qty = Y  ✓ (negativo = salida)
│                     │  DUoM Ratio = R       ✓
└─────────────────────┘
```

### 3.3 Flujo de put-away con Warehouse Activity (Issue 15)

```
┌─────────────────────┐
│  Warehouse Receipt  │
│  Receipt Line       │  DUoM Second Qty = X
│                     │  DUoM Ratio = R
└──────────┬──────────┘
           │ [Create Put-Away] crea actividad
           ▼
┌─────────────────────┐
│  Warehouse Activity │
│  Activity Line      │  DUoM Second Qty = X  ← propagar desde Receipt Line
│  (Type = Put-Away)  │  DUoM Ratio = R       ← propagar desde Receipt Line
└──────────┬──────────┘
           │ [Register Put-Away]
           ▼
┌─────────────────────┐
│  Warehouse Entry    │  DUoM Second Qty = X  ← potencial Phase 3
│                     │  DUoM Ratio = R
└─────────────────────┘
```

> **Nota:** `Warehouse Entry` es inmutable (no se puede modificar tras creación).
> La propagación DUoM a `Warehouse Entry` requiere un evento de inicialización previo
> al `Insert()` — verificar su existencia en BC 27.

### 3.4 Flujo de pick con Warehouse Activity (Issue 15)

```
┌─────────────────────┐
│ Warehouse Shipment  │
│  Shipment Line      │  DUoM Second Qty = Y
│                     │  DUoM Ratio = R
└──────────┬──────────┘
           │ [Create Pick] crea actividad
           ▼
┌─────────────────────┐
│  Warehouse Activity │
│  Activity Line      │  DUoM Second Qty = Y  ← propagar desde Shipment Line
│  (Type = Pick)      │  DUoM Ratio = R
└──────────┬──────────┘
           │ [Register Pick]  →  Warehouse Entry (potencial Phase 3)
           │ [Post Shipment]
           ▼
┌─────────────────────┐
│  Item Journal Line  │  DUoM Second Qty = Y  ← ya disponible si Shipment Line tiene DUoM
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│ Item Ledger Entry   │  DUoM Second Qty = Y  ✓
└─────────────────────┘
```

### 3.5 Resumen de saltos de propagación

| # | Origen | Destino | Issue | Estado |
|---|--------|---------|-------|--------|
| 1 | `Purchase Line` | `Warehouse Receipt Line` | 14 | ❌ Pendiente |
| 2 | `Warehouse Receipt Line` | `Item Journal Line` | 14 | ❌ Pendiente |
| 3 | `Item Journal Line` | `ILE` | Impl. | ✅ codeunit 50104 |
| 4 | `Sales Line` | `Warehouse Shipment Line` | 14 | ❌ Pendiente |
| 5 | `Warehouse Shipment Line` | `Item Journal Line` | 14 | ❌ Pendiente |
| 6 | `Warehouse Receipt Line` | `Warehouse Activity Line` (Put-Away) | 15 | ❌ Pendiente |
| 7 | `Warehouse Shipment Line` | `Warehouse Activity Line` (Pick) | 15 | ❌ Pendiente |
| 8 | `Warehouse Activity Line` | `Warehouse Entry` | Futuro | ⏳ Phase 3 |
| 9 | `Warehouse Receipt Line` | `Posted Whse. Receipt Line` | 14/Futuro | ⏳ Evaluar en 14 |
| 10 | `Warehouse Shipment Line` | `Posted Whse. Shipment Line` | 14/Futuro | ⏳ Evaluar en 14 |

---

## 4. Eventos estándar candidatos por objeto

> **Regla del proyecto (obligatoria):** toda firma de `[EventSubscriber]` debe incluir un
> comentario que indique el publisher (tabla o codeunit, nombre e ID), el nombre del evento,
> la razón de elección y la confirmación de validación contra BC 27 antes de codificar.
> Ver `docs/03-technical-architecture.md` — sección "Propagation patterns".

### 4.1 Salto 1: Purchase Line → Warehouse Receipt Line

| Candidato | Publisher | Tipo | Parámetros esperados | Probabilidad BC 27 |
|-----------|-----------|------|---------------------|-------------------|
| `OnAfterInitFromPurchLine` | `Table "Warehouse Receipt Line"` (7317) | Table event | `(PurchHeader, PurchLine, var WhseReceiptLine)` | **Alta** — patrón idéntico a `Purch. Rcpt. Line` ya verificado |
| `OnAfterCreateRcptLineFromPurchLine` | `Codeunit "Whse.-Get Receipt"` | Codeunit event | Verificar | Media |

**Evento preferido:** `OnAfterInitFromPurchLine` en `Table "Warehouse Receipt Line"`.
Sigue el mismo patrón que `OnAfterInitFromPurchLine` en `Table "Purch. Rcpt. Line"` (verificado
en Issues 6/7 de Phase 1). El subscriber expone `var WhseReceiptLine` **antes** del `Insert()`,
lo que permite asignación directa sin `Modify()` ni permisos adicionales.

**⚠️ Verificación obligatoria antes de codificar:** buscar en `microsoft/ALAppExtensions`
el fichero `WarehouseReceiptLine.Table.al` y confirmar la firma exacta.

### 4.2 Salto 4: Sales Line → Warehouse Shipment Line

| Candidato | Publisher | Tipo | Parámetros esperados | Probabilidad BC 27 |
|-----------|-----------|------|---------------------|-------------------|
| `OnAfterInitFromSalesLine` | `Table "Warehouse Shipment Line"` (7321) | Table event | `(SalesHeader, SalesLine, var WhseShipmentLine)` | **Alta** — patrón idéntico a `Sales Shipment Line` ya verificado |
| `OnAfterCreateShptLineFromSalesLine` | `Codeunit "Whse.-Get Shipment"` | Codeunit event | Verificar | Media |

**Evento preferido:** `OnAfterInitFromSalesLine` en `Table "Warehouse Shipment Line"`.

**⚠️ Verificación obligatoria:** confirmar firma exacta en `WarehouseShipmentLine.Table.al`.

### 4.3 Salto 2: Warehouse Receipt Line → Item Journal Line (durante posting)

Este salto es el más crítico y complejo. El `Codeunit "Whse.-Post Receipt"` genera un
`Item Journal Line` antes de llamar al posting de artículos.

| Candidato | Publisher | Parámetros esperados | Notas |
|-----------|-----------|---------------------|-------|
| `OnBeforeCreateWhseJnlLine` | `Codeunit "Whse.-Post Receipt"` | `(var ItemJnlLine, WhseReceiptLine, ...)` | Verificar si expone `WhseReceiptLine` correlacionada |
| `OnAfterCreateItemJnlLineFromReceipt` | `Codeunit "Whse.-Post Receipt"` | `(var ItemJnlLine, WhseReceiptLine)` | Candidato alto — nombre similar a patrones de Purchase/Sales post |
| `OnAfterPostWhseReceipt` | `Codeunit "Whse.-Post Receipt"` | post-hoc; no modifica IJL | ❌ Demasiado tarde |

**Alternativa si no existe evento directo:** si ningún evento del posting de recepción expone
simultáneamente `var ItemJnlLine` y la `Warehouse Receipt Line` correlacionada, la alternativa
es recuperar los datos DUoM desde `Warehouse Receipt Line` durante `OnAfterInitItemLedgEntry`
(codeunit 50104), haciendo un `Get` de la `Warehouse Receipt Line` usando el `Source No.` y
`Source Line No.` disponibles en el `Item Ledger Entry`. Este patrón es más robusto frente a
cambios en el posting pero introduce un lookup adicional.

**⚠️ Verificación obligatoria:** buscar en `WhsePostReceipt.Codeunit.al` todos los eventos
publicados con `[IntegrationEvent]` o `[BusinessEvent]`. Documentar el hallazgo en
`docs/issues/issue-14-warehouse-basic-duom-fields.md` antes de implementar.

### 4.4 Salto 5: Warehouse Shipment Line → Item Journal Line (durante posting)

Análogo al salto 2 pero en `Codeunit "Whse.-Post Shipment"`.

| Candidato | Publisher | Parámetros esperados |
|-----------|-----------|---------------------|
| `OnBeforeCreateWhseJnlLine` | `Codeunit "Whse.-Post Shipment"` | `(var ItemJnlLine, WhseShipmentLine, ...)` |
| `OnAfterCreateItemJnlLineFromShipment` | `Codeunit "Whse.-Post Shipment"` | `(var ItemJnlLine, WhseShipmentLine)` |

**Alternativa si no existe evento directo:** mismo patrón lookup descrito en 4.3 pero
usando `Source No.` / `Source Line No.` de la `Warehouse Shipment Line`.

### 4.5 Salto 6/7: Warehouse Receipt/Shipment Line → Warehouse Activity Line (Issue 15)

| Candidato | Publisher | Parámetros esperados |
|-----------|-----------|---------------------|
| `OnAfterCreatePutAwayLine` | `Codeunit "Create Put-away"` | `(var WhseActivityLine, WhseReceiptLine)` |
| `OnAfterInitFromWhseReceiptLine` | `Table "Warehouse Activity Line"` | `(WhseReceiptLine, var WhseActivityLine)` |
| `OnAfterCreatePickLine` | `Codeunit "Create Pick"` | `(var WhseActivityLine, WhseShipmentLine)` |
| `OnAfterInitFromWhseShipmentLine` | `Table "Warehouse Activity Line"` | `(WhseShipmentLine, var WhseActivityLine)` |

**⚠️ Verificación obligatoria para Issue 15:** buscar en `WhseActivityLine.Table.al`,
`CreatePutaway.Codeunit.al` y `CreatePick.Codeunit.al` antes de implementar.

### 4.6 Salto 8: Warehouse Activity Line → Warehouse Entry (Phase 3/Futuro)

| Candidato | Publisher | Notas |
|-----------|-----------|-------|
| `OnAfterInitFromWhseActivityLine` | `Table "Warehouse Entry"` | Verificar existencia |
| `OnBeforeInsertWhseEntry` | `Codeunit "Whse. Jnl.-Register Line"` | Candidato alternativo |

> **Nota Phase 3:** `Warehouse Entry` es inmutable tras inserción. Si el evento no expone
> `var WhseEntry` antes del `Insert()`, no habrá forma de propagarlo sin `Modify()`, lo que
> requeriría permiso adicional en SaaS. Evaluar la viabilidad antes de comprometerse.

### 4.7 Resumen de candidatos de eventos

| Salto | Evento candidato preferido | Publisher | Verificado BC 27 |
|-------|--------------------------|-----------|-----------------|
| 1 | `OnAfterInitFromPurchLine` | `Table "Warehouse Receipt Line"` | ⏳ Pendiente verificación |
| 2 | `OnAfterCreateItemJnlLine*` o alternativa lookup | `Codeunit "Whse.-Post Receipt"` | ⏳ Pendiente verificación |
| 4 | `OnAfterInitFromSalesLine` | `Table "Warehouse Shipment Line"` | ⏳ Pendiente verificación |
| 5 | `OnAfterCreateItemJnlLine*` o alternativa lookup | `Codeunit "Whse.-Post Shipment"` | ⏳ Pendiente verificación |
| 6 | `OnAfterInitFromWhseReceiptLine` o `OnAfterCreatePutAwayLine` | Table/Codeunit | ⏳ Pendiente Issue 15 |
| 7 | `OnAfterInitFromWhseShipmentLine` o `OnAfterCreatePickLine` | Table/Codeunit | ⏳ Pendiente Issue 15 |
| 8 | `OnAfterInitFromWhseActivityLine` | `Table "Warehouse Entry"` | ⏳ Phase 3 |

---

## 5. Riesgos de permisos y performance SaaS

### 5.1 Riesgos de permisos

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------|---------|-----------|
| Permiso `M` (Modify) requerido sobre `Warehouse Receipt Line` en SaaS al propagar campos | Media | Alto (error en tiempo de ejecución) | Usar eventos `OnAfterInit*` que exponen `var Rec` **antes** del `Insert()`. El patrón ya está establecido en el proyecto (Issue 6/7). Si el evento no existe en BC 27, documentar y buscar alternativa. |
| Permiso `M` sobre `Warehouse Shipment Line` | Media | Alto | Mismo patrón que el punto anterior. |
| Permiso `M` sobre `Warehouse Activity Line` | Media | Alto | Misma mitigación. |
| Permiso `M` sobre `Warehouse Entry` | Alta | Alto | `Warehouse Entry` es inmutable; cualquier propagación post-Insert requiere `Modify()`, que en SaaS puede fallar. **Solución recomendada:** no extender `Warehouse Entry` a menos que el evento pre-Insert exista. Usar ILE como fuente de verdad. |
| Permiso `R` sobre `Warehouse Receipt Line` para lookup en `OnAfterInitItemLedgEntry` | Baja | Medio | Añadir `tabledata "Warehouse Receipt Line" = R` al permission set si se usa el patrón lookup. |
| Scope de permission set — tablas base de BC | N/A | Medio | Las tablas base de BC no requieren entrada `tabledata` en permission sets de PTE excepto cuando se leen directamente (R) o modifican (M) desde la extensión. Verificar para cada tabla nueva. |

**Regla general del proyecto para permisos WMS:**

1. Si el evento expone `var Rec` antes del `Insert()` → asignación directa, sin permisos extra.
2. Si se requiere lookup (lectura) de la tabla base → añadir `tabledata ... = R` en el permission set.
3. Si se requiere `Modify()` → añadir `tabledata ... = M` Y documentar por qué no se pudo usar patrón pre-Insert.
4. Nunca usar `Permissions` property en codeunits (AL0246).

### 5.2 Riesgos de performance

| Riesgo | Escenario | Probabilidad | Mitigación |
|--------|-----------|-------------|-----------|
| Lookup de `Warehouse Receipt Line` en `OnAfterInitItemLedgEntry` por cada ILE | Empresas con alto volumen de movimientos de almacén | Media | Guardia `if DUoMEnabled then ...` antes del `Get`. El `Get` por clave primaria es O(1). Aceptable para SaaS con BC 27. |
| Subscriber `OnAfterInitFromPurchLine` llamado N veces por receipt (una por línea) | Documentos con muchas líneas | Baja | El subscriber es thin (una asignación de 2 campos). Impacto negligible. |
| Table extension en `Warehouse Activity Line` con muchas líneas de put-away/pick | Almacenes grandes | Baja | Los campos son Decimal (8 bytes). Impacto de almacenamiento insignificante. |
| `Get` sobre `Warehouse Shipment Line` durante posting de expedición | Expediciones con N líneas | Media | Mismo patrón lookup — O(1) por línea. Aceptable. |
| Scanning de `Warehouse Entry` para totales DUoM (si se implementa Phase 3) | Informes de inventario | Alta | Añadir `FlowField` o `SumIndexField` si se necesitan agregados. No implementar en Phase 2. |

### 5.3 Riesgos de compatibilidad BC 27

| Riesgo | Probabilidad | Mitigación |
|--------|-------------|-----------|
| Evento `OnAfterInitFromPurchLine` no existe en `Table "Warehouse Receipt Line"` en BC 27 | Media | Buscar alternativa en `Codeunit "Whse.-Get Receipt"`. Si tampoco existe, documentar y usar patrón lookup desde ILE. |
| Nombre de página `Warehouse Receipt Subform` incorrecto en BC 27 | Alta | Verificar en Symbol Reference ANTES de crear pageextension. Error AL0247 bloquea compilación completa. |
| Firma de evento con parámetros distintos a los esperados | Media | Verificar siempre en `microsoft/ALAppExtensions` antes de codificar. Incluir comentario de validación en cada `[EventSubscriber]`. |
| Eventos de posting de almacén cambiados entre BC 27 y versiones anteriores | Media | Usar BC 27 / runtime 15 como referencia única. No asumir compatibilidad con BC 25/26. |

---

## 6. Estrategia de tests mínimos WMS

### 6.1 Prerequisitos de infraestructura de tests

Antes de escribir tests WMS, verificar la disponibilidad de:

| Librería | ID (Tests-TestLibraries) | Disponibilidad esperada |
|----------|--------------------------|------------------------|
| `Library - Warehouse` | ~130516 | Alta — comprobar nombre exacto en BC 27 |
| `Library - Purchase` | 130512 | ✅ Disponible (Phase 1) |
| `Library - Sales` | 130509 | ✅ Disponible (Phase 1) |
| `Library - Inventory` | 132201 | ✅ Disponible (Phase 1) |
| `DUoM Test Helpers` | 50208 | ✅ Disponible |

Si `Library - Warehouse` no existe bajo ese nombre en BC 27, buscar `Library - Warehouse Management`
o crear helpers mínimos en `DUoM Test Helpers` (50208) documentando la excepción.

### 6.2 Setup de Location para tests WMS

Todo test WMS necesita una `Location` configurada con almacén habilitado. Usar
`Library - Warehouse` para crear la Location en lugar de construirla manualmente.

Configuración mínima para almacén básico (Issue 14):

```al
// Almacén básico: Require Receive + Require Shipment
LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
Location."Require Receive" := true;
Location."Require Shipment" := true;
Location.Modify(true);
```

Configuración mínima para almacén dirigido (Issue 15):

```al
// Almacén dirigido: Require Receive + Require Put-away + Require Shipment + Require Pick
LibraryWarehouse.CreateFullWMSLocation(Location, 2);  // 2 bins
// O crear manualmente con todos los flags habilitados
```

### 6.3 Matriz de tests mínimos — Issue 14 (Warehouse Basic)

| Test | ID | Flujo | Modo | Verificación |
|------|----|-------|------|-------------|
| Propagación Purchase → Receipt (Fixed) | T01 | Compra | Fixed | `WhseRcptLine.DUoM Second Qty` = `PurchLine.DUoM Second Qty` |
| Posting Receipt → ILE (Fixed) | T02 | Compra | Fixed | `ILE.DUoM Second Qty` = valor correcto; `ILE.DUoM Ratio` = ratio |
| Posting Receipt → ILE (Variable) | T03 | Compra | Variable | `ILE.DUoM Second Qty` propagado desde Purchase Line |
| Propagación Sales → Shipment (Fixed) | T04 | Venta | Fixed | `WhseShptLine.DUoM Second Qty` = `SalesLine.DUoM Second Qty` |
| Posting Shipment → ILE (Fixed) | T05 | Venta | Fixed | `ILE.DUoM Second Qty` = valor correcto (negativo) |
| Sin DUoM activo — sin impacto | T06 | Compra/Venta | N/A | `WhseRcptLine.DUoM Second Qty = 0`; flujo BC sin cambios |
| *(Recomendado)* Lot Ratio en Receipt | T07 | Compra | AlwaysVariable | `ILE.DUoM Second Qty` calculado via `TryApplyLotRatioToILE` |

**Codeunit de tests:** `DUoM Warehouse Tests` (ID 50218).

### 6.4 Matriz de tests mínimos — Issue 15 (Directed Put-Away & Pick)

| Test | ID | Flujo | Verificación |
|------|----|-------|-------------|
| Put-Away desde Receipt (Fixed) | T01 | Put-Away | `WhseActivityLine.DUoM Second Qty` = valor desde Receipt Line |
| Pick desde Shipment (Fixed) | T02 | Pick | `WhseActivityLine.DUoM Second Qty` = valor desde Shipment Line |
| Put-Away + Post Receipt → ILE | T03 | E2E compra | `ILE.DUoM Second Qty` correcto tras registro completo de put-away |
| Pick + Post Shipment → ILE | T04 | E2E venta | `ILE.DUoM Second Qty` correcto tras registro completo de pick |
| Sin DUoM activo — sin impacto | T05 | N/A | `WhseActivityLine.DUoM Second Qty = 0` |

**Codeunit de tests:** `DUoM Directed WMS Tests` (ID sugerido: 50219).

### 6.5 Patrón de test WMS (template)

```al
[Test]
procedure WarehouseReceipt_FixedMode_DUoMPropagatedFromPurchLine()
var
    Item: Record Item;
    DUoMSetup: Record "DUoM Item Setup";
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    WarehouseReceiptHeader: Record "Warehouse Receipt Header";
    WarehouseReceiptLine: Record "Warehouse Receipt Line";
    Location: Record Location;
begin
    // [GIVEN] Location con Require Receive = true
    // ...

    // [GIVEN] Artículo con DUoM activo (modo Fixed, ratio 2.5)
    LibraryInventory.CreateItem(Item);
    DUoMTestHelpers.EnableDUoMOnItem(Item, Enum::"DUoM Conversion Mode"::Fixed, 2.5);

    // [GIVEN] Purchase Order con 10 unidades → DUoM Second Qty = 25
    LibraryPurchase.CreatePurchaseHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
    LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader,
        PurchaseLine.Type::Item, Item."No.", 10);

    // [WHEN] Crear Warehouse Receipt desde Purchase Order
    LibraryWarehouse.CreateWhseReceiptFromPO(PurchaseHeader);

    // [THEN] Warehouse Receipt Line tiene DUoM Second Qty = 25
    WarehouseReceiptLine.SetRange("Source No.", PurchaseHeader."No.");
    WarehouseReceiptLine.FindFirst();
    LibraryAssert.AreEqual(25, WarehouseReceiptLine."DUoM Second Qty",
        'DUoM Second Qty should be propagated from Purchase Line');
    LibraryAssert.AreEqual(2.5, WarehouseReceiptLine."DUoM Ratio",
        'DUoM Ratio should be propagated from Purchase Line');
end;
```

### 6.6 Cobertura de tests E2E existente y nuevos huecos

| Flujo | Cobertura Phase 1 | Hueco WMS |
|-------|------------------|-----------|
| Purchase → ILE (sin almacén) | ✅ T01–T04 en DUoMILEIntegrationTests | — |
| Sales → ILE (sin almacén) | ✅ T05–T08 en DUoMILEIntegrationTests | — |
| Purchase → Whse Receipt → ILE | ❌ No cubierto | Issue 14 T01–T03 |
| Sales → Whse Shipment → ILE | ❌ No cubierto | Issue 14 T04–T06 |
| Whse Receipt → Put-Away → ILE | ❌ No cubierto | Issue 15 T01–T03 |
| Whse Shipment → Pick → ILE | ❌ No cubierto | Issue 15 T02–T04 |

---

## 7. Plan de implementación incremental

### Incremento 1 — Issue 14: Almacén básico (Warehouse Receipt / Shipment)

**Prerequisitos:** verificación de eventos BC 27 (saltos 1, 2, 4, 5).

**Objetos nuevos:**

| Objeto | Tipo | ID | Descripción |
|--------|------|----|-------------|
| `DUoM Whse. Receipt Line Ext` | tableextension | 50123 | Campos DUoM en Warehouse Receipt Line |
| `DUoM Whse. Shipment Line Ext` | tableextension | 50124 | Campos DUoM en Warehouse Shipment Line |
| `DUoM Whse. Receipt Subform` | pageextension | TBD | Columnas DUoM en subformulario recepción |
| `DUoM Whse. Shipment Subform` | pageextension | TBD | Columnas DUoM en subformulario expedición |
| `DUoM Warehouse Subscribers` | codeunit | 50109 | Subscribers thin para propagación WMS |
| `DUoM Warehouse Tests` | test codeunit | 50218 | Tests T01–T06 (mínimo) + T07 |

> **Nota sobre IDs:** verificar conflictos de ID en el estado actual del backlog antes de asignar.
> Los IDs 50122–50123 pueden estar tomados por otros objetos (verificar `docs/06-backlog.md`
> sección de notas de IDs).

**Pasos de implementación (TDD):**

1. Verificar eventos BC 27 en `microsoft/ALAppExtensions` para los 4 saltos.
2. Documentar hallazgos en `docs/issues/issue-14-warehouse-basic-duom-fields.md`.
3. Escribir tests T01–T06 en estado fallando.
4. Implementar table extensions (50123, 50124) → compilación pasa.
5. Implementar page extensions → UI tests pasan.
6. Implementar subscribers (50109) + métodos en `DUoM Doc Transfer Helper` (50105) → tests de propagación pasan.
7. Actualizar permission sets (DUoMAll + DUoMTestAll).
8. Actualizar ambos XLF.
9. Actualizar documentación (`03-technical-architecture.md`, `02-functional-design.md`, `06-backlog.md`).

### Incremento 2 — Issue 15: Almacén dirigido (Put-Away & Pick)

**Prerequisito:** Issue 14 completado y verificado.

**Objetos nuevos:**

| Objeto | Tipo | ID sugerido | Descripción |
|--------|------|------------|-------------|
| `DUoM Whse. Activity Line Ext` | tableextension | 50125 | Campos DUoM en Warehouse Activity Line |
| `DUoM Whse. Activity Subform` | pageextension | TBD | Columnas DUoM en subformulario actividad |
| `DUoM Directed WMS Subscribers` | codeunit | 50110 | Subscribers para put-away/pick (≤30 chars) |
| `DUoM Directed WMS Tests` | test codeunit | 50219 | Tests T01–T05 |

> **Nombre del codeunit:** verificar que el nombre no exceda 30 caracteres.
> `DUoM Directed WMS Subscribers` = 31 chars → ajustar. Sugerencia: `DUoM Directed Subscribers` (25 chars).

### Incremento 3 — Phase 3/Futuro: Warehouse Entry + Posted Lines

Sólo implementar si:
1. Existe un evento pre-Insert en `Table "Warehouse Entry"` que exponga `var WhseEntry`.
2. El equipo aprueba el diseño técnico y los riesgos de permisos.
3. Existe un caso de negocio claro para rastrear DUoM en `Warehouse Entry` (vs. ILE como fuente de verdad).

---

## 8. In / Out scope del primer incremento WMS

### ✅ In scope — Issue 14

| Funcionalidad | Decisión |
|--------------|---------|
| `DUoM Second Qty` y `DUoM Ratio` en `Warehouse Receipt Line` | ✅ In scope |
| `DUoM Second Qty` y `DUoM Ratio` en `Warehouse Shipment Line` | ✅ In scope |
| Propagación `Purchase Line` → `Warehouse Receipt Line` | ✅ In scope |
| Propagación `Sales Line` → `Warehouse Shipment Line` | ✅ In scope |
| Propagación `Warehouse Receipt Line` → `Item Journal Line` → `ILE` | ✅ In scope |
| Propagación `Warehouse Shipment Line` → `Item Journal Line` → `ILE` | ✅ In scope |
| UI: columnas en subformulario de recepción/expedición (solo lectura) | ✅ In scope |
| Permission sets actualizados | ✅ In scope |
| Tests T01–T06 en `DUoM Warehouse Tests` (50218) | ✅ In scope |
| Documentación técnica y funcional actualizada | ✅ In scope |
| Localización en-US y es-ES para nuevas cadenas | ✅ In scope |

### ❌ Out of scope — Issue 14

| Funcionalidad | Issue / Fase |
|--------------|--------------|
| `Warehouse Activity Line` (put-away/pick) | Issue 15 |
| `Warehouse Entry` con campos DUoM | Phase 3 / Futuro |
| `Posted Whse. Receipt Line` / `Posted Whse. Shipment Line` | Evaluar en Issue 14; si requiere Modify() → Futuro |
| Soporte N-lotes en almacén vía Item Tracking | Phase 3 / Futuro |
| Transfer Orders | Phase 3 |
| Assembly Orders | Fuera de alcance permanente |
| Campos DUoM editables en líneas de almacén (siempre solo lectura) | Fuera de alcance |
| Integración con Physical Inventory en almacén | Issue 17 |

### ✅ In scope — Issue 15

| Funcionalidad | Decisión |
|--------------|---------|
| `DUoM Second Qty` y `DUoM Ratio` en `Warehouse Activity Line` | ✅ In scope |
| Propagación `Warehouse Receipt Line` → `Warehouse Activity Line` (Put-Away) | ✅ In scope |
| Propagación `Warehouse Shipment Line` → `Warehouse Activity Line` (Pick) | ✅ In scope |
| UI: columna DUoM en subformulario de put-away/pick (solo lectura) | ✅ In scope |
| Tests T01–T05 en `DUoM Directed WMS Tests` (50219) | ✅ In scope |

### ❌ Out of scope — Issue 15

| Funcionalidad | Decisión |
|--------------|---------|
| `Registered Whse. Activity Line` con campos DUoM | Phase 3 |
| Movimientos internos (Internal Put-Away / Pick) | Evaluar post-Issue 15 |
| `Warehouse Entry` | Phase 3 |

---

## 9. Referencias

| Documento | Relación |
|-----------|---------|
| `docs/02-functional-design.md` | Diseño funcional general DUoM; sección a actualizar con flujo WMS |
| `docs/03-technical-architecture.md` | Arquitectura técnica; SaaS-Safe Principles; patrón thin subscriber |
| `docs/05-testing-strategy.md` | Reglas TDD; jerarquía de test helpers |
| `docs/06-backlog.md` | Issues 14, 15 y tarea futura N-lotes en almacén |
| `docs/issues/issue-14-warehouse-basic-duom-fields.md` | Especificación detallada de Issue 14 |
| `docs/01-scope-mvp.md` | Scope Phase 2 (Warehouse) y Phase 3 |
| [microsoft/ALAppExtensions](https://github.com/microsoft/ALAppExtensions) | Fuente de verdad para eventos y firmas BC 27 |
| `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al` (50104) | `OnAfterInitItemLedgEntry` — ya implementado, reutilizar en WMS |
| `app/src/codeunit/DUoMDocTransferHelper.Codeunit.al` (50105) | Helper centralizado de copia — extender con métodos WMS |

---

> **Responsable del blueprint:** equipo DualUoM-BC
>
> **Próxima acción:** verificar existencia y firma de los eventos candidatos (sección 4)
> en `microsoft/ALAppExtensions` para BC 27 antes de comenzar la implementación de Issue 14.
> Documentar los hallazgos en `docs/issues/issue-14-warehouse-basic-duom-fields.md`.
