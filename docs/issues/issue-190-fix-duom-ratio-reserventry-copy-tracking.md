# Issue 190 — fix: propagar DUoM Ratio y DUoM Second Qty a Reservation Entry usando `OnAfterCopyTrackingFromTrackingSpec`

## Contexto

El comentario en `DUoMReservationEntryExt` (50123) afirmaba erróneamente que el evento
`OnAfterCopyTrackingFromTrackingSpec` en tabla `Reservation Entry` (337) no expone un
parámetro `var ReservationEntry` modificable (AL0282). Esto era incorrecto.

La prueba es `codeunit 6516 "Package Management"` del base app de BC, que usa exactamente
ese evento para propagar `Package No.` desde `Tracking Specification` hacia `Reservation Entry`.

## Causa raíz

Sin el subscriber correspondiente, `ReservEntry."DUoM Ratio"` nunca recibía el valor
calculado por `DUoM Tracking Subscribers` (50109) al validar `Lot No.` en Item Tracking
Lines (Page 6510). Al reabrir la página, BC reconstruye el buffer `Tracking Specification`
desde `Reservation Entry` vía `OnAfterCopyTrackingFromReservEntry` — y como
`ReservEntry."DUoM Ratio" = 0` siempre, las columnas DUoM aparecían vacías.

### Flujo roto (antes del fix)

```
Usuario valida Lot No. en Item Tracking Lines
    ↓
OnAfterValidateTrackingSpecLotNo (50109)
    → TrackingSpec."DUoM Ratio" = 0,38  ✅ (visible en pantalla)
    ↓
Usuario cierra Item Tracking Lines
    ↓
BC llama CopyTrackingFromTrackingSpec → Reservation Entry
    → OnAfterCopyTrackingFromTrackingSpec se dispara
    → NADIE propaga DUoM Ratio  ❌
    → ReservEntry."DUoM Ratio" = 0  ❌
    ↓
Usuario vuelve a abrir Item Tracking Lines
    ↓
BC reconstruye buffer desde ReservEntry
    → OnAfterCopyTrackingFromReservEntry (50110) copia ReservEntry."DUoM Ratio" = 0
    → TrackingSpec."DUoM Ratio" = 0  ❌ (columnas vacías)
```

### Flujo correcto (después del fix)

```
Usuario cierra Item Tracking Lines
    ↓
BC llama CopyTrackingFromTrackingSpec → Reservation Entry
    → OnAfterCopyTrackingFromTrackingSpec (50110, nuevo subscriber)
    → ReservEntry."DUoM Ratio" = 0,38  ✅
    ↓
Usuario vuelve a abrir Item Tracking Lines
    ↓
BC reconstruye buffer desde ReservEntry
    → OnAfterCopyTrackingFromReservEntry (50110, ya existente)
    → TrackingSpec."DUoM Ratio" = 0,38  ✅
```

## Cambios realizados

### 1. `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al` (50110)

**Añadido:** Nuevo subscriber `ReservEntryOnAfterCopyTrackingFromTrackingSpec`.

- Publisher: `Table "Reservation Entry"` (337), evento `OnAfterCopyTrackingFromTrackingSpec`.
- Firma verificada contra `codeunit 6516 "Package Management"`.
- Copia `DUoM Ratio` y `DUoM Second Qty` desde `TrackingSpecification` hacia `ReservationEntry`.
- Subscriber stateless — sin lookups adicionales.

**Actualizado:** Resumen de `/// <summary>` para incluir la nueva cadena
`Tracking Specification → Reservation Entry` y la firma verificada.

### 2. `app/src/tableextension/DUoMReservationEntryExt.TableExt.al` (50123)

**Eliminado:** Bloque `Note:` que documentaba la limitación AL0282 (ahora incorrecta).

**Añadido:** Descripción correcta del mecanismo implementado: la propagación se realiza
en `DUoM Tracking Copy Subscribers` (50110) vía `OnAfterCopyTrackingFromTrackingSpec`.

### 3. `app/src/codeunit/DUoMTrackingSubscribers.Codeunit.al` (50109)

**Eliminado:** Sección `Propagación a Reservation Entry (RF-04):` del comentario de
cabecera, que documentaba la limitación AL0282 — ahora obsoleta.

### 4. `test/src/codeunit/DUoMItemTrackingTests.Codeunit.al` (50218)

**Añadidos:** Tests T08 y T09.

- **T08** — `ReservEntry_CopyFromTrackingSpec_DUoMRatioPropagated`: verifica que
  `ReservEntry.CopyTrackingFromTrackingSpec(TrackingSpec)` propaga `DUoM Ratio = 0,38`
  y `DUoM Second Qty = 3,8`.
- **T09** — `RoundTrip_TrackingSpec_ReservEntry_PreservesRatio`: verifica el round-trip
  completo `TrackingSpec → ReservEntry → TrackingSpec` sin pérdida de datos.

## Criterios de aceptación

| Test | Descripción | Estado |
|------|-------------|--------|
| T08  | `OnAfterCopyTrackingFromTrackingSpec` propaga DUoM Ratio a ReservEntry | ✅ |
| T09  | Round-trip TrackingSpec → ReservEntry → TrackingSpec conserva DUoM Ratio | ✅ |

## Referencias

- Patrón: `codeunit 6516 "Package Management"`, procedure `ReservationEntryCopyTrackingFromTrackingSpec`
- Issue relacionado: #22 (DUoM operativo en Item Tracking Lines)
- Issue relacionado: #23 (propagación DUoM al ILE via OnAfterCopyTracking*)
- Issue relacionado: #24 (regresiones en propagación DUoM al ILE)

## Etiquetas

`bug` · `item-tracking` · `reservation-entry` · `tracking-copy-subscribers` · `phase-1`
