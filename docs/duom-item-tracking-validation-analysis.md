# Análisis: Ciclo de vida estándar de Item Tracking y puntos de validación DUoM

> **Propósito:** Documento de análisis técnico para identificar los puntos correctos
> donde DualUoM-BC debe validar y propagar los campos DUoM a lo largo del ciclo de vida
> de Item Tracking en Business Central 27 (runtime 15).
>
> **Estado:** Análisis completado. Los eventos identificados aquí ya están implementados
> para el flujo de **Purchase Order** en los codeunits 50109, 50110, 50111 y 50102.
> El documento sirve también como base de diseño para extender la validación al flujo de
> **Sales Order** (pendiente — ver sección 11).

---

## 1. Resumen del flujo estándar de Item Tracking Lines

### 1.1 Apertura de la página

Cuando el usuario abre la página `Item Tracking Lines` (6510) desde un documento
(p.ej. Purchase Order), BC construye un **buffer temporal** en memoria a partir de los
datos persistidos en `Reservation Entry` (337):

```
Para cada Reservation Entry positiva vinculada a la línea origen:
  BC llama → TrackingSpec.CopyTrackingFromReservEntry(ReservEntry)
  → Evento: Table "Tracking Specification" (6500)
            OnAfterCopyTrackingFromReservEntry
  El buffer TrackingSpec queda en memoria (no en BD)
  → La página muestra los valores del buffer
```

**Consecuencia:** Los campos DUoM que el usuario ve al reabrir la página
proceden de `Reservation Entry`, copiados al buffer `Tracking Specification`
mediante el evento `OnAfterCopyTrackingFromReservEntry` en la Tabla 6500.
La recarga usa `:=` directo, **sin** `Validate`, por lo que no se recalcula
`DUoM Second Qty`. Los valores se conservan exactamente como se persistieron.

### 1.2 Introducción de datos por el usuario

El usuario trabaja con el buffer `Tracking Specification` (6500).
Cada fila del repeater de la página corresponde a un registro de ese buffer.
Al validar `Lot No.` o `Quantity (Base)`, BC dispara los eventos estándar
`OnAfterValidateEvent` sobre la tabla 6500.

DUoM se engancha aquí para:
- Pre-rellenar `DUoM Ratio` desde `DUoM Lot Ratio` al asignar `Lot No.`
- Recalcular `DUoM Second Qty` al cambiar `Quantity (Base)` si hay ratio

### 1.3 Cierre de la página (OK)

Al confirmar la página, BC llama `RegisterChange` que, para una nueva entrada
(INSERT), ejecuta internamente los siguientes pasos:

```
PASO 1 — CopyTrackingFromSpec
  ReservEntry1.CopyTrackingFromSpec(OldTrackingSpec)
  → Evento: Table "Reservation Entry" (337)
            OnAfterCopyTrackingFromTrackingSpec
  → ReservEntry1 recibe DUoM Ratio y DUoM Second Qty del buffer

PASO 2 — CopyTrackingFromReservEntry
  CreateReservEntry.CreateReservEntryFor(..., ForReservEntry = ReservEntry1)
  → internamente: InsertReservEntry.CopyTrackingFromReservEntry(ReservEntry1)
  → Evento: Table "Reservation Entry" (337)
            OnAfterCopyTrackingFromReservEntry
  → InsertReservEntry recibe los valores DUoM de ReservEntry1

PASO 3 — Insert
  CreateReservEntry.CreateEntry(...) → InsertReservEntry.Insert()
  → Reservation Entry queda en BD con DUoM Ratio y DUoM Second Qty correctos ✓
```

> **Nota:** El Paso 2 era el eslabón faltante (corregido en bug/tracking-flow).
> Sin el subscriber `OnAfterCopyTrackingFromReservEntry` en Table "Reservation Entry",
> `InsertReservEntry` quedaba con `DUoM Ratio = 0` aunque ReservEntry1 ya lo tuviera.

### 1.4 Flujo de posting (Purchase Order → ILE)

Durante la contabilización de una Purchase Order con Item Tracking:

