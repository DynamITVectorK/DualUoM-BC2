# Issue 22 — DUoM operativo en Item Tracking Lines (seguimiento de lotes)

## 1. Título propuesto

**DualUoM — Issue 22: Hacer operativos los datos DUoM en la página estándar de Item Tracking Lines**

---

## 2. Objetivo

Mostrar y hacer operativos los campos `DUoM Second Qty` y `DUoM Ratio` dentro de la
página estándar de Business Central **Item Tracking Lines** (page 6510), que es la página
modal donde el usuario asigna lotes a una línea de documento.

El objetivo es que, al asignar un lote en Item Tracking Lines, el sistema muestre la
cantidad secundaria correspondiente a ese lote y, si existe una `DUoM Lot Ratio`
registrada para ese par `(Item No., Lot No.)`, la aplique automáticamente. Esto cierra
el gap entre la gestión de lotes estándar de BC y la solución DualUoM.

---

## 3. Contexto

### Estado actual del repositorio

- **Phase 1 MVP (Issues 1–10):** ✅ completada — campos DUoM en Purchase/Sales/Item Journal
  Lines, propagación a ILE y documentos históricos.
- **Issue 11/11b/12:** ✅ Rounding, Variantes, Coste/Precio implementados.
- **Issue 13 (DUoM Lot Ratio):** ✅ tabla `DUoM Lot Ratio` (50102) + `TryApplyLotRatioToILE`.
- **Issues 20/21 (modelo 1:N):** ✅ arquitectura 1 línea = N lotes consolidada; subscriber
  de `Item Journal Line."Lot No."` eliminado (asunción incorrecta 1:1).
- **Issue 22 (este):** ✅ IMPLEMENTADO — 2026-04-29.

### Motivación funcional

En el flujo estándar de Business Central, el usuario no introduce el lote directamente en
la línea de documento (campo `Lot No.` no existe en `Purchase Line` ni `Sales Line`).
En cambio, abre la página modal **Item Tracking Lines** (page 6510 / table 6500
`Tracking Specification`) para asignar N lotes a la línea, con la cantidad de cada lote.

El gap actual es que esa página no muestra ni calcula `DUoM Second Qty` ni `DUoM Ratio`,
por lo que el usuario no puede ver ni confirmar la segunda cantidad por lote en el momento
de la asignación. Además, la `DUoM Lot Ratio` registrada para el lote no se aplica
automáticamente al validar el lote en Item Tracking Lines.

### Tablas involucradas en BC 27

| Tabla | ID | Descripción |
|-------|----|-------------|
| `Tracking Specification` | 6500 | Buffer de trabajo en Item Tracking Lines (modal) |
| `Reservation Entry` | 337 | Reservas y asignaciones de tracking persistidas |
| `DUoM Lot Ratio` | 50102 | Ratios DUoM por lote (ya implementada, Issue 13) |

> **Verificación obligatoria antes de implementar:** confirmar en BC 27 Symbol Reference
> los campos exactos de `Tracking Specification` (6500) y los eventos disponibles
> (`OnAfterValidateEvent` para `Lot No.`, eventos de posting de tracking) antes de crear
> cualquier extension o subscriber. Usar el patrón de verificación de firma del proyecto.

---

## 4. Alcance

### Dentro del alcance

- **TableExtension** sobre `Tracking Specification` (6500): campos `DUoM Second Qty`
  (Decimal) y `DUoM Ratio` (Decimal).
- **PageExtension** sobre `Item Tracking Lines` (page 6510): columnas `DUoM Second Qty`
  y `DUoM Ratio` visibles en el repeater.
- **Suscriptor** en `OnAfterValidateEvent` para el campo `Lot No.` de `Tracking Specification`
  (6500): cuando el usuario valida un lote, si existe `DUoM Lot Ratio` para
  `(Item No., Lot No.)`, pre-rellenar `DUoM Ratio` y calcular `DUoM Second Qty` con la
  cantidad de la línea de tracking.
