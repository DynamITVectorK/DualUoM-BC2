# 07 — Localization: XLF workflow, terminology glossary and rules

## Objetivo

Este documento define la estrategia de localización de la extensión **DualUoM-BC** y sirve como referencia permanente para cualquier desarrollador o agente que trabaje en el proyecto.

Idiomas soportados:
- **en-US** — Inglés (referencia principal)
- **es-ES** — Español

---

## Enfoque estándar: `TranslationFile` + XLF

La extensión usa la característica `TranslationFile` declarada en `app.json`:

```json
"features": ["TranslationFile", "NoImplicitWith"]
```

Los archivos de traducción residen en `app/Translations/`:

| Archivo | Idioma | Estado |
|---------|--------|--------|
| `DualUoM-BC.en-US.xlf` | Inglés (referencia) | `state="final"` |
| `DualUoM-BC.es-ES.xlf` | Español | `state="translated"` |

El compilador AL incorpora automáticamente las traducciones del XLF en el paquete de la extensión. En tiempo de ejecución, Business Central selecciona el XLF que coincide con el idioma del cliente.

---

## Reglas obligatorias

### 1. No hardcodear textos visibles

❌ Prohibido:
```al
Error('El código de la segunda UdM no puede ser igual a la UdM base.');
Message('Setup válido.');
```

✅ Correcto:
```al
var
    SameUoMErr: Label 'Second UoM Code cannot be the same as the base unit of measure (%1).',
                Comment = '%1 = UoM Code';
    SetupValidMsg: Label 'DUoM setup is valid.',
                   Comment = 'Confirmation message; no placeholders.';
...
Error(SameUoMErr, "Second UoM Code");
Message(SetupValidMsg);
```

### 2. `Comment` obligatorio en todos los `Label`

Cada declaración `Label` **debe** incluir la propiedad `Comment`:

- Si tiene parámetros: describir cada uno (`'%1 = Item No., %2 = UoM Code'`)
- Si no tiene parámetros: `'Validation error; no placeholders.'` / `'Confirmation message; no placeholders.'` etc.

### 3. Actualizar ambos XLF en el mismo PR

Cuando se añade o modifica cualquier caption, tooltip, label, error, confirmación, notificación o valor de enum:

1. Añadir la entrada `<trans-unit>` en `DualUoM-BC.en-US.xlf` con `state="final"`.
2. Añadir la entrada correspondiente en `DualUoM-BC.es-ES.xlf` con `state="translated"` y la traducción al español.
3. **No** crear PRs con `state="needs-translation"` — cada PR debe llegar al repositorio con ambas traducciones completas.

### 4. Definition of Done — localización

Una funcionalidad **no está terminada** hasta que se cumple **todo** lo siguiente:

- [ ] Todos los textos visibles están declarados como `Label` o propiedad `Caption`/`ToolTip`.
- [ ] Todos los `Label` tienen propiedad `Comment`.
- [ ] No queda ningún texto hardcodeado visible en la UI.
- [ ] `DualUoM-BC.en-US.xlf` actualizado: nuevas entradas con `state="final"`.
- [ ] `DualUoM-BC.es-ES.xlf` actualizado: mismas entradas con `state="translated"` y traducción en español.
- [ ] Terminología coherente con el glosario de este documento.
- [ ] No hay entradas `state="needs-translation"` en los XLF del repositorio.

---

## Flujo de trabajo XLF

### Añadir una nueva cadena

> ⚠️ **Los XLF deben actualizarse en el mismo PR que el código AL.** Un PR no está listo
> para mergear hasta que ambos XLF (`en-US` y `es-ES`) contengan entradas para **todas**
> las cadenas nuevas o modificadas, con `state="final"` y `state="translated"` respectivamente.
> Nunca uses `state="needs-translation"`.

El proceso correcto es:

1. Declarar la cadena en AL como `Label` (con `Comment`) o `Caption`/`ToolTip`.
2. Ejecutar CI mediante `workflow_dispatch` (o compilar localmente en VS Code) para obtener
   el artefacto compilado con los IDs hash correctos.