```
Purchase Line + Reservation Entries (por lote)
  → Codeunit "Purch.-Post" (90)
  → Item Journal Line preparada
    (OnPostItemJnlLineOnAfterCopyDocumentFields se dispara aquí)
  → Codeunit "Item Jnl.-Post Line" (22)
  → Para cada lote: TempSplitItemJnlLine creada desde TrackingSpec
    → TrackingSpec (buffer del lote) → Item Journal Line split
       Evento: Table "Item Journal Line" (83)
               OnAfterCopyTrackingFromSpec
    → Item Journal Line split → Item Ledger Entry
       Evento: Table "Item Ledger Entry" (32)
               OnAfterCopyTrackingFromItemJnlLine
```

---

## 2. Objetos estándar implicados

### 2.1 Tablas

| Tabla | ID | Rol en el flujo |
|-------|----|----------------|
| `Tracking Specification` | 6500 | Buffer temporal de Item Tracking Lines. Contiene una fila por lote durante la sesión interactiva. No persiste tras cerrar la página: los datos viajan a Reservation Entry (INSERT) o se descartan (CANCEL). |
| `Reservation Entry` | 337 | **Fuente de verdad persistente** entre la apertura/cierre de Item Tracking Lines y el momento del posting. Una entrada positiva por cada lote asignado en la línea de documento origen. |
| `Item Journal Line` | 83 | Línea de movimiento usada por posting. En flujos con Item Tracking, se divide en N líneas (`TempSplitItemJnlLine`), una por lote. Transitoria: no persiste tras el posting. |
| `Item Ledger Entry` | 32 | Registro definitivo e inmutable del movimiento de inventario por lote. Fuente de verdad tras el posting. |
| `Item Tracking Code` | 6502 | Define la configuración de trazabilidad del artículo (Lot Specific Tracking, SN Specific Tracking, etc.). |
| `Lot No. Information` | 6505 | Información adicional por lote (descripción, fecha caducidad, etc.). |

### 2.2 Pages

| Page | ID | Rol |
|------|----|-----|
| `Item Tracking Lines` | 6510 | Página interactiva de captura y revisión de asignaciones de lote/serie. Usa tabla 6500 como SourceTable. |

### 2.3 Codeunits estándar clave

| Codeunit | ID | Rol |
|----------|----|-----|
| `Item Tracking Management` | 6500 | Gestión del ciclo de vida de Item Tracking: apertura/cierre de la página, RegisterChange, sincronización con Reservation Entry. |
| `Create Reserv. Entry` | 312 | Crea Reservation Entries en BD. Internamente llama `CopyTrackingFromReservEntry` antes del Insert final. |
| `Purch.-Post` | 90 | Contabilización de Purchase Orders. Publica `OnPostItemJnlLineOnAfterCopyDocumentFields`. |
| `Item Jnl.-Post Line` | 22 | Procesamiento de Item Journal Lines. Realiza el split por lote (TempSplitItemJnlLine) y llama a `InitItemLedgEntry`. |
| `Item Tracking Lines` | 6500 *(page codeunit)* | Controlador de la página 6510. Gestiona el buffer de Tracking Specification durante la sesión interactiva. |

### 2.4 Eventos estándar en tablas (patrón Package Management / Codeunit 6516)

BC 27 publica los siguientes eventos estándar para propagar campos de tracking
personalizados entre tablas, siguiendo el patrón de `Codeunit 6516 "Package Management"`:

| Tabla publicadora | Evento | Firma (BC 27 / runtime 15) |
|-------------------|--------|---------------------------|
| `Reservation Entry` (337) | `OnAfterCopyTrackingFromTrackingSpec` | `(var ReservationEntry: Record "Reservation Entry"; TrackingSpecification: Record "Tracking Specification")` |
| `Reservation Entry` (337) | `OnAfterCopyTrackingFromReservEntry` | `(var ReservationEntry: Record "Reservation Entry"; FromReservationEntry: Record "Reservation Entry")` |
| `Reservation Entry` (337) | `OnAfterClearTracking` | `(var ReservationEntry: Record "Reservation Entry")` |
| `Reservation Entry` (337) | `OnAfterClearNewTracking` | `(var ReservationEntry: Record "Reservation Entry")` |
| `Tracking Specification` (6500) | `OnAfterCopyTrackingFromReservEntry` | `(var TrackingSpecification: Record "Tracking Specification"; ReservEntry: Record "Reservation Entry")` |
| `Tracking Specification` (6500) | `OnAfterCopyTrackingFromTrackingSpec` | `(var TrackingSpecification: Record "Tracking Specification"; FromTrackingSpecification: Record "Tracking Specification")` |
| `Tracking Specification` (6500) | `OnAfterCopyTrackingFromItemLedgEntry` | `(var TrackingSpecification: Record "Tracking Specification"; ItemLedgerEntry: Record "Item Ledger Entry")` |
| `Tracking Specification` (6500) | `OnAfterClearTracking` | `(var TrackingSpecification: Record "Tracking Specification")` |
| `Tracking Specification` (6500) | `OnAfterSetTrackingBlank` | `(var TrackingSpecification: Record "Tracking Specification")` |
| `Item Journal Line` (83) | `OnAfterCopyTrackingFromSpec` | `(var ItemJournalLine: Record "Item Journal Line"; TrackingSpecification: Record "Tracking Specification")` |
| `Item Journal Line` (83) | `OnAfterCopyTrackingFromItemLedgEntry` | `(var ItemJournalLine: Record "Item Journal Line"; ItemLedgEntry: Record "Item Ledger Entry")` |
| `Item Ledger Entry` (32) | `OnAfterCopyTrackingFromItemJnlLine` | `(var ItemLedgerEntry: Record "Item Ledger Entry"; ItemJnlLine: Record "Item Journal Line")` |
| `Item Ledger Entry` (32) | `OnAfterCopyTrackingFromNewItemJnlLine` | `(var ItemLedgerEntry: Record "Item Ledger Entry"; ItemJnlLine: Record "Item Journal Line")` |