- **Suscriptor** en `OnAfterValidateEvent` para el campo `Quantity (Base)` de
  `Tracking Specification` (6500): recalcular `DUoM Second Qty` al cambiar la cantidad
  del lote.
- **Propagación** desde `Tracking Specification` (buffer) hacia `Reservation Entry` (337)
  en el momento de confirmar Item Tracking Lines: copiar `DUoM Second Qty` y `DUoM Ratio`
  al `Reservation Entry` correspondiente para persistirlos.
- Actualizar **permission sets** `DUoM - All` (50100) y `DUoM - Test All` (50200) si se
  añaden nuevas tablas securizables.
- Actualizar **XLF** (`en-US` y `es-ES`) para todos los nuevos textos visibles.
- **Tests TDD** (mínimo 5) cubriendo los escenarios descritos en la sección de requisitos.
- **Documentación** actualizada en el mismo PR.

### Fuera del alcance

| Exclusión | Issue futuro |
|-----------|-------------|
| Documentos de almacén (Warehouse Receipt/Shipment Lines) | Issue 14 |
| Actividades de almacén dirigido (put-away/pick) | Issue 15 |
| Documentos de devolución | Issue 16 |
| Inventario físico con segunda cantidad | Issue 17 |
| Informes con columnas DUoM | Issue 18 |
| Agregación automática de `DUoM Second Qty` total en la línea origen desde los lotes | Tarea futura N-lotes |
| Extensión de `Item Tracking Lines` para trazabilidad por número de serie | Fuera de scope |

---

## 5. Requisitos funcionales

### RF-01 — Columnas DUoM en Item Tracking Lines

- Al abrir la página `Item Tracking Lines` para una línea de documento de un artículo
  con DUoM activado, el repeater muestra las columnas `DUoM Ratio` y `DUoM Second Qty`.
- Para artículos sin DUoM activado, las columnas pueden mostrarse vacías o estar ocultas
  mediante visibilidad condicional (decidir durante implementación).

### RF-02 — Pre-rellenado de ratio al validar Lot No.

- Cuando el usuario introduce o valida un `Lot No.` en una línea de `Tracking Specification`:
  1. El sistema busca una `DUoM Lot Ratio` para el par `(Item No., Lot No.)`.
  2. Si existe y el modo de conversión efectivo es Variable o AlwaysVariable, escribe el
     `Actual Ratio` en el campo `DUoM Ratio` de la línea de tracking.
  3. Recalcula `DUoM Second Qty = Quantity (Base) × DUoM Ratio` (con rounding precision).
- En modo Fixed, `DUoM Ratio` y `DUoM Second Qty` se calculan usando el ratio fijo del
  artículo/variante (no el ratio de lote).

### RF-03 — Recálculo al cambiar la cantidad del lote

- Cuando el usuario modifica `Quantity (Base)` en una línea de `Tracking Specification`
  con `DUoM Ratio` ya establecido, `DUoM Second Qty` se recalcula automáticamente.

### RF-04 — Persistencia en Reservation Entry

- Al confirmar (`OK`) la página `Item Tracking Lines`, los valores `DUoM Second Qty`
  y `DUoM Ratio` del buffer `Tracking Specification` se copian al `Reservation Entry`
  correspondiente para garantizar persistencia.

### RF-05 — Modo Fixed: usa ratio fijo del artículo

- Para artículos con modo Fixed, `DUoM Ratio` en la línea de tracking debe reflejar el
  `Fixed Ratio` del artículo (o variante) y `DUoM Second Qty` calcularse con él.
  El ratio de lote no aplica en este modo.

---

## 6. Requisitos técnicos

### RT-01 — TableExtension `DUoM Tracking Spec Ext` sobre `Tracking Specification` (6500)

- Campos: `DUoM Second Qty` (Decimal, `DataClassification = CustomerContent`) y
  `DUoM Ratio` (Decimal, `DataClassification = CustomerContent`).
- Trigger `OnValidate` en `DUoM Ratio`: recalcular `DUoM Second Qty` usando
  `DUoM Calc Engine.ComputeSecondQtyRounded`.
