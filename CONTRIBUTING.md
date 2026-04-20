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

### Eventos InitFrom* para propagación a líneas de documentos contabilizados

Para copiar campos de extensión desde una línea de documento origen a una línea de documento
contabilizado, usar siempre los eventos de inicialización estándar de la **tabla destino**
en lugar de eventos de inserción en el codeunit de contabilización. Estos eventos son más
estables, tienen la línea origen disponible como parámetro y su firma es menos propensa a
cambiar entre versiones de BC.

| Flujo de propagación | Tabla publicadora | Nombre del evento |
|---------------------|------------------|-------------------|
| `Purchase Line` → `Purch. Rcpt. Line` | `"Purch. Rcpt. Line"` (Table) | `OnAfterInitFromPurchLine` |
| `Sales Line` → `Sales Shipment Line` | `"Sales Shipment Line"` (Table) | `OnAfterInitFromSalesLine` |

**Firma confirmada (BC 27 / runtime 15):**

```al
// Purchase
[EventSubscriber(ObjectType::Table, Database::"Purch. Rcpt. Line", 'OnAfterInitFromPurchLine', '', false, false)]
local procedure OnAfterInitFromPurchLine(PurchRcptHeader: Record "Purch. Rcpt. Header"; PurchLine: Record "Purchase Line"; var PurchRcptLine: Record "Purch. Rcpt. Line")

// Sales
[EventSubscriber(ObjectType::Table, Database::"Sales Shipment Line", 'OnAfterInitFromSalesLine', '', false, false)]
local procedure OnAfterInitFromSalesLine(SalesShptHeader: Record "Sales Shipment Header"; SalesLine: Record "Sales Line"; var SalesShptLine: Record "Sales Shipment Line")
```

**No usar** eventos de inserción en `Codeunit::"Purch.-Post"` o `Codeunit::"Sales-Post"` como
`OnBeforePurchRcptLineInsert` o `OnBeforeInsertShipmentLine` — estos eventos **no existen en BC 27**
y causan errores AL0280/AL0282.

### Suscriptores delgados + helpers de transferencia centralizados

Los procedimientos suscriptores deben ser delgados: solo validar y delegar.
La lógica de copia de campos DUoM vive en `DUoM Doc Transfer Helper` (codeunit 50105).

Todo nuevo suscriptor debe incluir un comentario con:
- Objeto publicador (tabla o codeunit)
- Nombre del evento
- Por qué se eligió ese evento
- Confirmación de que la firma fue validada en los símbolos BC 27

### Verificación de páginas estándar en `pageextension`

**Antes de crear un `pageextension`** que extienda una página estándar de Microsoft,
verificar que la página existe en BC 27 con ese nombre exacto consultando el
Symbol Reference de BC 27.  
Los nombres de páginas estándar han cambiado en varias versiones (renombrados, movidos
a namespaces). Una cláusula `extends` con un nombre incorrecto provoca AL0247 y bloquea
toda la compilación del módulo donde aparece.

---

## Regla de mantenimiento de documentación (obligatoria)

> **Todo cambio en el repositorio obliga a revisar la documentación afectada y actualizarla en el mismo trabajo. Si tras la revisión no hay nada que modificar, debe indicarse explícitamente "No aplica" con una justificación breve y concreta. No se acepta un cambio silencioso que omita esta revisión.**

Esta norma aplica a **cualquier tipo de cambio**, sin excepción:

- código AL y tests
- `app.json` / `test/app.json`
- permission sets y traducciones
- pipelines, workflows y configuración de AL-Go
- estructura de carpetas
- backlog y roadmap
- decisiones de diseño o arquitectura
- documentación funcional y técnica
- `README.md` y cualquier archivo `.md` relacionado

### Documentos mínimos a revisar en cada cambio

Al trabajar en un issue o PR, identificar y revisar al menos los siguientes documentos cuando el cambio los afecte:

| Documento | Cuándo revisarlo |
|-----------|-----------------|
| `README.md` | Cualquier cambio que altere el alcance, la configuración o el tech stack |
| `docs/02-functional-design.md` | Cambios en lógica funcional, modos de conversión, propagación |
| `docs/03-technical-architecture.md` | Cambios en diseño técnico, eventos, patrones de extensión |
| `docs/04-item-setup-model.md` | Cambios en tablas o campos de configuración de artículo |
| `docs/05-testing-strategy.md` | Cambios en estrategia o estructura de tests |
| `docs/06-backlog.md` | Cierre de issues, cambios de prioridad o alcance |
| `docs/07-localization.md` | Cambios en textos, Labels o flujo XLF |
| `docs/ci-cost-decisions.md` | Cambios en workflows o configuración de CI |
| `CONTRIBUTING.md` | Cambios en normas, convenciones o DoD del proyecto |
| `.github/copilot-instructions.md` | Cambios en reglas que el agente Copilot debe aplicar |

### Resultado requerido en cada PR

Cada PR debe incluir una de estas dos declaraciones en la descripción o en los comentarios:

- **Documentación actualizada:** listar los archivos `.md` modificados y qué se cambió.
- **No aplica:** justificar brevemente por qué ningún documento necesita cambio (p.ej. "corrección de typo interno en codeunit sin impacto en diseño ni APIs").

