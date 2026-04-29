# Issue 14 — Campos DUoM en documentos de almacén básico (Warehouse Receipt / Shipment)

## 1. Título propuesto

**DualUoM — Issue 14: Campos DUoM en Warehouse Receipt Line y Warehouse Shipment Line**

---

## 2. Objetivo

Extender los documentos de entrada y salida de almacén básico (`Warehouse Receipt Line` y
`Warehouse Shipment Line`) con los campos `DUoM Second Qty` y `DUoM Ratio`, propagarlos
desde el pedido de origen (`Purchase Line` / `Sales Line`) al crear las líneas de almacén,
y asegurar que al contabilizar la recepción / expedición de almacén el `Item Ledger Entry`
recibe los valores DUoM correctos.

---

## 3. Contexto

### Estado actual del repositorio

- **Phase 1 (Issues 1–10):** ✅ Completada — flujo completo compra/venta/diario→ILE→históricos.
- **Issue 11 (Rounding):** ✅ — precisión de redondeo aplicada a `DUoM Second Qty`.
- **Issue 11b (Variants):** ✅ — jerarquía Item → Variante con `DUoM Setup Resolver`.
- **Issue 12 (Coste/Precio):** ✅ — `DUoM Unit Cost` y `DUoM Unit Price` en líneas y históricos.
- **Issue 13 (Lot Ratio):** ✅ — `DUoM Lot Ratio` (table 50102), `TryApplyLotRatioToILE` en posting.
- **Issues 20, 21 (Modelo 1:N):** ✅ — modelo multi-lote correcto consolidado.
- **Warehouse (Issue 14):** ❌ Pendiente — no existen table extensions ni subscribers de almacén.

### Motivación funcional

En empresas con almacén habilitado (opción "Require Receive" / "Require Shipment" en la
Location), el flujo de compra y venta no pasa directamente por Purchase/Sales Line → ILE,
sino por:

```
Purchase Line  →  Warehouse Receipt Line  →  Post Receipt  →  Item Journal Line  →  ILE
Sales Line     →  Warehouse Shipment Line →  Post Shipment →  Item Journal Line  →  ILE
```

Sin la extensión en `Warehouse Receipt Line` / `Warehouse Shipment Line`:
- Los campos `DUoM Second Qty` y `DUoM Ratio` nunca llegan al `Item Journal Line` generado
  durante el posting de almacén.
- El ILE queda con `DUoM Second Qty = 0` aunque el Purchase/Sales Line sí tenga los valores.
- El operador de almacén no puede ver ni confirmar la segunda cantidad en la pantalla de
  recepción o expedición.

### Dependencias completadas

Todos los issues previos (1–13, 20, 21) están completados. Este issue puede comenzarse
directamente.

---

## 4. Alcance

### Dentro del alcance

- Table extension en `Warehouse Receipt Line` (50122) con campos `DUoM Second Qty` y
  `DUoM Ratio` (solo lectura — propagados desde la línea de pedido origen).
- Table extension en `Warehouse Shipment Line` (50123) con los mismos campos.
- Page extension en el subformulario de `Warehouse Receipt` (50111) — solo lectura.
- Page extension en el subformulario de `Warehouse Shipment` (50112) — solo lectura.
- Nuevo codeunit `DUoM Warehouse Subscribers` (50109):
  - Subscriber para propagar DUoM desde `Purchase Line` → `Warehouse Receipt Line` al
    crear/inicializar la línea de recepción de almacén.
  - Subscriber para propagar DUoM desde `Sales Line` → `Warehouse Shipment Line` al
    crear/inicializar la línea de expedición de almacén.
  - Subscriber para propagar DUoM desde `Warehouse Receipt Line` → `Item Journal Line`
    durante el posting de almacén, de modo que `OnAfterInitItemLedgEntry` (ya implementado
    en 50104) reciba los datos correctos y los copie al ILE.
  - Subscriber equivalente para expedición: `Warehouse Shipment Line` → `Item Journal Line`.