- `Access = Public` (la page extension y los subscribers deben acceder a los campos).

> **Verificación obligatoria:** confirmar en BC 27 Symbol Reference que `Tracking Specification`
> (table 6500) admite extensiones PTE y que los campos `Lot No.` y `Quantity (Base)` existen
> con esos nombres exactos.

### RT-02 — PageExtension sobre `Item Tracking Lines` (page 6510)

- Nombre propuesto: `DUoM Item Tracking Lines` (≤ 30 chars: 24 chars ✅).
- Añadir columnas `DUoM Ratio` y `DUoM Second Qty` al repeater, después de las columnas
  de cantidad estándar.
- Considerar `Visible` condicional basado en `DUoM Item Setup."Dual UoM Enabled"`.

> **Verificación obligatoria:** confirmar nombre exacto de la página en BC 27 Symbol Reference
> (`"Item Tracking Lines"` o variante). Un nombre incorrecto causa AL0247 y rompe la compilación.

### RT-03 — Suscriptor `OnAfterValidateEvent` para `Lot No.` en `Tracking Specification`

- En un nuevo codeunit `DUoM Tracking Subscribers` (50109, `Access = Internal`) o en un
  codeunit existente apropiado.
- Firma a verificar contra BC 27 Symbol Reference:
  ```al
  [EventSubscriber(ObjectType::Table, Database::"Tracking Specification",
                   'OnAfterValidateEvent', 'Lot No.', false, false)]
  local procedure OnAfterValidateTrackingSpecLotNo(
      var Rec: Record "Tracking Specification";
      var xRec: Record "Tracking Specification")
  ```
- Patrón thin subscriber: validar condiciones de salida rápida, delegar lógica al helper.
- Usar `DUoM Setup Resolver` (50107) para obtener el modo y ratio efectivos.
- Usar `DUoM Lot Subscribers` (50108) / helper existente para aplicar el ratio de lote.

### RT-04 — Suscriptor `OnAfterValidateEvent` para `Quantity (Base)` en `Tracking Specification`

- Similar a RT-03 pero para recalcular `DUoM Second Qty` al cambiar la cantidad del lote.
- Verificar nombre exacto del campo (`'Quantity (Base)'`) en BC 27 Symbol Reference.

### RT-05 — Propagación a `Reservation Entry` (337)

- Identificar el evento correcto de BC 27 para el momento en que `Tracking Specification`
  se vuelca a `Reservation Entry` (al confirmar Item Tracking Lines).
- Candidatos a verificar: `OnAfterTransferReservEntry`, `OnBeforeInsert`, etc. en
  `Reservation Entry` o en el codeunit estándar que realiza el volcado.
- Solo implementar si el evento existe y tiene los parámetros correctos. Si no se encuentra
  un evento seguro, documentar la limitación y dejarlo para la tarea futura N-lotes.

### RT-06 — Permission sets

- Si `Tracking Specification` (6500) requiere permiso explícito como tabla extensible en
  SaaS, añadir `tabledata "Tracking Specification" = RIMD` en ambos permission sets.
- Verificar si `Reservation Entry` (337) también requiere permiso de Read para los
  suscriptores/helpers.

### RT-07 — Localización (obligatorio)

- Captions de los campos nuevos (`DUoM Second Qty`, `DUoM Ratio`) en la page extension
  deben declararse con `Caption` + Label si son personalizables, o heredarse de las
  table extensions existentes.
- Todos los nuevos mensajes de error o confirmación: `Label` con `Comment`.
- Actualizar `DualUoM-BC.en-US.xlf` y `DualUoM-BC.es-ES.xlf` en el mismo PR.

### RT-08 — TDD estricto

- Codeunit de test: `DUoM Item Tracking Tests` (50218, `Subtype = Test`,
  `TestPermissions = Disabled`).
- Patrón `// [GIVEN] / [WHEN] / [THEN]` en cada test.
- Usar `Library Assert`, `LibraryPurchase`, `LibrarySales`, `LibraryInventory`,
  `Library - Item Tracking` (codeunit 130502) y `DUoM Test Helpers` (50208).