> **Fuente de verificación:** Todas las firmas anteriores se han verificado contra
> `Codeunit 6516 "Package Management"` y la implementación de BC 27 (runtime 15).
> No asumir nombres: confirmar siempre en AL Symbol Reference antes de usar.

### 2.5 Eventos estándar en codeunits

| Codeunit publicadora | Evento | Firma (BC 27 / runtime 15) |
|---------------------|--------|---------------------------|
| `Purch.-Post` (90) | `OnPostItemJnlLineOnAfterCopyDocumentFields` | `(var ItemJournalLine: Record "Item Journal Line"; PurchaseLine: Record "Purchase Line")` |
| `Sales-Post` (80) | `OnPostItemJnlLineOnAfterCopyDocumentFields` | `(var ItemJournalLine: Record "Item Journal Line"; SalesLine: Record "Sales Line")` |
| `Item Jnl.-Post Line` (22) | `OnAfterInitItemLedgEntry` | `(var ItemLedgerEntry: Record "Item Ledger Entry"; ItemJournalLine: Record "Item Journal Line"; ...)` |

---

## 3. Objetos DUoM existentes en el repositorio

### 3.1 Table Extensions

| Objeto | ID | Tabla extendida | Campos añadidos |
|--------|----|----------------|----------------|
| `DUoM Tracking Spec Ext` | 50122 | `Tracking Specification` (6500) | `DUoM Second Qty`, `DUoM Ratio` (con trigger OnValidate para recálculo) |
| `DUoM Reservation Entry Ext` | 50123 | `Reservation Entry` (337) | `DUoM Second Qty`, `DUoM Ratio` |
| `DUoM Purchase Line Ext` | 50110 | `Purchase Line` | `DUoM Second Qty`, `DUoM Ratio`, `DUoM Unit Cost` |
| `DUoM Sales Line Ext` | 50111 | `Sales Line` | `DUoM Second Qty`, `DUoM Ratio`, `DUoM Unit Price` |
| `DUoM Item Journal Line Ext` | 50112 | `Item Journal Line` (83) | `DUoM Second Qty`, `DUoM Ratio` |
| `DUoM Item Ledger Entry Ext` | 50113 | `Item Ledger Entry` (32) | `DUoM Second Qty`, `DUoM Ratio` |

### 3.2 Page Extensions

| Objeto | ID | Página extendida | Funcionalidad |
|--------|----|-----------------|---------------|
| `DUoM Item Tracking Lines` | 50112 | `Item Tracking Lines` (6510) | Añade columnas `DUoM Ratio` y `DUoM Second Qty` al repeater. OnValidate de cada campo llama a `ValidateTrackingSpecLine` para feedback inmediato. |

### 3.3 Codeunits de suscriptores