- Actualización de `DUoM Doc Transfer Helper` (50105): nuevos métodos de copia de campos
  DUoM para los flujos de almacén (thin subscriber pattern).
- Actualización de permission sets:
  - `app/src/permissionset/DUoMAll.PermissionSet.al` (50100)
  - `test/src/permissionset/DUoMTestAll.PermissionSet.al` (50200)
- Tests TDD: nuevo codeunit `DUoM Warehouse Tests` (50218) con mínimo 6 tests.
- Actualización de ambos XLF (`en-US` y `es-ES`) si se introducen Captions o ToolTips
  en campos de las table/page extensions.
- Documentación actualizada en el mismo PR.

### Fuera del alcance

- Almacén dirigido (Directed Put-Away and Pick) → Issue 15.
- `Warehouse Activity Line` → Issue 15.
- `Warehouse Entry` con campos DUoM → tareas futuras.
- Documentos de devolución de almacén → Issue 16.
- Transfer Orders → Phase 3.
- Assembly Orders → fuera de alcance MVP.
- Lot-level DUoM en warehouse (N lotes vía Item Tracking Lines en almacén) → tarea futura.

---

## 5. Requisitos funcionales

### RF-01 — Campos DUoM visibles en Warehouse Receipt

Al crear una línea de `Warehouse Receipt` desde un `Purchase Order` con DUoM activo, los
campos `DUoM Second Qty` y `DUoM Ratio` de la `Purchase Line` origen deben aparecer (solo
lectura) en la línea de recepción de almacén. El operador puede ver la segunda cantidad
esperada antes de contabilizar.

### RF-02 — Campos DUoM visibles en Warehouse Shipment

Mismo comportamiento que RF-01 pero para `Warehouse Shipment` creado desde `Sales Order`.

### RF-03 — Propagación al ILE durante posting de recepción

Al contabilizar (`Post`) un `Warehouse Receipt`:
1. El sistema copia `DUoM Second Qty` y `DUoM Ratio` de la `Warehouse Receipt Line` al
   `Item Journal Line` generado por el posting.
2. El subscriber existente `OnAfterInitItemLedgEntry` (codeunit 50104) copia los valores
   del `Item Journal Line` al `ILE`.
3. El ILE queda con `DUoM Second Qty` y `DUoM Ratio` correctos.

### RF-04 — Propagación al ILE durante posting de expedición

Mismo comportamiento que RF-03 pero para `Warehouse Shipment`.

### RF-05 — Modos de conversión respetados

El flujo de almacén respeta los tres modos de conversión definidos en `DUoM Setup`:
- **Fixed:** `DUoM Second Qty = Qty × FixedRatio` (propagado desde Purchase/Sales Line).
- **Variable:** `DUoM Second Qty` y `DUoM Ratio` copiados tal cual desde la línea origen.
- **AlwaysVariable:** `DUoM Second Qty` = 0 en la línea de almacén (el usuario introduce
  la cantidad real en el Purchase/Sales Line antes de crear la recepción).

### RF-06 — Artículos sin DUoM activo: sin impacto

Para artículos con `Dual UoM Enabled = false`, los campos DUoM quedan a 0 y el subscriber
no realiza ninguna acción. El flujo estándar de BC no se ve afectado.

---

## 6. Requisitos técnicos

### RT-01 — Table extension `DUoM Whse. Receipt Line Ext` (50122)

- Extiende `Warehouse Receipt Line` (tabla estándar de BC 27).
- Campos:
  - `DUoM Second Qty` (Decimal, ID de campo 50100): `Caption`, `DataClassification = CustomerContent`.
  - `DUoM Ratio` (Decimal, ID de campo 50101): idem.
- Sin triggers `OnValidate` (los campos son de solo propagación, no editables en almacén).
- `LookupPageId` y `DrillDownPageId` no necesarios.

### RT-02 — Table extension `DUoM Whse. Shipment Line Ext` (50123)

- Extiende `Warehouse Shipment Line` (tabla estándar de BC 27).
- Mismos campos que RT-01.

### RT-03 — Page extension subformulario Warehouse Receipt (50111)