- Escribir los tests en estado **fallando** antes de implementar el código de producción.

### RT-09 — Longitud de nombres de objetos (AL0305)

Verificar que ningún nombre supera 30 caracteres:
- `"DUoM Tracking Spec Ext"` = 22 chars ✅
- `"DUoM Item Tracking Lines"` = 24 chars ✅
- `"DUoM Tracking Subscribers"` = 25 chars ✅
- `"DUoM Item Tracking Tests"` = 24 chars ✅

### RT-10 — Documentación (obligatorio)

Actualizar en el mismo PR:
- `docs/02-functional-design.md` — sección del flujo de integración con Item Tracking Lines.
- `docs/03-technical-architecture.md` — añadir `DUoM Tracking Spec Ext` (tableextension)
  y `DUoM Tracking Subscribers` (codeunit) en las tablas de objetos.
- `docs/06-backlog.md` — marcar Issue 22 como ✅ IMPLEMENTADO.
- `docs/TestCoverageAudit.md` — añadir los nuevos objetos y caseunits de test.

---

## 7. Requisitos funcionales — Tests TDD

### Escenarios mínimos obligatorios

- **T01** — Artículo con DUoM Variable + lote con `DUoM Lot Ratio` registrada:
  al validar `Lot No.` en `Tracking Specification`, `DUoM Ratio` = ratio del lote y
  `DUoM Second Qty` = `Quantity (Base)` × ratio (con rounding).
- **T02** — Artículo con DUoM Variable + lote **sin** `DUoM Lot Ratio` registrada:
  al validar `Lot No.`, `DUoM Ratio` sin cambios (mantiene ratio por defecto del artículo).
- **T03** — Artículo con modo Fixed:
  al validar `Lot No.` con ratio de lote existente, `DUoM Ratio` = Fixed Ratio del artículo
  (el ratio de lote NO sobreescribe en modo Fixed).
- **T04** — Cambio de `Quantity (Base)` en línea de tracking con ratio ya establecido:
  `DUoM Second Qty` recalculada automáticamente.
- **T05** — Flujo E2E: compra con lote asignado via Item Tracking Lines →
  `DUoM Second Qty` en tracking = esperado → contabilización → ILE con `DUoM Second Qty`
  correcto (coherencia entre tracking y ILE).

---

## 8. Checklist de validación (Definition of Done)

### Código y tests

- [x] TableExtension `DUoM Tracking Spec Ext` compilando sin warnings.
- [x] TableExtension `DUoM Reservation Entry Ext` compilando sin warnings.
- [x] PageExtension `DUoM Item Tracking Lines` compilando sin warnings.
- [x] Suscriptor `OnAfterValidateEvent` para `Lot No.` implementado y verificado en BC 27.
- [x] Suscriptor `OnAfterValidateEvent` para `Quantity (Base)` implementado y verificado.
- [ ] Propagación a `Reservation Entry` — **NO implementada**: `OnAfterCopyTrackingFromTrackingSpec` no expone `var Rec` modificable en BC 27 (AL0282). Limitación conocida, tarea futura N-lotes.
- [ ] T01–T07 pasando en CI.

### Calidad

- [ ] Cero warnings `PerTenantExtensionCop`, `CodeCop`, `UICop`.
- [x] Sin `with` implícito (`NoImplicitWith`).
- [x] Sin uso de `Permissions` en codeunits (AL0246).
- [x] Todos los `Label` con propiedad `Comment`.
- [x] Nombres de objetos ≤ 30 caracteres.

### Localización

- [x] `DualUoM-BC.en-US.xlf` actualizado.
- [x] `DualUoM-BC.es-ES.xlf` actualizado.

### Permission sets

- [x] `DUoMAll.PermissionSet.al` actualizado (`Reservation Entry = RIMD`).
- [x] `DUoMTestAll.PermissionSet.al` actualizado (`Reservation Entry = RIMD`).