| Codeunit | ID | Responsabilidad |
|----------|----|----------------|
| `DUoM Tracking Subscribers` | 50109 | `OnAfterValidateEvent` para `Lot No.` y `Quantity (Base)` en Tracking Specification. Auto-rellena DUoM Ratio desde DUoM Lot Ratio al asignar lote; recalcula DUoM Second Qty cuando cambia Quantity (Base). |
| `DUoM Tracking Copy Subscribers` | 50110 | Cadena completa `OnAfterCopyTracking*`: TrackSpec→ReservEntry, ReservEntry→ReservEntry, ReservEntry→TrackSpec, TrackSpec→IJL, IJL→ILE, ILE→IJL. También Clear/Blank en TrackSpec y ReservEntry. |
| `DUoM Tracking Coherence Mgt` | 50111 | Validación centralizada de coherencia DUoM. Métodos públicos: `ValidatePurchLineTrackingCoherence`, `ValidateTrackingSpecLine`, `CalcTrackingDUoMTotalsForPurchLine`, `AssertRatioCoherence`. |
| `DUoM Purchase Subscribers` | 50102 | Contiene el guard de validación pre-posting en `OnPostItemJnlLineOnAfterCopyDocumentFields` de `Purch.-Post` (90). Llama a `ValidatePurchLineTrackingCoherence`. |

---

## 4. Fuente persistente real de los campos DUoM

### 4.1 Durante la sesión interactiva (página abierta)

| Tabla | ¿Persiste en BD? | Observaciones |
|-------|-----------------|---------------|
| `Tracking Specification` (6500) | **No** — buffer en memoria | Vive solo durante la sesión de la página 6510. Se descarta al cancelar o al confirmar (los datos viajan a Reservation Entry). |
| `Reservation Entry` (337) | **Sí** — fuente de verdad | Una vez confirmada la página (OK), los datos DUoM se copian aquí. Persisten hasta el posting. |

### 4.2 Después de cerrar la página (OK)

`Reservation Entry` (337) con los campos `DUoM Ratio` y `DUoM Second Qty`
(tableextension 50123) es la **fuente de verdad** antes del posting.

Vinculación a la línea de documento origen:

| Campo en Reservation Entry | Valor para Purchase |
|---------------------------|---------------------|
| `Source Type` | `Database::"Purchase Line"` (38) |
| `Source Subtype` | `PurchLine."Document Type".AsInteger()` |
| `Source ID` | `PurchHeader."No."` |
| `Source Ref. No.` | `PurchLine."Line No."` |
| `Lot No.` | Lote asignado |
| `Positive` | `true` |

### 4.3 Al reabrir la página

BC reconstruye el buffer `Tracking Specification` desde las `Reservation Entry`
existentes vía `OnAfterCopyTrackingFromReservEntry` en Table "Tracking Specification".
Los campos DUoM se restauran mediante `:=` directo (sin `Validate`), preservando
los valores exactos sin recálculo.

### 4.4 Después del posting

`Item Ledger Entry` (32) con `DUoM Ratio` y `DUoM Second Qty` (tableextension 50113)
es la **fuente de verdad definitiva e inmutable** tras la contabilización.

### 4.5 ¿Se pierden los campos DUoM al cerrar la página?

**No**, siempre que el doble subscriber esté activo:
1. `OnAfterCopyTrackingFromTrackingSpec` en Table "Reservation Entry" → copia TrackSpec→ReservEntry1.
2. `OnAfterCopyTrackingFromReservEntry` en Table "Reservation Entry" → copia ReservEntry1→InsertReservEntry.

Sin el segundo subscriber (bug histórico), los campos se perdían porque
`InsertReservEntry` se insertaba en BD con `DUoM Ratio = 0`.

---

## 5. Eventos candidatos para cada punto de validación

### 5.1 Candidatos para validación al cerrar la página

| Candidato | Objeto | Momento | ¿Acceso a línea origen? | ¿Acceso al conjunto de líneas? | Riesgos |
|-----------|--------|---------|------------------------|-------------------------------|---------|
| `OnValidate` del campo en pageextension | `DUoM Item Tracking Lines` (50112) | Inmediatamente al editar cada campo | Sí (vía SourceRef) | No (solo la línea actual) | Solo valida por línea individual; no calcula suma total |
| `OnAfterValidateEvent` en `Tracking Specification` | Tabla 6500 | Inmediatamente al editar Lot No./Qty | No directamente | No | Igual limitación: solo línea individual |
| `OnAfterRegisterChange` en `Item Tracking Management` | CU 6500 | Al confirmar OK (después de volcar a ReservEntry) | Sí, mediante Source fields | Sí, consultando Reservation Entry filtrando por Source | No está en el patrón estándar confirmado de BC 27; revisar existencia antes de usar |
| `OnClosingPage` / `OnQueryClosePage` en pageextension | `DUoM Item Tracking Lines` (50112) | Antes de cerrar la página | Solo la última línea activa | No (el buffer está en memoria) | Difícil de acceder al conjunto completo de líneas del buffer; no recomendado |