> **⚠️ Verificación obligatoria:** antes de crear esta page extension, confirmar el nombre
> exacto de la página de subformulario de `Warehouse Receipt` en BC 27 usando el Symbol
> Reference de VS Code o `microsoft/ALAppExtensions`. El nombre puede ser
> `"Whse. Receipt Subform"`, `"Warehouse Receipt Subform"` u otro — AL0247 bloquea la
> compilación si el nombre no es exacto. Documentar el nombre verificado en el fichero
> de la page extension como comentario.

- Tipo de extensión: `pageextension 50111`.
- Añade columnas `DUoM Second Qty` y `DUoM Ratio` al repeater (solo lectura, no editables).
- ToolTip de cada campo: `Label` con `Comment` propiedad.

### RT-04 — Page extension subformulario Warehouse Shipment (50112)

> **⚠️ Verificación obligatoria:** misma validación que RT-03 para el nombre exacto de la
> página de subformulario de `Warehouse Shipment` en BC 27. Puede ser `"Whse. Shipment Subform"`,
> `"Warehouse Shipment Subform"` u otro.

- Tipo de extensión: `pageextension 50112`.
- Mismas columnas que RT-03.

### RT-05 — Codeunit `DUoM Warehouse Subscribers` (50109)

- `Access = Internal`.
- Subscribers de propagación Purchase → Warehouse Receipt:
  - Identificar el evento correcto en BC 27 para cuando `Warehouse Receipt Line` se
    inicializa desde `Purchase Line`. Candidatos: `OnAfterInitFromPurchLine` en
    `Table "Warehouse Receipt Line"`, o eventos en `Codeunit "Whse.-Get Receipt"` /
    `Codeunit "Create Receipts"`. **Verificar firma exacta en BC 27 Symbol Reference
    antes de codificar.**
  - El subscriber debe ser thin: solo delega a `DUoM Doc Transfer Helper`.
- Subscriber equivalente Sales → Warehouse Shipment:
  - Candidatos: `OnAfterInitFromSalesLine` en `Table "Warehouse Shipment Line"`, o
    evento en `Codeunit "Whse.-Get Shipment"`. **Verificar en BC 27.**
- Subscribers de propagación al Item Journal Line durante posting:
  - Para recepciones: evento en `Codeunit "Whse.-Post Receipt"` que exponga el
    `Item Journal Line` generado y la `Warehouse Receipt Line` origen. Candidato:
    `OnBeforeCreateWhseJnlLine` o similar. **Verificar en BC 27.**
  - Para expediciones: evento equivalente en `Codeunit "Whse.-Post Shipment"`.
  - **Si los eventos no existen en BC 27:** documentar el hallazgo, proponer la
    alternativa correcta (p.ej., via `OnAfterInitItemLedgEntry` con lookup hacia
    `Warehouse Entry` o `Warehouse Receipt Line`) y actualizar este documento antes
    de implementar.

> **Regla del proyecto:** toda firma de EventSubscriber debe incluir un comentario que
> indique el publisher (tabla o codeunit, nombre e ID), el nombre del evento, por qué
> se eligió ese evento, y la confirmación de que la firma fue validada contra BC 27.

### RT-06 — Nuevos métodos en `DUoM Doc Transfer Helper` (50105)

Siguiendo el patrón thin subscriber del proyecto, añadir:

```al
procedure CopyFromPurchLineToWhseRcptLine(
    PurchaseLine: Record "Purchase Line";
    var WhseReceiptLine: Record "Warehouse Receipt Line")

procedure CopyFromSalesLineToWhseShptLine(
    SalesLine: Record "Sales Line";
    var WhseShipmentLine: Record "Warehouse Shipment Line")

procedure CopyFromWhseRcptLineToItemJnlLine(
    WhseReceiptLine: Record "Warehouse Receipt Line";
    var ItemJournalLine: Record "Item Journal Line")

procedure CopyFromWhseShptLineToItemJnlLine(
    WhseShipmentLine: Record "Warehouse Shipment Line";
    var ItemJournalLine: Record "Item Journal Line")
```