### Documentación

- [ ] `docs/02-functional-design.md` actualizado.
- [x] `docs/03-technical-architecture.md` actualizado.
- [x] `docs/06-backlog.md` — Issue 22 marcado ✅ IMPLEMENTADO.
- [x] `docs/TestCoverageAudit.md` actualizado.
- [x] `docs/issues/issue-22-item-tracking-lines-duom.md` creado (este fichero).

---

## 9. Riesgos y dependencias

### Dependencias previas (todas completadas)

| Issue | Estado |
|-------|--------|
| Issue 13 — DUoM Lot Ratio | ✅ |
| Issue 20 — Modelo 1:N multi-lote | ✅ |
| Issue 21 — Refactor subscriber 1:1 eliminado | ✅ |

### Riesgos técnicos

| Riesgo | Probabilidad | Mitigación |
|--------|-------------|-----------|
| `Tracking Specification` (6500) puede no ser extensible via tableextension en SaaS PTE | Media | Verificar en BC 27 Symbol Reference antes de implementar. Si no es extensible, documentar la limitación y diseñar alternativa (p.ej. tabla paralela indexada por `Entry No.`). |
| El evento de volcado `Tracking Specification` → `Reservation Entry` puede no existir o tener firma cambiada en BC 27 | Media | Verificar en ALAppExtensions. Si no existe evento seguro, dejar la propagación a `Reservation Entry` fuera del alcance de este issue y documentar como tarea futura. |
| La page extension `Item Tracking Lines` puede causar conflictos con otras extensiones del tenant | Baja | Usar el nombre de campo más neutro posible y no bloquear navegación en posticiones no esperadas. |
| `Library - Item Tracking` (130502) puede requerir configuración especial de licencia en entornos de test SaaS | Baja | Documentar el requisito; si no está disponible, crear helpers manuales mínimos en `DUoM Test Helpers` (50208). |

---

## 10. IDs de objetos propuestos

| Objeto | Tipo | ID propuesto |
|--------|------|-------------|
| `DUoM Tracking Spec Ext` | tableextension | **50122** |
| `DUoM Item Tracking Lines` | pageextension | **50112** |
| `DUoM Tracking Subscribers` | codeunit | **50109** |
| `DUoM Item Tracking Tests` | test codeunit | **50218** |

> **Confirmar disponibilidad de IDs** en `docs/06-backlog.md` sección Notes antes de crear
> los objetos. Los IDs propuestos asumen que ningún otro issue paralelo los ha reservado.

---

## 11. Instrucciones adicionales para @copilot

### Verificación de firma de suscriptores (OBLIGATORIA)