3. Descargar el artefacto `*-Apps-*.zip` → extraer como ZIP → abrir `Translations/DualUoM-BC.g.xlf`.
4. Copiar el `id` exacto del `<trans-unit>` correspondiente. **Nunca estimes el ID manualmente.**
5. Añadir la entrada en `en-US.xlf`:
   ```xml
   <trans-unit id="..." translate="yes" xml:space="preserve">
     <source>New string in English.</source>
     <target state="final">New string in English.</target>
     <note from="Developer" annotates="general" priority="2">...</note>
     <note from="Xliff Generator" annotates="general" priority="3">Object - context</note>
   </trans-unit>
   ```
6. Añadir la misma entrada en `es-ES.xlf` con la traducción:
   ```xml
   <trans-unit id="..." translate="yes" xml:space="preserve">
     <source>New string in English.</source>
     <target state="translated">Nueva cadena en español.</target>
     <note from="Developer" annotates="general" priority="2">...</note>
     <note from="Xliff Generator" annotates="general" priority="3">Object - context</note>
   </trans-unit>
   ```
7. Añadir el commit con los cambios XLF al mismo PR y empujar antes de solicitar revisión.

### Formato de los `trans-unit id`

> ⚠️ **IMPORTANTE — IDs hash-based (runtime 15 / BC 27+)**
>
> A partir de runtime 15 el compilador AL genera **IDs basados en hash**, no IDs secuenciales.
> Los IDs tienen el formato `<Tipo> <hash_objeto> - <segmento> <hash_elemento> - Property <hash_propiedad>`.
> **Nunca uses IDs secuenciales** como `Table 50100 - Field 1 - Property Caption` — estos no coinciden
> con lo que el compilador genera y BC no aplicará la traducción.
>
> La **única fuente de verdad** para los IDs correctos es el archivo `DualUoM-BC.g.xlf` incluido
> dentro del artefacto `.app` compilado (extraíble como ZIP). También está disponible en el artefacto
> de CI `*-Apps-*.zip` → `Translations/DualUoM-BC.g.xlf`.

Los IDs siguen el patrón generado por el compilador AL (ejemplos reales de este proyecto):

| Tipo | Segmento | Formato del ID | Ejemplo |
|------|----------|---------------|---------|
| Objeto (caption) | — | `<Tipo> <hash_obj> - Property <hash_prop>` | `Table 2256867475 - Property 2879900210` |
| Campo (caption) | Field | `<Tipo> <hash_obj> - Field <hash_campo> - Property <hash_prop>` | `Table 2256867475 - Field 568743302 - Property 2879900210` |
| Enum value | EnumValue | `Enum <hash_obj> - EnumValue <hash_valor> - Property <hash_prop>` | `Enum 747545484 - EnumValue 744835066 - Property 2879900210` |
| Label (NamedType) | NamedType | `<Tipo> <hash_obj> - NamedType <hash_label>` | `Table 2256867475 - NamedType 439880220` |
| Control de página | Control | `Page <hash_obj> - Control <hash_ctrl> - Property <hash_prop>` | `Page 2256867475 - Control 2445482498 - Property 2879900210` |
| Acción de página | Action | `Page <hash_obj> - Action <hash_accion> - Property <hash_prop>` | `Page 2256867475 - Action 2570329715 - Property 2879900210` |
| Acción de extensión | Action | `PageExtension <hash_obj> - Action <hash_accion> - Property <hash_prop>` | `PageExtension 3793678013 - Action 3087588456 - Property 2879900210` |

Hashes de propiedades habituales (constantes para todos los objetos):

| Propiedad | Hash |
|-----------|------|
| `Caption` | `2879900210` |
| `ToolTip` | `1295455071` |

### Eliminar una cadena

1. Eliminar la entrada `<trans-unit>` de ambos XLF.
2. Eliminar la declaración `Label` del AL.

### Modificar una cadena