Cada método verifica que los campos DUoM no sean ambos cero antes de copiar (optimización
para artículos sin DUoM activo).

### RT-07 — Permission sets

- Añadir en `DUoMAll.PermissionSet.al` (50100):
  ```al
  tabledata "Warehouse Receipt Line" = RIMD,
  tabledata "Warehouse Shipment Line" = RIMD,
  ```
- Añadir las mismas entradas en `DUoMTestAll.PermissionSet.al` (50200).

> **Nota:** verificar si BC SaaS requiere permiso `M` sobre estas tablas base al asignar
> campos en un subscriber `OnAfterInit*`. Si el evento expone `var Rec` antes del Insert(),
> no se necesita `Modify` (patrón ya establecido en el proyecto para `Purch. Rcpt. Line` y
> `Sales Shipment Line`). Si el evento requiere un `Modify()` posterior, añadir el permiso
> y documentar la razón.

### RT-08 — IDs de objetos

| Objeto | Tipo | ID |
|--------|------|----|
| `DUoM Whse. Receipt Line Ext` | tableextension | **50122** |
| `DUoM Whse. Shipment Line Ext` | tableextension | **50123** |
| `DUoM Whse. Receipt Subform` | pageextension | **50111** |
| `DUoM Whse. Shipment Subform` | pageextension | **50112** |
| `DUoM Warehouse Subscribers` | codeunit | **50109** |
| `DUoM Warehouse Tests` | test codeunit | **50218** |

> **Verificar antes de usar:** que los IDs 50122, 50123 de tableextension y 50111, 50112 de
> pageextension, 50109 de codeunit y 50218 de test codeunit no hayan sido tomados por un
> issue paralelo. La fuente de verdad es el estado actual de `docs/06-backlog.md`.

### RT-09 — Localization

- Todos los campos nuevos en table extensions con `Caption` como `Label` y propiedad `Comment`.
- ToolTips en page extensions como `Label` con `Comment`.
- Ambos XLF actualizados en el mismo PR:
  - `app/Translations/DualUoM-BC.en-US.xlf`
  - `app/Translations/DualUoM-BC.es-ES.xlf`
- Si los campos son solo de propagación (sin interacción directa del usuario), un `Caption`
  y `ToolTip` mínimos son suficientes; no se requieren mensajes de error adicionales.

### RT-10 — TDD estricto

- Escribir el codeunit `DUoM Warehouse Tests` (50218) con todos los tests en estado
  **fallando** antes de implementar el código de producción.
- Usar `// [GIVEN] / [WHEN] / [THEN]` en cada test.
- `Subtype = Test; TestPermissions = Disabled;` en el codeunit.
- Usar `LibraryPurchase`, `LibrarySales`, `LibraryWarehouse` (si existe en Tests-TestLibraries)
  y `DUoM Test Helpers` para setup de datos.
- Verificar si existe `Library - Warehouse` (o `Library - Warehouse Management`) en
  `Tests-TestLibraries` antes de crear lógica manual de setup de almacén.

### RT-11 — Longitud de nombres de objetos (≤ 30 caracteres)

| Nombre propuesto | Longitud | Estado |
|-----------------|----------|--------|
| `DUoM Whse. Receipt Line Ext` | 29 chars | ✅ |
| `DUoM Whse. Shipment Line Ext` | 30 chars | ✅ (límite exacto) |
| `DUoM Whse. Receipt Subform` | 27 chars | ✅ |
| `DUoM Whse. Shipment Subform` | 28 chars | ✅ |
| `DUoM Warehouse Subscribers` | 27 chars | ✅ |
| `DUoM Warehouse Tests` | 21 chars | ✅ |

> Verificar los nombres finales con la herramienta de conteo antes de abrir el PR.

### RT-12 — Documentación obligatoria

Actualizar en el mismo PR:

- `docs/03-technical-architecture.md`: añadir table extensions 50122/50123 en la tabla
  Object Structure; añadir page extensions 50111/50112; añadir codeunit 50109; añadir
  los nuevos métodos de `DUoM Doc Transfer Helper` (50105).