Un PR sin esta declaración explícita no cumple la definición de trabajo completado.

---

## Tests

- TDD es obligatorio: el test debe existir antes que la producción.
- Los tests usan `Subtype = Test` y el atributo `[Test]`.
- Patrón de comentarios: `// [GIVEN] / [WHEN] / [THEN]`.
- Librería de aserciones: `Library Assert` (Microsoft).
- Ningún test puede desactivarse para que pase el CI.

### Norma de creación de datos de test (obligatoria)

En el código de tests, **si existe un helper estándar de Microsoft `Library - *` que cubra
razonablemente el caso, debe usarse ese helper** en lugar de implementar lógica manual o un
helper propio equivalente. Se aplica la siguiente jerarquía de decisión:

1. **Primero**: usar helper estándar `Library - *` (p.ej. `LibraryInventory.CreateItem`, `LibraryPurchase.CreateVendor`).
2. **Si no existe helper estándar suficiente**: usar helper propio reutilizable del proyecto (`DUoM Test Helpers`).
3. **Si tampoco existe helper propio**: crear uno nuevo en la capa de tests, nunca en la app productiva.
4. **Toda excepción** a la jerarquía debe quedar justificada en comentario en el propio código.

Ejemplos de creadores estándar disponibles:

| Entity              | Library call                                                  |
|---------------------|---------------------------------------------------------------|
| Item                | `LibraryInventory.CreateItem(Item)`                          |
| Item Variant (auto) | `LibraryInventory.CreateItemVariant(ItemVariant, ItemNo)`    |
| Item Variant (code) | `DUoMTestHelpers.CreateItemVariantWithCode(ItemNo, Code, ItemVariant)` |
| Vendor              | `LibraryPurchase.CreateVendor(Vendor)`                       |
| Customer            | `LibrarySales.CreateCustomer(Customer)`                      |
| Purchase Header     | `LibraryPurchase.CreatePurchaseHeader(...)`                  |
| Purchase Line       | `LibraryPurchase.CreatePurchaseLine(...)`                    |
| Sales Header        | `LibrarySales.CreateSalesHeader(...)`                        |
| Sales Line          | `LibrarySales.CreateSalesLine(...)`                          |
| Item Journal Line   | `LibraryInventory.CreateItemJournalLine(...)`                |

> `Init()` sin `Insert()` sigue siendo válido para registros puramente en memoria (p.ej.
> testing de validación de campos en aislamiento).

Ver detalles y excepciones justificadas en `.github/copilot-instructions.md`, sección
"AL Test Data Creation — Mandatory Standard".

---

## Definition of Done (DoD)

Un issue/PR se considera **terminado** solo cuando se cumple **todo** lo siguiente:

- [ ] El código compila sin errores ni warnings (zero-warnings policy).
- [ ] Todos los tests existentes siguen pasando.
- [ ] Los nuevos tests cubren la funcionalidad añadida o modificada.
- [ ] Los tests de nueva creación de datos usan helpers estándar `Library - *` o `DUoM Test Helpers`, no `Init()` + `Insert(false)` manual sobre tablas estándar.
- [ ] Todos los textos visibles usan Labels/Captions con `Comment`.
- [ ] `DualUoM-BC.en-US.xlf` actualizado con `state="final"`.
- [ ] `DualUoM-BC.es-ES.xlf` actualizado con `state="translated"`.
- [ ] Terminología consistente con el glosario de `docs/07-localization.md`.
- [ ] Permission sets actualizados si hay nuevas tablas: **tanto `DUoMAll.PermissionSet.al` (producción) como `DUoMTestAll.PermissionSet.al` (test)**.
- [ ] **Documentación revisada:** todos los documentos afectados están actualizados, o se ha declarado explícitamente "No aplica" con justificación (ver sección "Regla de mantenimiento de documentación").
- [ ] Todos los nombres de objeto AL tienen ≤ 30 caracteres.
- [ ] Todos los `[EventSubscriber]` han sido verificados contra el Symbol Reference de BC 27
      (nombre de evento y parámetros correctos).
- [ ] Todos los `pageextension` han sido verificados contra el Symbol Reference de BC 27
      (nombre exacto de la página objetivo).
- [ ] Para propagar campos a líneas de documentos contabilizados, se usan eventos `InitFrom*`
      en la **tabla destino** (no eventos de inserción en el codeunit de contabilización).
- [ ] Los suscriptores son delgados: delegan la lógica de copia a `DUoM Doc Transfer Helper` (50105).
- [ ] Todo nuevo suscriptor incluye comentario con: publicador, nombre evento, justificación y
      confirmación de firma contra BC 27 symbols.

---

## Referencias

- `.github/copilot-instructions.md` — Instrucciones para el agente Copilot (incluye la norma de documentación para el agente)
- `docs/07-localization.md` — Flujo XLF, glosario y reglas de localización detalladas
- `docs/06-backlog.md` — Backlog ordenado de entregables
- `docs/05-testing-strategy.md` — Estrategia de tests
- `docs/03-technical-architecture.md` — Arquitectura técnica de la extensión
- `docs/02-functional-design.md` — Diseño funcional de Dual UoM