1. Actualizar `<source>` y `<target>` en `en-US.xlf` (mantener `state="final"`).
2. Actualizar `<source>` y traducir `<target>` en `es-ES.xlf` (mantener `state="translated"`).

---

## Glosario terminológico

Terminología canónica para la extensión DualUoM-BC. Usar siempre estos términos en captions, tooltips, mensajes y documentación.

### Conceptos principales

| Concepto | Inglés (en-US) | Español (es-ES) |
|----------|---------------|-----------------|
| Extension feature | Dual Unit of Measure / Dual UoM | Unidad de Medida Dual / UdM Dual |
| Item setup record | DUoM Item Setup | Config. artículo UdM Dual |
| Master switch | Dual UoM Enabled | UdM Dual habilitada |
| Primary/base unit | Base Unit of Measure | Unidad de medida base |
| Secondary unit | Second UoM | Segunda UdM / 2ª UdM |
| Secondary unit code | Second UoM Code | Cód. 2ª UdM |
| Conversion ratio | Conversion Ratio / Fixed Ratio | Ratio de conversión / Ratio fijo |
| Conversion mode | Conversion Mode | Modo conversión |

### Modos de conversión (Enum 50100)

| Valor | Inglés (en-US) | Español (es-ES) |
|-------|---------------|-----------------|
| `Fixed` | Fixed | Fijo |
| `Variable` | Variable | Variable |
| `AlwaysVariable` | Always Variable | Siempre variable |

### Mensajes y errores

| Mensaje | Inglés (en-US) | Español (es-ES) |
|---------|---------------|-----------------|
| Setup valid | DUoM setup is valid. | La configuración UdM Dual es válida. |
| Same UoM error | Second UoM Code cannot be the same as the base unit of measure (%1). | El código de la 2ª UdM no puede ser el mismo que la unidad de medida base (%1). |
| Second UoM required | Second UoM Code must be specified when Dual UoM is enabled. | Debe especificarse el código de la 2ª UdM cuando la UdM Dual está habilitada. |
| Fixed ratio required | Fixed Ratio must be greater than zero when Conversion Mode is Fixed. | El ratio fijo debe ser mayor que cero cuando el modo de conversión es Fijo. |

### Conceptos de fases futuras (Phase 2+)

Estos términos no están en uso aún pero deben seguir esta convención cuando se implementen:

| Concepto | Inglés (en-US) | Español (es-ES) |
|----------|---------------|-----------------|
| Lot-specific ratio | Lot-Specific Ratio | Ratio específico por lote |
| Variable conversion | Variable Conversion | Conversión variable |
| Quantity (primary) | Quantity | Cantidad |
| Quantity (secondary) | Second Quantity | Segunda cantidad |
| Cost per unit | Unit Cost | Coste unitario |
| Price per unit | Unit Price | Precio unitario |
| Warehouse bin | Bin | Ubicación |
| Location | Location | Almacén |
| Zone | Zone | Zona |

---

## Cobertura actual de traducciones

### Estado en la versión inicial (MVP — Issues 1–3)

| Objeto | Tipo | Cadenas traducidas |
|--------|------|--------------------|
| `Enum 50100 "DUoM Conversion Mode"` | Enum | Caption + 3 valores |
| `Table 50100 "DUoM Item Setup"` | Table | Caption + 5 captions de campos + 3 mensajes |
| `Page 50100 "DUoM Item Setup"` | Page | Caption + 2 grupos + 5 tooltips + 1 acción (caption + tooltip) + 1 mensaje |
| `PageExtension 50100 "DUoM Item Card Ext"` | PageExtension | 1 acción (caption + tooltip) |
| `PermissionSet 50100 "DUoM - All"` | PermissionSet | Caption |
| **Total** | | **27 trans-units por idioma** |

### ⚠️ Hueco conocido — Phase 1 MVP (Issues 2, 4–8): XLF incompleto

Los objetos incorporados en Phase 1 (Codeunit, TableExtensions y PageExtensions) contienen
cadenas visibles que **todavía no tienen entradas en los XLF**. Esto bloquea la finalización
de Phase 1 según la DoD del proyecto.