- `docs/02-functional-design.md`: añadir sección "Flujo de almacén básico" describiendo
  el camino `Purchase/Sales Line → Warehouse Receipt/Shipment Line → Item Journal Line → ILE`.
- `docs/06-backlog.md`: marcar Issue 14 como ✅ IMPLEMENTADO; actualizar tarea futura
  N-lotes para incluir almacén.
- `docs/TestCoverageAudit.md`: añadir `DUoM Whse. Receipt Line Ext` (50122) y
  `DUoM Whse. Shipment Line Ext` (50123) en el inventario de objetos y en la matriz de
  cobertura; registrar `DUoM Warehouse Tests` (50218) en el listado de codeunits de test.
- `docs/issues/issue-14-warehouse-basic-duom-fields.md`: este fichero (actualizar con los
  hallazgos de verificación de eventos y nombres de páginas BC 27).

---

## 7. Exclusiones

| Exclusión | Issue futuro |
|-----------|-------------|
| Almacén dirigido: `Warehouse Activity Line` (put-away / pick) | Issue 15 |
| `Warehouse Entry` con campos DUoM | Tarea futura Phase 3 |
| Documentos de devolución de almacén | Issue 16 |
| Soporte de lote por almacén (N lotes vía Item Tracking en recepción) | Tarea futura |
| Transfer Orders | Phase 3 |
| Assembly Orders | Fuera de alcance MVP |
| Campos en `Posted Warehouse Receipt` / `Posted Warehouse Shipment` | Evaluar en este issue o en Issue 15 |

---

## 8. Checklist de validación (Definition of Done)

### Código y tests

- [ ] **T01** — Crear Warehouse Receipt desde Purchase Order con DUoM (Fixed) →
  `Warehouse Receipt Line.DUoM Second Qty` = valor correcto propagado desde `Purchase Line`.
- [ ] **T02** — Contabilizar Warehouse Receipt (Fixed) →
  ILE con `DUoM Second Qty` y `DUoM Ratio` correctos.
- [ ] **T03** — Contabilizar Warehouse Receipt (Variable) →
  ILE con `DUoM Second Qty` y `DUoM Ratio` propagados desde la Purchase Line.
- [ ] **T04** — Crear Warehouse Shipment desde Sales Order con DUoM (Fixed) →
  `Warehouse Shipment Line.DUoM Second Qty` = valor correcto propagado desde `Sales Line`.
- [ ] **T05** — Contabilizar Warehouse Shipment (Fixed) →
  ILE con `DUoM Second Qty` y `DUoM Ratio` correctos.
- [ ] **T06** — Artículo sin DUoM activo → Warehouse Receipt/Shipment Line con
  `DUoM Second Qty = 0`; flujo estándar BC sin impacto.
- [ ] *(Recomendado)* **T07** — Contabilizar Warehouse Receipt (Variable, ratio de lote) →
  ILE con `DUoM Second Qty` calculado con el ratio de lote via `TryApplyLotRatioToILE`.

### Calidad

- [ ] Cero warnings de `PerTenantExtensionCop`, `CodeCop` y `UICop`.
- [ ] Sin `with` implícito (`NoImplicitWith`).
- [ ] Sin uso de `Permissions` en codeunits (AL0246).
- [ ] Todos los `Label` tienen propiedad `Comment`.
- [ ] Nombres de objetos ≤ 30 caracteres verificados.
- [ ] Cada `[EventSubscriber]` nuevo incluye comentario de validación de firma BC 27.

### Localización

- [ ] `DualUoM-BC.en-US.xlf` actualizado.
- [ ] `DualUoM-BC.es-ES.xlf` actualizado.
- [ ] O declarado "Not applicable" si no se introducen nuevas cadenas visibles.

### Permission sets

- [ ] `tabledata "Warehouse Receipt Line" = RIMD` en `DUoMAll.PermissionSet.al`.
- [ ] `tabledata "Warehouse Shipment Line" = RIMD` en `DUoMAll.PermissionSet.al`.
- [ ] Mismas entradas en `DUoMTestAll.PermissionSet.al`.

