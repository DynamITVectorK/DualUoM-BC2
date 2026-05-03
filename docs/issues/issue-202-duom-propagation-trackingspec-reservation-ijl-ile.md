# Issue 202 — Propagación DUoM extremo a extremo (TrackingSpec -> IJL -> ILE)

## Objetivo
Asegurar la propagación correcta de DUoM por lote desde captura en tracking line hasta registros destino de posting.

## Problema actual
- Riesgo de que, en algunos caminos, los valores de línea origen (agregados) se usen como fallback incorrecto para lotes múltiples.
- Necesidad de reforzar que la fuente de verdad por lote es Tracking Specification/Lot Ratio.

## Alcance
1. Revisar y ajustar subscribers en cadena estándar:
   - `OnAfterCopyTrackingFromReservEntry`
   - `OnAfterCopyTrackingFromSpec`
   - `OnAfterCopyTrackingFromItemJnlLine`
   - `OnAfterInitItemLedgEntry` (fallback)
2. Confirmar prioridad funcional:
   - Ratio por lote > ratio de línea origen.
3. Asegurar que 1 línea origen puede generar N ILE con ratio independiente.
4. No crear Reservation Entry manualmente fuera de patrón estándar.

## Criterios de aceptación
- En escenario 2 lotes / 2 ratios, cada ILE conserva ratio y second qty de su lote.
- No hay copia ciega de ratio de Purchase/Sales Line a todos los lotes.
- AlwaysVariable se comporta según política vigente.

## Tests requeridos
- Compra multilot con ratios distintas y verificación ILE por lote.
- Diario de producto multilot con ratios distintas y verificación ILE por lote.
- Test negativo AlwaysVariable sin ratio por lote.

## Dependencias
- Issue 204 (suite de tests).