| Objeto | Tipo | Cadenas pendientes |
|--------|------|--------------------|
| `Codeunit 50101 "DUoM Calc Engine"` | Codeunit | 4 labels de error |
| `TableExtension 50110 "DUoM Purchase Line Ext"` | TableExtension | 2 captions de campo |
| `TableExtension 50111 "DUoM Sales Line Ext"` | TableExtension | 2 captions de campo |
| `TableExtension 50112 "DUoM Item Journal Line Ext"` | TableExtension | 2 captions de campo |
| `TableExtension 50113 "DUoM Item Ledger Entry Ext"` | TableExtension | 2 captions de campo |
| `PageExtension 50101 "DUoM Purchase Order Subform"` | PageExtension | 2 tooltips de control |
| `PageExtension 50102 "DUoM Sales Order Subform"` | PageExtension | 2 tooltips de control |
| **Total pendiente** | | **~16 trans-units por idioma** |

**Cómo cerrar este hueco** (siguiendo el flujo de trabajo definido en la sección anterior):

1. Tras mergear el PR de Phase 1 en `main`, ejecutar el workflow `CI/CD` vía `workflow_dispatch`.
2. Descargar el artefacto `*-Apps-*.zip` y extraer `Translations/DualUoM-BC.g.xlf`.
3. Añadir los `<trans-unit>` con los IDs correctos a `en-US.xlf` y `es-ES.xlf`.
4. Subir los XLF actualizados en un commit inmediato sobre `main` (o PR dedicado de muy corto plazo).

> Phase 1 **no puede considerarse completo** hasta que este punto esté cerrado.

### Terminología nueva (Issues 4–8)

| Concepto | Inglés (en-US) | Español (es-ES) |
|----------|---------------|-----------------|
| Secondary quantity (field) | DUoM Second Qty | Segunda cantidad UdM Dual |
| Conversion ratio (field) | DUoM Ratio | Ratio UdM Dual |
| Engine error: negative qty | Quantity cannot be negative. | La cantidad no puede ser negativa. |
| Engine error: zero ratio fixed | Ratio must be greater than zero when Conversion Mode is Fixed. | El ratio debe ser mayor que cero cuando el modo de conversión es Fijo. |
| Engine error: negative ratio var | Ratio cannot be negative. | El ratio no puede ser negativo. |

---

## Riesgos y huecos detectados

| Riesgo | Descripción | Acción recomendada |
|--------|-------------|-------------------|
| IDs de controles de página | ✅ **Resuelto.** Los XLF ahora usan los IDs hash-based correctos obtenidos del `DualUoM-BC.g.xlf` generado por el compilador AL (runtime 15). | Para futuros cambios de páginas: descargar el artefacto `*-Apps-*.zip` del CI, extraerlo y copiar los IDs desde `Translations/DualUoM-BC.g.xlf`. |
| **Issues 2–8 (Phase 1 MVP) — XLF incompleto** | ⚠️ **Bloqueante.** ~16 cadenas en 7 objetos sin entradas XLF correctas. Ver sección "⚠️ Hueco conocido — Phase 1 MVP". | Seguir el proceso de cierre descrito en dicha sección. Phase 1 no es completo hasta resolverlo. |
| Phase 2 | Cuando se implementen módulos de Venta, Compra, Almacén o Lotes, habrá nuevas cadenas. | Aplicar esta guía desde el primer día de cada nueva issue. |
| ~~`codeunit 50100 "DualUoM Pipeline Check"`~~ | ~~Codeunit temporal sin textos visibles.~~ | ✅ Eliminado en PR de Issues 2–8. |

---

## Referencias

- [Microsoft Learn — Developing Multilanguage Extensions](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-multilanguage-development)
- [XLIFF 1.2 Specification](https://docs.oasis-open.org/xliff/v1.2/os/xliff-core.html)
- `.github/copilot-instructions.md` — Regla de localización (resumen ejecutivo)
- `CONTRIBUTING.md` — Guía de contribución para desarrolladores (incluye DoD y checklist de localización)