**Conclusión para validación al cerrar:** No existe un evento estándar único en BC 27
que proporcione acceso simultáneo a (a) todas las líneas del buffer y (b) la línea de
documento origen para calcular y comparar la suma DUoM. La validación por línea
individual (OnValidate en pageextension) es el enfoque más seguro y compatible con SaaS.
La validación de la suma total se delega al momento de posting (ver sección 6.2).

---

## 6. Evento recomendado para validación al cerrar la página

### Punto implementado: OnValidate en `DUoM Item Tracking Lines` (pageextension 50112)

**Objeto:** pageextension 50112 `DUoM Item Tracking Lines`  
**Evento:** `trigger OnValidate()` en los campos `DUoM Ratio` y `DUoM Second Qty`  
**Momento:** Inmediatamente al confirmar edición de cualquiera de los dos campos en
la línea de tracking activa.

**Implementación:**
```al
field("DUoM Ratio"; Rec."DUoM Ratio")
{
    trigger OnValidate()
    var
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        DUoMCoherenceMgt.ValidateTrackingSpecLine(Rec);
    end;
}
field("DUoM Second Qty"; Rec."DUoM Second Qty")
{
    trigger OnValidate()
    var
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        DUoMCoherenceMgt.ValidateTrackingSpecLine(Rec);
    end;
}
```

**Variables disponibles:** `Rec: Record "Tracking Specification"` con todos los campos
del buffer de la línea activa (incluyendo `Item No.`, `Variant Code`, `Lot No.`,
`Quantity (Base)`, `DUoM Ratio`, `DUoM Second Qty`).

**¿Accede a la línea origen?** No directamente, pero `DUoM Tracking Coherence Mgt`
puede leer la `Purchase Line` mediante los campos Source de `Tracking Specification`
si fuera necesario.

**¿Accede al conjunto completo de líneas?** No: solo la línea activa. La validación
de suma total requiere consultar `Reservation Entry` (más seguro que iterar el buffer
en memoria) y se ejecuta en el punto de posting.

**Validaciones ejecutadas (`ValidateTrackingSpecLine`):**
- Si `DUoM Ratio = 0` y el modo es `AlwaysVariable` y `Quantity (Base) ≠ 0` → Error.
- Si el modo es `Fixed` y `DUoM Ratio ≠ FixedRatio` → Error.
- Coherencia matemática: `|Qty (Base) × DUoM Ratio − DUoM Second Qty| ≤ Precision`.

**Riesgos:**
- No captura el caso en que el usuario cierra la página sin editar los campos DUoM
  (si los campos ya están pre-rellenados correctamente, no hay riesgo).
- No valida la suma total de todos los lotes vs. `Purchase Line.DUoM Second Qty`;
  esto es responsabilidad del guard de posting.

---

## 7. Evento recomendado para validación antes del posting

### Punto implementado: `OnPostItemJnlLineOnAfterCopyDocumentFields` en `Purch.-Post` (90)

**Objeto:** `Codeunit "Purch.-Post"` (90)  
**Evento:** `OnPostItemJnlLineOnAfterCopyDocumentFields`  
**Firma BC 27 verificada:**
```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post",
    'OnPostItemJnlLineOnAfterCopyDocumentFields', '', false, false)]
local procedure OnPurchPostValidateDUoMTrackingCoherence(
    var ItemJournalLine: Record "Item Journal Line";
    PurchaseLine: Record "Purchase Line")
```

**Momento del posting:** Se dispara una vez por `Purchase Line` después de que los
campos de la línea se copian al `Item Journal Line`, **antes** de crear ningún
`Item Ledger Entry`. En este momento las `Reservation Entries` ya están en BD
(creadas cuando el usuario asignó los lotes vía Item Tracking Lines).

**Variables disponibles:**
- `ItemJournalLine: Record "Item Journal Line"` — el IJL que se está preparando.
- `PurchaseLine: Record "Purchase Line"` — la línea de compra origen (con
  `DUoM Second Qty`, `Document No.`, `Line No.`, `No.`, `Variant Code`).

**¿Accede a la línea origen?** Sí: `PurchaseLine` es un parámetro directo del evento.

