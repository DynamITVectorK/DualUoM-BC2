# Configuración DUoM del artículo — Nota de diseño del modelo de datos

## Decisión: Opción B — Tabla de configuración dedicada

La configuración DUoM del artículo se almacena en una tabla dedicada (`DUoM Item Setup`, ID 50100)
indexada por `Item No.`, en lugar de extender directamente la tabla `Item`.

---

## Justificación

### ¿Por qué no la Opción A (extensión de la tabla Item)?

Extender `Item` directamente contaminaría la tabla más utilizada en BC con campos DUoM
irrelevantes para la mayoría de los artículos. También crea un acoplamiento más estrecho
que dificulta la eliminación o refactorización, y aumenta el riesgo en el momento de actualización (cualquier
cambio de esquema en Item es responsabilidad de BC y puede bloquear las actualizaciones de la extensión).

### ¿Por qué no la Opción C (híbrida)?

Un enfoque híbrido añade complejidad: un indicador en `Item` para la habilitación más una
tabla separada para los detalles. El indicador en `Item` aporta un beneficio mínimo (filtro rápido
sin join) pero añade sobrecarga de mantenimiento si la tabla de configuración se consulta
igualmente. Dado que el rendimiento de BC a esta escala no es una preocupación, el join adicional
es aceptable y mantener toda la configuración DUoM en un solo lugar es más limpio.

### ¿Por qué la Opción B?

- **Base limpia**: la tabla Item no se modifica. La seguridad en las actualizaciones es máxima.
- **Ausencia = no configurado**: un registro `DUoM Item Setup` ausente significa que no hay DUoM
  para ese artículo — sin campos de indicador nulo que verificar en todos los artículos.
- **Fuente única de verdad**: toda la configuración DUoM del artículo reside en una tabla con
  una clave primaria clara.
- **Extensible**: añadir futuros campos (vínculo de seguimiento de lotes, indicadores específicos de almacén,
  campos de costes) no requiere extensiones adicionales de la tabla Item.
- **Seguro para SaaS**: sigue el patrón de *tabla de extensión dedicada* recomendado para
  extensiones PTE que asocian configuración compleja a entidades estándar.

---

## Estructura de la tabla

| Campo | Tipo | Propósito |
|---|---|---|
| `Item No.` | Code[20] PK | Vincula a `Item`; define el ámbito de configuración |
| `Dual UoM Enabled` | Boolean | Interruptor principal; desactivarlo limpia todos los demás campos |
| `Second UoM Code` | Code[10] | La UdM secundaria (p. ej. PZS cuando la base es KG) |
| `Conversion Mode` | Enum `DUoM Conversion Mode` | Fixed / Variable / Always Variable |
| `Fixed Ratio` | Decimal(0:5) | Ratio cuando el modo es Fixed o Variable; se limpia para Always Variable |

---

## Enum: DUoM Conversion Mode

| Valor | Significado |
|---|---|
| Fixed | El ratio es constante; almacenado en el campo `Fixed Ratio`; derivado automáticamente |
| Variable | Ratio predeterminado en `Fixed Ratio`; el usuario puede sobreescribirlo por línea de documento |
| Always Variable | Sin ratio predeterminado; el usuario debe introducirlo manualmente en cada línea de documento |

---

## Reglas de validación

| Regla | Punto de aplicación |
|---|---|
| Si DUoM deshabilitado → Second UoM Code, Conversion Mode, Fixed Ratio se limpian | Disparador OnValidate de `Dual UoM Enabled` |
| Si DUoM habilitado → Second UoM Code debe estar establecido | Procedimiento `ValidateSetup()` |
| Second UoM Code ≠ UdM base del artículo | Disparador OnValidate de `Second UoM Code` + `ValidateSetup()` |
| Si modo Fixed → Fixed Ratio > 0 | Procedimiento `ValidateSetup()` |
| Cambio de Fixed a Variable/Always Variable → Fixed Ratio se limpia | Disparador OnValidate de `Conversion Mode` |

`ValidateSetup()` es un procedimiento público destinado a ser usado por los flujos de documento/contabilización
(issues futuros) para verificar la consistencia de la configuración antes de usar los datos DUoM.

---

## Extensibilidad futura

- **Ratios específicos por lote (Fase 2)**: se almacenarán en una tabla separada indexada por
  `(Item No., Lot No.)` — no se necesitan cambios en `DUoM Item Setup`.
- **Campos de almacén (Fase 2)**: se pueden añadir indicadores booleanos adicionales (p. ej. `Track in WMS`)
  a `DUoM Item Setup` como nuevos campos sin romper los datos existentes.
- **Propagación de documentos**: los codeunits de líneas de documento llamarán a `DUoM Item Setup.Get()`
  para recuperar el modo de conversión y el ratio — el diseño de clave de tabla soporta esto.
- **Herramientas de actualización masiva**: un issue futuro puede añadir un informe/página para habilitar DUoM en masa
  para múltiples artículos sin cambiar la estructura de la tabla.
