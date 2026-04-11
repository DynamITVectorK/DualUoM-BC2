# Guía de contribución — DualUoM-BC

Bienvenido/a al proyecto **DualUoM-BC**. Este documento recoge las normas que deben seguir todos los contribuidores para mantener la calidad, coherencia y mantenibilidad de la extensión.

---

## Idioma de trabajo

El idioma oficial del proyecto es el **español**. Toda la documentación, comentarios en issues/PRs y mensajes de commit deben redactarse en español. Los identificadores AL y las APIs de Business Central se mantienen en inglés por convención de plataforma.

---

## Requisitos previos

- Conocimiento de AL (Business Central Extension Language)
- Extensión AL para VS Code
- Acceso al repositorio y a un entorno BC 27 (sandbox de Business Central Online)

---

## Ciclo de desarrollo

1. **Crear o asignarse un issue** del backlog (`docs/06-backlog.md`).
2. **TDD:** escribir primero el test que falla, luego la producción.
3. **Implementar** en la rama `copilot/<nombre-issue>` o `feature/<nombre-issue>`.
4. **Localización:** actualizar ambos XLF **en el mismo PR** (ver sección siguiente).
5. **PR:** abrir una Pull Request contra `main` con el checklist del issue completado.

> **Límite de 30 caracteres en identificadores AL (AL0305):** Los nombres de todos los objetos AL
> (tablas, páginas, codeunits, page extensions, etc.) **no pueden superar los 30 caracteres**.
> Verificar la longitud antes de abrir un PR. Los nombres de page extensions deben ser
> especialmente compactos para dejar margen al prefijo `DUoM`.

---

## Regla de localización (obligatoria)

> **Una funcionalidad no está terminada hasta que todos sus textos visibles están traducidos en español e inglés.**

### Qué debe localizarse

Todo texto visible para el usuario dentro de la extensión:

- Captions de páginas, grupos, campos y acciones
- Tooltips
- Mensajes de error y confirmación
- Notificaciones
- Captions de valores de enum
- Cualquier otro texto de interfaz

### Cómo hacerlo correctamente

**❌ Prohibido — string hardcodeado:**
```al
Error('El código de la 2ª UdM no puede ser igual a la UdM base.');
```

**✅ Correcto — Label con Comment:**
```al
var
    SameUoMErr: Label 'Second UoM Code cannot be the same as the base unit of measure (%1).',
                Comment = '%1 = UoM Code';
...
Error(SameUoMErr, "Second UoM Code");
```

### Reglas de Label

- Declarar siempre como variable `Label` o propiedad `Caption`/`ToolTip`.
- Incluir siempre la propiedad `Comment`:
  - Con parámetros: `Comment = '%1 = Item No., %2 = UoM Code'`
  - Sin parámetros: `Comment = 'Validation error; no placeholders.'`

### Archivos XLF

Los archivos de traducción están en `app/Translations/`:

| Archivo | Idioma | Estado de las entradas |
|---------|--------|----------------------|
| `DualUoM-BC.en-US.xlf` | Inglés (referencia) | `state="final"` |
| `DualUoM-BC.es-ES.xlf` | Español | `state="translated"` |

Cada PR que añada o modifique textos visibles **debe** actualizar ambos archivos en la misma entrega. No se aceptan PRs si los archivos XLF del repositorio contienen entradas con `state="needs-translation"` al cierre del PR (aplica a la totalidad del archivo, no solo a las entradas nuevas).

### Glosario terminológico

Consultar `docs/07-localization.md` para la terminología canónica de Dual UoM en inglés y español.

---

## Regla de permisos (obligatoria)

Toda nueva tabla debe tener una entrada `tabledata` **en dos sitios** en el mismo PR:

1. **`app/src/permissionset/DUoMAll.PermissionSet.al`** — para que la extensión de producción funcione. La omisión provoca el error de build `PTE0004`.
2. **`test/src/permissionset/DUoMTestAll.PermissionSet.al`** — para que el app de test pueda insertar en esa tabla tanto directamente como de forma indirecta (llamando a codeunits de producción).

Ver detalles en `.github/copilot-instructions.md` (sección "Permission set rule").

> **Nunca uses** la propiedad `Permissions` en un objeto codeunit. Es una API deprecada (AL0246) que además **no cubre los IndirectInserts** (cuando el test llama a una codeunit de producción que escribe en la tabla). Usa siempre un objeto `permissionset` independiente.

---

## Compatibilidad de API BC 27

### Verificación de eventos de suscriptor

**Antes de implementar cualquier `[EventSubscriber]`** que apunte a un codeunit estándar
de Microsoft (por ejemplo `Purch.-Post`, `Sales-Post`, `Item Jnl.-Post Line`), verificar
que el evento y todos sus parámetros existen en la versión BC 27 (runtime 15) consultando:

- El **BC Symbol Reference** en VS Code (extensión AL).
- El repositorio público [microsoft/ALAppExtensions](https://github.com/microsoft/ALAppExtensions).

Los eventos de BC cambian entre versiones (renombrados, parámetros modificados, eliminados).
Un suscriptor que apunta a un evento inexistente provoca AL0280 o AL0282 y rompe el build.

### Verificación de páginas estándar en `pageextension`

**Antes de crear un `pageextension`** que extienda una página estándar de Microsoft,
verificar que la página existe en BC 27 con ese nombre exacto consultando el
Symbol Reference de BC 27.  
Los nombres de páginas estándar han cambiado en varias versiones (renombrados, movidos
a namespaces). Una cláusula `extends` con un nombre incorrecto provoca AL0247 y bloquea
toda la compilación del módulo donde aparece.

---

## Tests

- TDD es obligatorio: el test debe existir antes que la producción.
- Los tests usan `Subtype = Test` y el atributo `[Test]`.
- Patrón de comentarios: `// [GIVEN] / [WHEN] / [THEN]`.
- Librería de aserciones: `Library Assert` (Microsoft).
- Ningún test puede desactivarse para que pase el CI.

---

## Definition of Done (DoD)

Un issue/PR se considera **terminado** solo cuando se cumple **todo** lo siguiente:

- [ ] El código compila sin errores ni warnings (zero-warnings policy).
- [ ] Todos los tests existentes siguen pasando.
- [ ] Los nuevos tests cubren la funcionalidad añadida o modificada.
- [ ] Todos los textos visibles usan Labels/Captions con `Comment`.
- [ ] `DualUoM-BC.en-US.xlf` actualizado con `state="final"`.
- [ ] `DualUoM-BC.es-ES.xlf` actualizado con `state="translated"`.
- [ ] Terminología consistente con el glosario de `docs/07-localization.md`.
- [ ] Permission sets actualizados si hay nuevas tablas: **tanto `DUoMAll.PermissionSet.al` (producción) como `DUoMTestAll.PermissionSet.al` (test)**.
- [ ] Documentación técnica actualizada si procede.
- [ ] Todos los nombres de objeto AL tienen ≤ 30 caracteres.
- [ ] Todos los `[EventSubscriber]` han sido verificados contra el Symbol Reference de BC 27
      (nombre de evento y parámetros correctos).
- [ ] Todos los `pageextension` han sido verificados contra el Symbol Reference de BC 27
      (nombre exacto de la página objetivo).

---

## Referencias

- `.github/copilot-instructions.md` — Instrucciones para el agente Copilot
- `docs/07-localization.md` — Flujo XLF, glosario y reglas de localización detalladas
- `docs/06-backlog.md` — Backlog ordenado de entregables
- `docs/05-testing-strategy.md` — Estrategia de tests
- `docs/02-functional-design.md` — Diseño funcional de Dual UoM