**¿Cómo recuperar las tracking lines?** Filtrando `Reservation Entry` (337) por:
```al
ReservEntry.SetRange("Source Type", Database::"Purchase Line");
ReservEntry.SetRange("Source Subtype", PurchaseLine."Document Type".AsInteger());
ReservEntry.SetRange("Source ID", PurchaseLine."Document No.");
ReservEntry.SetRange("Source Ref. No.", PurchaseLine."Line No.");
ReservEntry.SetRange(Positive, true);
```

**Validaciones ejecutadas (`ValidatePurchLineTrackingCoherence`):**
1. Sale si DUoM no está activo para el artículo de la línea.
2. Calcula `SUM(DUoM Second Qty)` y `SUM(Qty (Base))` de todas las Reservation Entries.
3. Si no hay datos DUoM en tracking (total = 0), sale — el artículo puede no usar lot tracking.
4. Si `PurchLine.DUoM Second Qty > 0`: compara la suma con `PurchLine.DUoM Second Qty`.
   Si la diferencia supera la precisión de redondeo → Error con detalle.
5. Por cada Reservation Entry: valida coherencia de ratio y reglas según modo (Fixed/Variable/AlwaysVariable).

**Riesgos:**
- El evento se dispara incluso cuando no hay Item Tracking: la guarda `TotalBaseQty = 0` cubre este caso.
- Si el usuario no abrió Item Tracking Lines y no asignó lotes, las Reservation Entries no existen
  y `TotalBaseQty = 0`; la validación sale silenciosamente (correcto).
- El evento se dispara por línea, no una vez por documento. Para documentos con muchas líneas,
  el costo computacional es lineal en el número de líneas con DUoM activo.

---

## 8. Evento recomendado para propagación al Item Ledger Entry

### Punto implementado: `OnAfterCopyTrackingFromItemJnlLine` en Table "Item Ledger Entry" (32)

**Objeto:** `Table "Item Ledger Entry"` (32)  
**Evento:** `OnAfterCopyTrackingFromItemJnlLine`  
**Firma BC 27 verificada (patrón Package Management, línea 551):**
```al
[EventSubscriber(ObjectType::Table, Database::"Item Ledger Entry",
    'OnAfterCopyTrackingFromItemJnlLine', '', false, false)]
local procedure ILECopyTrackingFromItemJnlLine(
    var ItemLedgerEntry: Record "Item Ledger Entry";
    ItemJnlLine: Record "Item Journal Line")
```

**Momento:** BC lo dispara desde `Item Jnl.-Post Line` (22) cuando copia el tracking
del IJL split al ILE que está a punto de insertar. El ILE tiene ya `Quantity` asignada
(del lote específico). El ILE **no ha sido insertado aún** en BD.

**¿Cómo acceder al ratio correcto del lote?**

La propagación sigue una prioridad definida:

```
1. DUoM Lot Ratio (tabla 50102) — cuando ItemJnlLine."Lot No." <> '' y existe registro
   → Ratio más preciso: el medido por el almacén/proveedor para ese lote.

2. ItemJnlLine."DUoM Ratio" — si no hay registro en 50102 pero IJL tiene ratio
   (viene de TrackingSpec vía OnAfterCopyTrackingFromReservEntry → OnAfterCopyTrackingFromSpec)
   → Ratio del lote introducido por el usuario en Item Tracking Lines.

3. IJL."Lot No." = '' y DUoM Ratio = 0 → AlwaysVariable sin lote:
   copia DUoM Second Qty directamente del IJL total.

4. IJL."Lot No." <> '' y DUoM Ratio = 0 → AlwaysVariable + lote sin ratio:
   reset a 0 (total no válido para ILE individual).
```

**Implementación (codeunit 50110):**
```al
local procedure ILECopyTrackingFromItemJnlLine(
    var ItemLedgerEntry: Record "Item Ledger Entry";
    ItemJnlLine: Record "Item Journal Line")
var
    DUoMLotRatio: Record "DUoM Lot Ratio";
    AppliedRatio: Decimal;
begin
    if (ItemJnlLine."DUoM Ratio" = 0) and (ItemJnlLine."DUoM Second Qty" = 0) then
        exit;
    AppliedRatio := ItemJnlLine."DUoM Ratio";
    if ItemJnlLine."Lot No." <> '' then
        if DUoMLotRatio.Get(ItemJnlLine."Item No.", ItemJnlLine."Lot No.") then
            AppliedRatio := DUoMLotRatio."Actual Ratio";
    ItemLedgerEntry."DUoM Ratio" := AppliedRatio;
    if AppliedRatio <> 0 then
        ItemLedgerEntry."DUoM Second Qty" := Abs(ItemLedgerEntry.Quantity) * AppliedRatio
    else begin
        if ItemJnlLine."Lot No." = '' then
            ItemLedgerEntry."DUoM Second Qty" := ItemJnlLine."DUoM Second Qty"
        else
            ItemLedgerEntry."DUoM Second Qty" := 0;
    end;
end;
```

