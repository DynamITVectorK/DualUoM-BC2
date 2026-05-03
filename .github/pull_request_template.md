## Descripción del cambio

<!-- Describe brevemente qué cambia y por qué. -->

---

## Documentación

<!-- Obligatorio. Indicar una de las dos opciones: -->

- **Documentación actualizada:** <!-- lista de archivos .md modificados y qué cambió -->
- **No aplica:** <!-- justificación breve y concreta (p.ej. "corrección de typo interno sin impacto en APIs ni diseño") -->

---

## Checklist de validación BC / DUoM

- [ ] He usado las APIs estándar de Business Central donde existen.
- [ ] No he creado ni manipulado registros `Reservation Entry` manualmente salvo justificación explícita.
- [ ] He usado `Reservation Entry.SetSourceFilter(...)` para filtrar datos persistidos de tracking/reserva.
- [ ] He usado `Tracking Specification.SetSourceFilter(...)` para filtrar buffers temporales de tracking.
- [ ] No he filtrado datos de tracking solo por `Lot No.`, `Serial No.`, `Package No.` o `Entry No.`.
- [ ] No he asumido una relación 1:1 entre línea de documento y lote.
- [ ] He verificado firmas de eventos, nombres de tablas, páginas y métodos contra los símbolos BC actuales.
- [ ] He añadido o actualizado tests que cubren 1 línea origen con N lotes donde sea aplicable.

---

## Checklist general AL

- [ ] Los identificadores AL no superan 30 caracteres (límite AL0305).
- [ ] Todos los textos visibles al usuario son `Label` con `Comment` de descripción de placeholders.
- [ ] Los archivos XLF (`en-US` y `es-ES`) están actualizados si se añadieron o cambiaron cadenas.
- [ ] Los nuevos objetos `table` tienen entrada en `DUoM - All` y en `DUoM - Test All`.
- [ ] Los nuevos `[EventSubscriber]` incluyen comentario de validación de firma (publisher, evento, razón, confirmación BC 27).
- [ ] Los tests pasan y no se ha desactivado ninguno para hacer pasar la CI.