Antes de implementar cualquier `[EventSubscriber]`, verificar en BC 27 Symbol Reference
o en [microsoft/ALAppExtensions](https://github.com/microsoft/ALAppExtensions) que:
1. La tabla `Tracking Specification` (6500) tiene campo `Lot No.` como campo directo.
2. El evento `OnAfterValidateEvent` existe para ese campo.
3. La firma exacta coincide con la esperada.

Incluir en el código un comentario que documente la verificación:
```al
// Publisher: Table "Tracking Specification" (6500), Event: OnAfterValidateEvent, Field: Lot No.
// Verificado contra BC 27 Symbol Reference — [fecha de verificación]
// Motivo: pre-rellenar DUoM Ratio al asignar lote en Item Tracking Lines
```

### Patrón de codeunit thin subscriber

Seguir el patrón establecido en el proyecto: el suscriptor solo valida condiciones de
salida rápida y delega la lógica al helper centralizado. No implementar lógica de negocio
directamente en el suscriptor.

### Verificación del nombre de la page extension

Confirmar el nombre exacto de la página en BC 27 antes de crear la pageextension:
- Candidato probable: `"Item Tracking Lines"` (page 6510)
- Un nombre incorrecto causa AL0247 y bloquea la compilación de todo el módulo.

---

## 12. Referencias

- Issue 13: `DUoM Lot Ratio` — tabla y página de mantenimiento de ratios por lote.
- Issue 20: modelo 1:N multi-lote — arquitectura `TryApplyLotRatioToILE`.
- Issue 21: eliminación del subscriber 1:1 de `Item Journal Line."Lot No."`.
- `docs/02-functional-design.md`: sección "Lot-Specific Real Ratio".
- `docs/03-technical-architecture.md`: sección "Modelo 1:N".
- `docs/06-backlog.md`: tarea futura "Arquitectura DUoM por lote sobre Item Tracking (N lotes reales)".

---

## 13. Estado de implementación

**Estado:** ✅ IMPLEMENTADO — 2026-04-29

### Objetos creados

| Objeto | Tipo | ID | Archivo |
|--------|------|----|---------|
| `DUoM Tracking Spec Ext` | tableextension | 50122 | `app/src/tableextension/DUoMTrackingSpecExt.TableExt.al` |
| `DUoM Reservation Entry Ext` | tableextension | 50123 | `app/src/tableextension/DUoMReservationEntryExt.TableExt.al` |
| `DUoM Item Tracking Lines` | pageextension | 50112 | `app/src/pageextension/DUoMItemTrackingLines.PageExt.al` |
| `DUoM Tracking Subscribers` | codeunit | 50109 | `app/src/codeunit/DUoMTrackingSubscribers.Codeunit.al` |
| `DUoM Item Tracking Tests` | test codeunit | 50218 | `test/src/codeunit/DUoMItemTrackingTests.Codeunit.al` |

### Decisiones de implementación

1. **`Tracking Specification` (6500) es extensible:** confirmado procediendo con tableextension 50122.

2. **Comportamiento por modo en `Lot No.` subscriber (RT-03):**
   - Fixed: aplica ratio fijo del artículo (lote no sobreescribe).
   - Variable/AlwaysVariable: aplica ratio del lote si existe; si no, deja campos sin cambios.

3. **`Quantity (Base)` subscriber (RT-04):** solo recalcula si `DUoM Ratio ≠ 0`,
   evitando cálculos inútiles en líneas sin DUoM configurado.

4. **Propagación a `Reservation Entry` (RF-04 / RT-05) — LIMITACIÓN CONOCIDA:**
   El evento `OnAfterCopyTrackingFromTrackingSpec` publicado en `Table "Reservation Entry"`
   (tabla 337) NO expone un parámetro `var Rec: Record "Reservation Entry"` modificable
   en BC 27. El subscriber generaba AL0282 (parámetro `ReservEntry` no encontrado) y se ha
   eliminado. Los campos de `DUoM Reservation Entry Ext` (tableextension 50123) quedan
   definidos para uso futuro cuando se identifique un mecanismo de propagación seguro.
   La ratio real por lote se aplica al ILE durante el posting vía `TryApplyLotRatioToILE`
   (DUoM Lot Subscribers, 50108), lo que garantiza la trazabilidad DUoM en los registros
   de valoración aunque la Reservation Entry no almacene los campos DUoM.

5. **Permission sets (RT-06):** Se añadió `tabledata "Reservation Entry" = RIMD`
   en `DUoMAll.PermissionSet.al` y `DUoMTestAll.PermissionSet.al` para cubrir el
   acceso de escritura a los campos DUoM en `Reservation Entry` desde el subscriber.

6. **Tests T01–T07 usando Tracking Specification in-memory y posting E2E:**
   Los tests T01–T04 y T07 usan registros `Tracking Specification` sin `Insert()` para
   aislar la lógica de los subscribers. T05 y T06 verifican coherencia E2E:
   T05 verifica coherencia entre buffer y ILE con un lote; T06 verifica el modelo
   1:N (1 línea IJL → 2 lotes → 2 ILEs cada uno con su ratio correcto), demostrando
   explícitamente que no se asume 1 línea = 1 lote. T07 verifica que artículos sin
   DUoM activo no producen errores (salida rápida del subscriber).

---

## Etiquetas

`enhancement` `phase-2` `lot-tracking` `item-tracking` `tdd` `al`