**Por qué este evento y no otros:**
- **No usar ratio agregado de la línea de compra cuando hay varios lotes:** Cada ILE
  recibe la cantidad exacta de su lote (`ItemLedgerEntry.Quantity`). Usar `PurchLine.DUoM Second Qty`
  o `IJL.DUoM Second Qty` total sería incorrecto para escenarios N-lotes con ratios distintos.
- **No usar `OnAfterInitItemLedgEntry`:** Este evento se dispara antes de
  `OnAfterCopyTrackingFromItemJnlLine`. Puede establecer un valor provisional que
  `ILECopyTrackingFromItemJnlLine` sobrescribirá con el ratio correcto del lote.
  En el flujo sin Item Tracking, `OnAfterInitItemLedgEntry` sigue siendo necesario
  como fallback.

---

## 9. Cadena completa de propagación DUoM (resumen)

```
[Usuario] introduce Lot No. + DUoM Ratio en Item Tracking Lines
  │
  ├── OnAfterValidateEvent 'Lot No.' en TrackingSpec (CU 50109)
  │    → auto-rellena DUoM Ratio desde DUoM Lot Ratio
  │
  ├── OnAfterValidateEvent 'Quantity (Base)' en TrackingSpec (CU 50109)
  │    → recalcula DUoM Second Qty
  │
  └── OnValidate campos DUoM en pageextension (PE 50112)
       → ValidateTrackingSpecLine → coherencia por línea

[Usuario] cierra Item Tracking Lines (OK)
  │
  ├── PASO 1: OnAfterCopyTrackingFromTrackingSpec en Reservation Entry (CU 50110)
  │    → TrackingSpec.DUoM → ReservEntry1.DUoM
  │
  └── PASO 2: OnAfterCopyTrackingFromReservEntry en Reservation Entry (CU 50110)
       → ReservEntry1.DUoM → InsertReservEntry.DUoM
       → InsertReservEntry.Insert() → BD ✓

[Sistema] Contabilización Purchase Order
  │
  ├── OnPostItemJnlLineOnAfterCopyDocumentFields en Purch.-Post (CU 50102)
  │    → ValidatePurchLineTrackingCoherence
  │    → SUM(ReservEntry.DUoM Second Qty) = PurchLine.DUoM Second Qty
  │
  ├── Split por lote (Item Jnl.-Post Line)
  │    ├── OnAfterCopyTrackingFromReservEntry en TrackingSpec (CU 50110)
  │    │    → ReservEntry.DUoM → TrackSpec buffer
  │    └── OnAfterCopyTrackingFromSpec en Item Journal Line (CU 50110)
  │         → TrackSpec.DUoM → IJL split.DUoM
  │
  └── Insert Item Ledger Entry
       └── OnAfterCopyTrackingFromItemJnlLine en Item Ledger Entry (CU 50110)
            → Prioridad: DUoM Lot Ratio > IJL.DUoM Ratio
            → ILE.DUoM Ratio = AppliedRatio
            → ILE.DUoM Second Qty = Abs(ILE.Quantity) × AppliedRatio ✓
```

---

