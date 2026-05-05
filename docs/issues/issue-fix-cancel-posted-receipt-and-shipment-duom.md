# Issue — bug: anulación de albarán contabilizado no revierte correctamente DUoM (compras y ventas)

## Resumen

Se detecta un fallo en la **anulación de albaranes contabilizados** donde los movimientos de reversión no conservan de forma consistente los campos de DUoM (ratio y segunda cantidad), provocando inconsistencias en:

- Movs. producto (Item Ledger Entry)
- Trazabilidad por lote/serie
- Cantidades facturadas y pendientes en documentos relacionados

El problema se observa en **compras** y la misma solución debe aplicarse también a **ventas**, porque ambas rutas usan el mismo patrón de copiado de tracking/reversión en BC.

---

## Contexto funcional

Al anular un albarán contabilizado se generan movimientos inversos. En escenarios con lotes (múltiples líneas de tracking), si DUoM no se propaga en todos los puntos de copia, pueden aparecer líneas con signos correctos en cantidad base pero con DUoM incompleto o a cero.

Síntomas típicos:

1. Reversos con cantidades base correctas pero `DUoM Ratio` vacío/0.
2. Descuadre entre `Cantidad` y `Cantidad secundaria DUoM` en movimientos invertidos.
3. Reapertura de seguimiento con valores DUoM no persistidos tras la anulación.

---

## Alcance

### Incluido

- Anulación de albarán de **compra** contabilizado.
- Anulación de albarán de **venta** contabilizado.
- Casos con tracking por lote/serie y múltiples líneas.

### No incluido

- Re-diseño funcional de DUoM.
- Cambios de UX fuera de validaciones y persistencia de campos DUoM.

---

## Causa raíz probable

En la cadena de anulación/reversión hay al menos un salto de copia (`Tracking Specification`, `Reservation Entry`, buffers de aplicación, o creación de entradas invertidas) donde **no se transfiere explícitamente DUoM Ratio y DUoM Second Qty**.

Dado que compras y ventas comparten infraestructura de tracking/reversión, el fix debe implementarse de forma transversal en subscribers/eventos comunes o en ambos flujos espejo.

---

## Solución propuesta

1. **Auditar y completar propagación DUoM** en todos los puntos de copia implicados en anulación:
   - TrackingSpec → ReservEntry
   - ReservEntry/Tracking buffers → movimientos invertidos
   - Cualquier reconstrucción posterior de tracking
2. **Unificar comportamiento compras/ventas**:
   - Si hay subscriber común, centralizar ahí.
   - Si existen rutas separadas, aplicar cambios espejo y cubrir ambas con test.
3. **Añadir pruebas automáticas** para cancelación en ambos circuitos.

---

## Criterios de aceptación

- [ ] Al anular albarán de compra contabilizado, los movimientos inversos conservan `DUoM Ratio` y `DUoM Second Qty` en todas las líneas.
- [ ] Al anular albarán de venta contabilizado, mismo resultado.
- [ ] En escenarios multi-lote, la suma de segunda cantidad en reverso coincide (con signo contrario) con el movimiento original.
- [ ] No hay regresión en trazabilidad ni en cantidad facturada.

---

## Plan de pruebas (mínimo)

### Compra

1. Crear pedido compra con producto DUoM y 2-3 lotes con ratios distintos.
2. Registrar recepción/albarán.
3. Ejecutar **Anular**.
4. Verificar movimientos originales vs. invertidos (`Cantidad`, `DUoM Ratio`, `DUoM Second Qty`).

### Venta

1. Crear pedido venta equivalente con tracking multi-lote.
2. Registrar envío/albarán.
3. Ejecutar **Anular**.
4. Verificar mismos campos y consistencia de signos/sumas.

---

## Riesgos

- Fix parcial solo en compras (regresión funcional en ventas).
- Cobertura de test insuficiente para escenarios multi-lote con ratios heterogéneos.

---

## Etiquetas sugeridas

`bug` · `purchase` · `sales` · `item-tracking` · `cancellation` · `duom`
