# Issue 9 — Campos DUoM en líneas de documentos contabilizados y tests de integración end-to-end (Phase 1 Closure)

## Contexto

El scope del MVP ([docs/01-scope-mvp.md](../01-scope-mvp.md)) establece explícitamente:

> **Purchase Lines** — second quantity field on purchase order lines and **receipt lines**
> **Sales Lines** — second quantity field on sales order lines and **shipment lines**

La implementación actual (Issues 4–8) cubre:

- ✅ Líneas de pedido de compra (`Purchase Line`)
- ✅ Líneas de pedido de venta (`Sales Line`)
- ✅ Líneas de diario de almacén (`Item Journal Line`)
- ✅ Movimientos de producto (`Item Ledger Entry`)

Pero **faltan**:

- ❌ Líneas de albarán de compra contabilizado (`Purch. Rcpt. Line`) — tabla 121
- ❌ Líneas de envío de venta contabilizado (`Sales Shipment Line`) — tabla 111

Además, `docs/05-testing-strategy.md` requiere, como **condición previa** al inicio de Phase 2:

> 4. Purchase posting — ILE contains correct second qty after posting a purchase receipt
> 5. Sales posting — ILE contains correct second qty after posting a sales shipment
> 6. Item journal posting — ILE contains correct second qty after posting an item journal line

Ninguno de estos tests de integración end-to-end existe todavía. `DUoMInventoryTests` (50207) los difiere explícitamente indicando "requires a BC Docker environment".

Este issue cierra Phase 1 completando las superficies de documentos contabilizados y añadiendo los tests de integración de contabilización requeridos.

---

## Objetivo

1. Hacer visibles los campos `DUoM Second Qty` y `DUoM Ratio` en:
   - El albarán de compra contabilizado (líneas de `Purch. Rcpt. Line`)
   - El envío de venta contabilizado (líneas de `Sales Shipment Line`)
2. Propagar dichos campos desde las líneas de origen durante la contabilización.
3. Añadir tests de integración end-to-end que verifiquen la propagación completa hasta el `Item Ledger Entry` y los documentos contabilizados.

---

## Diseño funcional

### Flujo de compra

```
Purchase Line  ──►  Purch. Rcpt. Line  ──►  Item Journal Line  ──►  ILE
(DUoM Ratio,        (DUoM Ratio,             (propagado por          (propagado por
 DUoM Second Qty)    DUoM Second Qty)          OnPurchPostCopy...)     OnAfterInitItemLedgEntry)
```

El evento `OnAfterInsertReceiptLine` (Codeunit `Purch.-Post`) proporciona acceso simultáneo a `PurchaseLine` y `PurchRcptLine`, lo que permite copiar los campos DUoM en un solo subscriber.

### Flujo de venta

```
Sales Line  ──►  Sales Shipment Line  ──►  Item Journal Line  ──►  ILE
(DUoM Ratio,     (DUoM Ratio,               (propagado por          (propagado por
 DUoM Second Qty) DUoM Second Qty)            OnSalesPostCopy...)     OnAfterInitItemLedgEntry)
```

El evento `OnAfterInsertShipmentLine` (Codeunit `Sales-Post`) proporciona el mismo patrón.

### Campos en documentos contabilizados

Los campos son **de sólo lectura** en las páginas de albarán/envío (inmutables tras la contabilización, igual que los campos de `ILE`).

---

## Entregables

### Tablas — tableextension

| Archivo | ID | Tabla extendida |
|---|---|---|
| `DUoMPurchRcptLine.TableExt.al` | 50114 | `Purch. Rcpt. Line` |
| `DUoMSalesShipmentLine.TableExt.al` | 50115 | `Sales Shipment Line` |

Campos en cada extensión:

- `field(50100; "DUoM Second Qty"; Decimal)` — `DecimalPlaces = 0:5`, `DataClassification = CustomerContent`
- `field(50101; "DUoM Ratio"; Decimal)` — `DecimalPlaces = 0:5`, `DataClassification = CustomerContent`

### Subscribers — DUoMInventorySubscribers.Codeunit.al (50104)

Añadir dos nuevos subscribers al codeunit existente:

- `OnAfterInsertReceiptLine` en `Purch.-Post` → copia `DUoM Second Qty` y `DUoM Ratio` de `PurchaseLine` a `PurchRcptLine`.
- `OnAfterInsertShipmentLine` en `Sales-Post` → copia `DUoM Second Qty` y `DUoM Ratio` de `SalesLine` a `SalesShipmentLine`.

### Páginas — pageextension

| Archivo | ID | Página extendida |
|---|---|---|
| `DUoMPostedPurchRcptSubform.PageExt.al` | 50104 | `Posted Purchase Receipt Subform` |
| `DUoMPostedSalesShipSubform.PageExt.al` | 50105 | `Posted Sales Shipment Subform` |