## 10. Riesgos técnicos

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------|---------|------------|
| El usuario cierra Item Tracking Lines sin abrir los campos DUoM | Alta | Bajo — los datos de tracking siguen siendo válidos sin DUoM | Los subscribers aplican DUoM automáticamente cuando el lote está en DUoM Lot Ratio |
| AlwaysVariable + lote sin ratio en DUoM Lot Ratio → ILE con DUoM Second Qty = 0 | Media | Medio | La validación pre-posting alerta antes de crear el ILE; el usuario debe introducir ratio |
| `OnAfterClearTracking` en Item Journal Line: NO implementar | Alta si se implementa | Crítico — rompe cadena IJL→ILE | NO añadir subscriber en este evento para IJL; BC llama ClearTracking() durante Validate("Lot No.") y durante el split |
| Eventos `OnAfterCopyTracking*` pueden cambiar en versiones futuras de BC | Baja | Alto | Patrón documentado por Microsoft en CU 6516 "Package Management"; estable históricamente |
| Suma DUoM en múltiples lotes puede no coincidir por errores de redondeo | Media | Bajo | `AssertRatioCoherence` usa `RoundingPrecision` del UoM secundario como tolerancia |
| Un lote asignado a múltiples líneas origen puede tener DUoM Ratio inconsistente | Media | Medio | La validación se hace por línea, no por lote global; riesgo teórico en escenarios de Split Lot |
| Extensión de flujos WMS (Warehouse Receipt/Shipment) sin campos DUoM | Alta (WMS) | Alto para WMS | Gap conocido; previsto en Issue 14/15 (Phase 2) |

---

## 11. Propuesta de siguiente issue de implementación

### Issue propuesto: Validación y propagación DUoM en flujos de Sales Order con Item Tracking

**Contexto:** El análisis y la implementación actuales cubren el flujo de Purchase Order
con Item Tracking. El mismo ciclo existe para Sales Orders, pero los subscribers
específicos de validación pre-posting no están implementados para ventas.

**Objetivo:** Replicar el mismo patrón de validación y propagación DUoM para el flujo
de Sales Order:

1. **Guard de validación pre-posting en `Sales-Post` (80):**  
   Suscribirse a `OnPostItemJnlLineOnAfterCopyDocumentFields` en `Codeunit "Sales-Post"` (80).
   Firma verificada:  
   `(var ItemJournalLine: Record "Item Journal Line"; SalesLine: Record "Sales Line")`  
   Llamar a un método análogo `ValidateSalesLineTrackingCoherence` en un codeunit
   coherencia que filtre `Reservation Entry` por Source Type = `Database::"Sales Line"`.

2. **Extensión de `DUoM Tracking Coherence Mgt` (50111):**  
   Añadir `ValidateSalesLineTrackingCoherence` con la misma lógica que
   `ValidatePurchLineTrackingCoherence` pero filtrando por Source Type = Sales Line.

3. **Tests TDD:**  
   - Sales Order con dos lotes de ratios distintos → suma DUoM correcta en posting.
   - Sales Order con suma DUoM incorrecta → error pre-posting.
   - AlwaysVariable + lote sin ratio → error pre-posting.

**Dependencias:** No tiene dependencias sobre Issues pendientes. Puede iniciarse después
de cerrar este análisis.

**Objetos afectados:**
- Crear nuevo codeunit `DUoM Sales Subscribers` (nuevo ID en rango 50100-50199) para los
  subscribers específicos de Sales Post. El codeunit 50102 `DUoM Purchase Subscribers`
  debe mantenerse con ese nombre y alcance exclusivamente de compras.
- `DUoM Tracking Coherence Mgt` (50111) → añadir método para Sales Line.
- Test codeunit nueva en rango 50200-50299.

---

## 12. Referencias

| Documento | Contenido relacionado |
|-----------|----------------------|
| `docs/03-technical-architecture.md` | Persistencia DUoM en Item Tracking Lines — flujo de dos pasos al cerrar la página |
| `docs/issues/issue-22-item-tracking-lines-duom.md` | Diseño e implementación de la pageextension y subscribers DUoM en Tracking Specification |
| `docs/issues/issue-190-fix-duom-ratio-reserventry-copy-tracking.md` | Corrección del evento `OnAfterCopyTrackingFromTrackingSpec` en Reservation Entry |
| `docs/issues/issue-23-tracking-copy-subscribers.md` | Cadena completa `OnAfterCopyTracking*` en codeunit 50110 |
| `docs/issues/issue-209-fix-ijlcleartracking-duom-ratio-reset.md` | Por qué NO implementar `OnAfterClearTracking` en Item Journal Line |
| `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al` | Implementación de todos los subscribers de propagación |
| `app/src/codeunit/DUoMTrackingCoherenceMgt.Codeunit.al` | Validación centralizada de coherencia DUoM |
| `app/src/codeunit/DUoMPurchaseSubscribers.Codeunit.al` | Guard de validación pre-posting para Purchase Order |
| `app/src/pageextension/DUoMItemTrackingLines.PageExt.al` | Extensión de UI con validación por línea |