### Documentación

- [ ] `docs/03-technical-architecture.md` actualizado (Object Structure + Event-Based Design).
- [ ] `docs/02-functional-design.md` actualizado (sección Warehouse básico).
- [ ] `docs/06-backlog.md` — Issue 14 marcado ✅ IMPLEMENTADO.
- [ ] `docs/TestCoverageAudit.md` actualizado.
- [ ] `docs/issues/issue-14-warehouse-basic-duom-fields.md` — este fichero actualizado con
  los hallazgos de verificación de eventos y nombres de páginas BC 27.

---

## 9. Riesgos y dependencias

### Dependencias previas (todas completadas)

| Issue | Estado |
|-------|--------|
| Issues 1–10 — Phase 1 MVP | ✅ |
| Issue 11 — Rounding Precision | ✅ |
| Issue 11b — Item Variants | ✅ |
| Issue 12 — Coste/Precio | ✅ |
| Issue 13 — Lot Ratio | ✅ |
| Issues 20/21 — Modelo 1:N consolidado | ✅ |

### Riesgos técnicos

| Riesgo | Probabilidad | Mitigación |
|--------|-------------|-----------|
| Eventos de inicialización de `Warehouse Receipt Line` desde `Purchase Line` no existen o tienen firma diferente en BC 27 | Media | Verificar obligatoriamente en Symbol Reference o `microsoft/ALAppExtensions` antes de implementar. Si no existe `OnAfterInitFromPurchLine` en `Warehouse Receipt Line`, buscar el evento correcto en `Codeunit "Whse.-Get Receipt"` o tabla `Warehouse Receipt`. Documentar hallazgo en el fichero de issue. |
| Eventos de posting de `Warehouse Receipt` → `Item Journal Line` no exponen `var ItemJournalLine` accesible | Media | Si el evento no expone el `Item Journal Line` con la `Warehouse Receipt Line` correlacionada, evaluar alternativa via `Warehouse Entry` + lookup en `OnAfterInitItemLedgEntry`. El mecanismo `TryApplyLotRatioToILE` (50108) ya hace lookup a `DUoM Lot Ratio` desde el ILE; el mismo patrón puede usarse para recuperar datos DUoM de almacén desde el ILE. |
| Nombres de páginas BC 27 (`Warehouse Receipt Subform`, etc.) diferentes a los esperados | Alta | Verificar en Symbol Reference antes de crear pageextensions. Usar el nombre exacto. AL0247 es error de compilación. |
| Permission `M` requerido sobre `Warehouse Receipt Line` / `Warehouse Shipment Line` en SaaS | Baja-Media | Si el subscriber usa `var Rec` antes del Insert(), no se necesita Modify. Si se requiere Modify(), añadir el permiso y documentar. El patrón `OnAfterInitFrom*` del proyecto evita Modify(). |
| Librería `Library - Warehouse` no disponible en Tests-TestLibraries | Baja | Verificar su existencia. Si no está disponible, crear helpers mínimos de setup de almacén en `DUoM Test Helpers` (50208) siguiendo las reglas del proyecto sobre test data creation. |
| Conflicto de IDs si se usa 50122/50123 en otro issue paralelo | Muy baja | Confirmar en el estado actual de `docs/06-backlog.md` antes de crear los objetos. |

---

## 10. Instrucciones adicionales para @copilot

### Paso previo obligatorio — Discovery de eventos BC 27

Antes de escribir ningún subscriber, realizar un discovery de los eventos disponibles en
BC 27 para los flujos de almacén:

1. **Buscar en `microsoft/ALAppExtensions`** los siguientes objetos para identificar eventos
   publicados (con `[IntegrationEvent]` o `[BusinessEvent]`):
   - `Table "Warehouse Receipt Line"` — ¿existe `OnAfterInitFromPurchLine`?
   - `Table "Warehouse Shipment Line"` — ¿existe `OnAfterInitFromSalesLine`?
   - `Codeunit "Whse.-Post Receipt"` — ¿qué eventos expone antes/después de crear el IJL?
   - `Codeunit "Whse.-Post Shipment"` — ídem.
   - `Codeunit "Whse.-Get Receipt"` / `"Whse.-Get Shipment"` — ¿eventos al crear líneas?

2. **Verificar nombres de páginas:**
   - Subformulario de `Warehouse Receipt` → nombre exacto en BC 27.
   - Subformulario de `Warehouse Shipment` → nombre exacto en BC 27.

3. **Documentar los hallazgos** en este fichero de issue antes de abrir el PR de implementación.

### Estrategia TDD

1. Configurar una Location con `Require Receive = true` y `Require Shipment = true` en
   los tests. Usar `Library - Warehouse` si existe.
2. Escribir los tests T01–T06 en estado fallando (los fields DUoM no existen aún en las
   table extensions).
3. Implementar las table extensions (50122, 50123) → los tests de compilación pasan.
4. Implementar los subscribers → los tests de propagación pasan.
5. Verificar tests E2E de posting (T02, T03, T05).

### Patrón thin subscriber

Seguir el mismo patrón ya establecido en el proyecto:

```al
// Suscriptor thin — solo valida y delega a DUoM Doc Transfer Helper
[EventSubscriber(ObjectType::Table, Database::"Warehouse Receipt Line",
                 'OnAfterInitFromPurchLine', '', false, false)]
local procedure OnAfterInitWhseRcptLineFromPurchLine(
    PurchLine: Record "Purchase Line";
    var WhseReceiptLine: Record "Warehouse Receipt Line")
begin
    // Publisher: Table "Warehouse Receipt Line" (verificar ID en BC 27)
    // Evento: OnAfterInitFromPurchLine
    // Motivo: inicializa el campo DUoM antes del Insert(), sin necesidad de Modify()
    // Firma verificada contra BC 27 Symbol Reference: [PENDIENTE — verificar antes de implementar]
    DUoMDocTransferHelper.CopyFromPurchLineToWhseRcptLine(PurchLine, WhseReceiptLine);
end;
```

> **Nota:** si el evento correcto no es `OnAfterInitFromPurchLine` sino otro, actualizar
> el comentario con el nombre real verificado.

### Regla de propagación al ILE

El camino preferido es:

```
Warehouse Receipt Line (DUoM fields)
    ↓ subscriber en el evento de posting que genera IJL
Item Journal Line (DUoM fields)
    ↓ suscriptor existente OnAfterInitItemLedgEntry en 50104
Item Ledger Entry (DUoM fields)
```

Si no existe un evento que exponga `var ItemJournalLine` correlacionado con la
`Warehouse Receipt Line` durante el posting, documentar el bloqueo y proponer como
alternativa extender `OnAfterInitItemLedgEntry` en 50104 para hacer lookup hacia
`Warehouse Entry` o `Warehouse Receipt Line` usando los datos del ILE en curso.

---

## 11. Referencias

- Issue 9: patrón `OnAfterInitFromPurchLine` / `OnAfterInitFromSalesLine` en tablas de
  históricos — base para el mismo patrón en warehouse.
- Issue 10: extensión de históricos de factura/abono — mismo patrón.
- `docs/03-technical-architecture.md`: sección "Propagación de DUoM a históricos" y
  "Patrón thin subscriber".
- `docs/06-backlog.md`: Issue 14 en Phase 2 — descripción de alcance original.
- `docs/02-functional-design.md`: diseño funcional actual (sin warehouse todavía).
- `microsoft/ALAppExtensions`: fuente de verdad de eventos y firmas BC 27.

---

## 12. Etiquetas

`enhancement` `phase-2` `warehouse` `tdd` `al` `propagation`

---

*Documento generado como propuesta de siguiente tarea a partir del análisis del estado real
del repositorio a fecha 2026-04-29: Issues 1–13, 20, 21 completados; ningún objeto de
almacén existe en el repositorio.*