Ambas extensiones añaden `DUoM Second Qty` (read-only, con `CaptionClass` dinámico para mostrar el código de la segunda UoM) y `DUoM Ratio` (read-only) tras el campo `Quantity`. Aplicar el mismo patrón de `OnAfterGetRecord` que las pageextensions existentes.

### Tests de integración end-to-end — codeunit 50209

Nuevo codeunit `"DUoM ILE Integration Tests"` (ID 50209):

| Procedimiento de test | Qué verifica |
|---|---|
| `PurchasePosting_FixedMode_ILEHasDUoMFields` | Contabilizar un pedido de compra → ILE tiene `DUoM Second Qty` y `DUoM Ratio` correctos |
| `PurchasePosting_FixedMode_PurchRcptLineHasDUoMFields` | Contabilizar un pedido de compra → `Purch. Rcpt. Line` contiene los campos DUoM propagados |
| `SalesPosting_FixedMode_ILEHasDUoMFields` | Contabilizar un pedido de venta → ILE tiene `DUoM Second Qty` y `DUoM Ratio` correctos |
| `SalesPosting_FixedMode_SalesShipmentLineHasDUoMFields` | Contabilizar un pedido de venta → `Sales Shipment Line` contiene los campos DUoM propagados |
| `ItemJournalPosting_FixedMode_ILEHasDUoMFields` | Contabilizar un diario de almacén → ILE tiene `DUoM Second Qty` y `DUoM Ratio` correctos |
| `PurchasePosting_DUoMDisabled_ILEFieldsAreZero` | Ítem sin DUoM habilitado → ILE no contiene valores DUoM tras la contabilización |

Usar `LibraryPurchase.PostPurchaseDocument`, `LibrarySales.PostSalesDocument` y
`LibraryInventory.PostItemJournalLine` para la contabilización.
Seguir el patrón `// [GIVEN] / [WHEN] / [THEN]` y `TestPermissions = Disabled`.

### Localización

Actualizar **ambos** ficheros XLF con las nuevas cadenas Caption/ToolTip de las dos
`tableextension` y las dos `pageextension`. No dejar ningún `trans-unit` en estado
`needs-translation`. Obtener los IDs correctos desde `DualUoM-BC.g.xlf` del artefacto
compilado (ver `docs/07-localization.md`).

### Permission sets

Las `tableextension` sobre tablas BC estándar (`Purch. Rcpt. Line`, `Sales Shipment Line`)
**no** requieren entradas en los permission sets. No se añaden nuevas tablas custom (`table`),
por lo que `DUoMAll.PermissionSet.al` y `DUoMTestAll.PermissionSet.al` no necesitan cambios
en este issue.

---

## Criterios de aceptación

- [ ] Los campos `DUoM Second Qty` y `DUoM Ratio` aparecen (read-only) en el subformulario del albarán de compra contabilizado.
- [ ] Los campos `DUoM Second Qty` y `DUoM Ratio` aparecen (read-only) en el subformulario del envío de venta contabilizado.
- [ ] Al contabilizar un pedido de compra para un ítem con DUoM en modo Fixed, la `Purch. Rcpt. Line` resultante contiene los mismos valores DUoM que la `Purchase Line`.
- [ ] Al contabilizar un pedido de venta para un ítem con DUoM en modo Fixed, la `Sales Shipment Line` resultante contiene los mismos valores DUoM que la `Sales Line`.
- [ ] Al contabilizar un pedido de compra, el `Item Ledger Entry` resultante contiene `DUoM Second Qty` y `DUoM Ratio` correctos.
- [ ] Al contabilizar un pedido de venta, el `Item Ledger Entry` resultante contiene `DUoM Second Qty` y `DUoM Ratio` correctos.
- [ ] Al contabilizar una línea de diario de almacén, el `Item Ledger Entry` resultante contiene `DUoM Second Qty` y `DUoM Ratio` correctos.
- [ ] Para un ítem sin DUoM habilitado, la contabilización no altera el comportamiento estándar (campos DUoM = 0 en ILE).
- [ ] Todos los tests del codeunit 50209 pasan en CI.
- [ ] Ambos ficheros XLF actualizados con todas las cadenas nuevas, sin entradas `needs-translation`.
- [ ] Zero warnings en los analizadores `CodeCop`, `PerTenantExtensionCop` y `UICop`.

---

## Dependencias

- **Requiere:** Issues 1–8 completados ✅
- **Bloquea:** Phase 2 — Issue 10 (Lot-Specific Real Ratio)

## Labels sugeridos

`phase-1`, `enhancement`, `testing`
