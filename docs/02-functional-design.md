# Diseño Funcional — DualUoM-BC

## Configuración DUoM del artículo

Cada artículo que participa en la doble UdM requiere la siguiente configuración:

| Campo | Descripción |
|---|---|
| `Dual UoM Enabled` | Booleano — activa DUoM para este artículo |
| `Second UoM Code` | El código de la segunda unidad de medida (p. ej. PZS cuando la base es KG) |
| `Conversion Mode` | Fixed / Variable / Always-Variable (ver más abajo) |
| `Fixed Ratio` | Usado solo cuando el modo de conversión es Fixed |

Esta configuración se almacena en una tabla dedicada de configuración DUoM del artículo vinculada
por número de artículo. La intención funcional es la configuración a nivel de artículo.

---

## Modos de conversión

### Fixed (Fijo)

El ratio entre las dos unidades es constante en todas las transacciones y lotes.

```
Segunda Cantidad = Primera Cantidad × Ratio Fijo
```

Ejemplo: 1 caja contiene siempre exactamente 12 piezas.

### Variable

El sistema propone un ratio predeterminado (de la configuración del artículo), pero el usuario puede sobreescribirlo
por línea de documento. La sobreescritura se almacena en la línea y se propaga a los asientos.

Ejemplo: Un ratio KG/pzs de ~1,25 KG/pzs es el predeterminado, pero el peso real
del lote en esta recepción es 1,31 KG/pzs, por lo que el usuario ajusta el campo.

### Always-Variable (Siempre Variable)

No se proporciona ratio predeterminado. El usuario debe introducir la segunda cantidad manualmente en
cada línea de documento. El sistema nunca la deriva automáticamente.

Ejemplo: Producto fresco vendido por peso pero contado por pieza — cada envío es diferente.

---

## Propagación de la segunda cantidad

La segunda cantidad debe ser visible y editable (según el modo de conversión) en:

1. **Línea de pedido de compra** — introducida o derivada en el momento del pedido
2. **Línea de recepción de compra** — confirmada o ajustada en la recepción
3. **Asiento del libro de artículos** — contabilizado desde la recepción; inmutable tras la contabilización
4. **Línea de pedido de venta** — introducida o derivada al crear el pedido
5. **Línea de envío de venta** — confirmada en el envío
6. **Línea del diario de artículos** — introducida manualmente para ajustes

En todos los casos, el ratio utilizado en el momento de la contabilización se almacena junto
a la cantidad para que el análisis histórico sea posible sin recalcular.

---

## Ratio real específico por lote

Cuando el seguimiento de artículos por lote está activo, el ratio de conversión real para un lote determinado puede
diferir del predeterminado. El ratio real pesado es:

- introducido por el usuario en la recepción (almacén o compra)
- almacenado contra el número de lote (extensión de seguimiento de artículos)
- usado como predeterminado para todas las transacciones posteriores que involucren ese lote

Esta es una funcionalidad de la Fase 2. En el MVP, el ratio se almacena solo en la línea del documento.

---

## Impacto esperado en los módulos

### Compras

- Las líneas de pedido de compra y líneas de recepción obtienen un campo `Second Qty` y `Second UoM Code`
- La contabilización propaga la segunda cantidad al asiento del libro de artículos
- La línea de factura de compra muestra la segunda cantidad (solo lectura desde la recepción, ajustable en facturas directas)

### Ventas

- Las líneas de pedido de venta y líneas de envío obtienen un campo `Second Qty`
- El picking (almacén básico) descuenta basándose en la cantidad principal; la segunda cantidad es informativa
- La línea de factura muestra la segunda cantidad del envío

### Inventario

- Las líneas del diario de artículos obtienen un campo `Second Qty`
- Los asientos del libro de artículos registran la segunda cantidad para todos los tipos de asiento relevantes
- Los recuentos de inventario físico admiten la introducción de segunda cantidad

### Almacén (Fase 2)

- Las líneas de recepción y envío de almacén obtienen `Second Qty`
- Las líneas de picking/put-away dirigido obtienen `Second Qty` para doble verificación
- Los asientos de almacén registran la segunda cantidad
