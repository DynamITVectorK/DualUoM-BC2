# Issue 10 — Corrección de errores de compilación por incompatibilidades con BC 27 API + reglas preventivas

## Contexto

El build actual falla con **10 errores y 1 warning** introducidos en la implementación del Issue 9.
Los errores provienen de dos fuentes:

1. **Nombres de objeto AL superan el límite de 30 caracteres** (`AL0305`) y referencian
   **páginas estándar que no existen** con esos nombres en BC 27 (`AL0247`), en los page extensions
   de subformularios de documentos contabilizados.
2. **Suscriptores de eventos incompatibles con BC 27** (`AL0280`, `AL0282`) en
   `DUoMInventorySubscribers.Codeunit.al` (codeunit 50104):
   - El evento `OnAfterInsertReceiptLine` ya no existe en `Codeunit "Purch.-Post"` en BC 27.
   - El parámetro `SalesShipmentLine` del evento `OnAfterInsertShipmentLine` en `Codeunit "Sales-Post"`
     fue renombrado en BC 27.

Adicionalmente, el proyecto **carece de reglas documentadas** que prevengan la introducción de
incompatibilidades de API de BC en futuros cambios.

---

## Errores exactos

| Archivo | Línea | Código | Descripción |
|---------|-------|--------|-------------|
| `DUoMPostedSalesShipSubform.PageExt.al` | L7 | AL0305 | Identificador `'DUoM Posted Sales Ship. Subform'` supera 30 caracteres |
| `DUoMPostedSalesShipSubform.PageExt.al` | L7 | AL0247 | Página objetivo `'Posted Sales Shipment Subform'` no encontrada en BC 27 |
| `DUoMPostedSalesShipSubform.PageExt.al` | L13 | AL0118 | `'Rec'` no existe en el contexto actual (consecuencia de AL0247) |
| `DUoMPostedSalesShipSubform.PageExt.al` | L20 | AL0118 | `'Rec'` no existe en el contexto actual (consecuencia de AL0247) |
| `DUoMPostedPurchRcptSubform.PageExt.al` | L7 | AL0305 | Identificador `'DUoM Posted Purch. Rcpt. Subform'` supera 30 caracteres |
| `DUoMPostedPurchRcptSubform.PageExt.al` | L7 | AL0247 | Página objetivo `'Posted Purchase Receipt Subform'` no encontrada en BC 27 |
| `DUoMPostedPurchRcptSubform.PageExt.al` | L13 | AL0118 | `'Rec'` no existe en el contexto actual (consecuencia de AL0247) |
| `DUoMPostedPurchRcptSubform.PageExt.al` | L20 | AL0118 | `'Rec'` no existe en el contexto actual (consecuencia de AL0247) |
| `DUoMInventorySubscribers.Codeunit.al` | L79 | AL0280 | Evento `'OnAfterInsertReceiptLine'` no encontrado en `Codeunit Microsoft.Purchases.Posting."Purch.-Post"` |
| `DUoMInventorySubscribers.Codeunit.al` | L95 | AL0282 | Parámetro `'SalesShipmentLine'` no encontrado en el suscriptor `'OnAfterInsertShipmentLine'` |

---

## Objetivo

1. **Corregir los 10 errores de compilación** para que el build vuelva a pasar en BC 27.
2. **Añadir reglas documentadas al repositorio** que impidan que este tipo de incompatibilidades
   de API vuelvan a introducirse sin detección temprana.

---

## Tareas de corrección

### Tarea A — Corregir page extensions de documentos contabilizados

**Archivos afectados:**
- `app/src/pageextension/DUoMPostedSalesShipSubform.PageExt.al`
- `app/src/pageextension/DUoMPostedPurchRcptSubform.PageExt.al`

**Problema 1 — Nombres de objeto demasiado largos (AL0305)**

Los identificadores de objeto superan el límite de 30 caracteres de AL:

| Nombre actual (incorrecto) | Longitud | Nombre propuesto |
|----------------------------|----------|-----------------|
| `DUoM Posted Sales Ship. Subform` | 32 | `DUoM Posted Ship. Subform` |
| `DUoM Posted Purch. Rcpt. Subform` | 34 | `DUoM Posted Rcpt. Subform` |

**Problema 2 — Nombres de página objetivo incorrectos (AL0247)**

En BC 27, las páginas de subformulario de documentos contabilizados tienen nombres distintos
a los usados en la implementación. Antes de corregir, **verificar en el BC Symbol Reference**
(o en `Microsoft_Base Application_27.x.x.x.app`) los nombres exactos de las páginas que
extienden los subformularios de:

- Albarán de compra contabilizado → candidato: `"Purch. Rcpt. Subform"` (Page 6662)
- Envío de venta contabilizado → candidato: `"Sales Shipment Subform"` (Page 6631)

> ⚠️ Verificar los nombres exactos antes de implementar. No asumir los candidatos sin validar
> contra el Symbol Reference de BC 27.

Una vez confirmados, actualizar la cláusula `extends` en ambos ficheros y ajustar el nombre
del objeto a ≤ 30 caracteres.

Los errores AL0118 sobre `'Rec'` desaparecerán automáticamente al resolver AL0247.

---

### Tarea B — Corregir suscriptores de eventos en `DUoMInventorySubscribers`

**Archivo afectado:**
- `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al`

**Problema 1 — Evento renombrado en BC 27 (AL0280, línea 79)**

El evento `OnAfterInsertReceiptLine` ya **no existe** en `Codeunit "Purch.-Post"` bajo el
namespace `Microsoft.Purchases.Posting` en BC 27.

Investigar el Symbol Reference de BC 27 para encontrar el evento equivalente que se dispara
tras insertar una `Purch. Rcpt. Line` durante la contabilización de una orden de compra.
Candidatos a verificar:

- `OnAfterInsertPostedRcptLine`
- `OnAfterPurchRcptLineInsert`
- Otro nombre según BC 27 Symbol Reference

Una vez identificado el nombre correcto, actualizar el atributo `[EventSubscriber]` en la
línea 79 y ajustar la firma del procedimiento `OnAfterInsertReceiptLine` si los parámetros
también cambiaron.

**Problema 2 — Parámetro renombrado en BC 27 (AL0282, línea 95)**

El evento `OnAfterInsertShipmentLine` en `Codeunit "Sales-Post"` **sí existe** en BC 27,
pero el parámetro `SalesShipmentLine: Record "Sales Shipment Line"` fue renombrado.

Investigar el Symbol Reference de BC 27 para confirmar el nombre exacto del parámetro.
Candidatos:

- `SalesShipLine`
- Otro nombre según BC 27 Symbol Reference

Actualizar únicamente el nombre del parámetro en la firma del procedimiento suscriptor
(línea 95) para que coincida con el nombre que espera BC 27.

> **Nota:** El cuerpo del procedimiento no debería necesitar cambios salvo que también
> cambie el tipo del registro.

---

### Tarea C — Verificar XLF si se modifican Captions o ToolTips

Si las correcciones anteriores implican cambiar captions, tooltips u otros textos visibles,
actualizar **ambos** archivos XLF en el mismo PR siguiendo el flujo de `docs/07-localization.md`.

---

### Tarea D — Actualizar tests si la firma de evento cambia

Si el cambio en `OnAfterInsertReceiptLine` o `OnAfterInsertShipmentLine` altera la lógica de
propagación, revisar si los tests E2E de `DUoMILEIntegrationTests` (codeunit 50209) cubren
correctamente los nuevos flujos y añadir o ajustar casos de prueba según sea necesario.

---

## Reglas preventivas a añadir al repositorio

Además de corregir los errores, este issue debe establecer las siguientes reglas en la
documentación del repositorio para evitar que estas categorías de errores se repitan.

### Regla 1 — Límite de 30 caracteres en identificadores de objeto AL (AL0305)

**Dónde añadir:** `CONTRIBUTING.md` (sección "Ciclo de desarrollo") y
`.github/copilot-instructions.md` (sección "AL coding conventions").

**Texto a añadir:**

> Los nombres de todos los objetos AL (tablas, páginas, codeunits, page extensions, etc.)
> **no pueden superar los 30 caracteres** (límite del compilador AL, error AL0305).
> Verificar la longitud antes de abrir un PR. Los nombres de page extensions deben ser
> especialmente compactos para dejar margen al prefijo `DUoM`.

---

### Regla 2 — Verificación de API de BC 27 antes de usar eventos de suscriptor

**Dónde añadir:** `CONTRIBUTING.md` (nueva sección "Compatibilidad de API BC 27") y
`.github/copilot-instructions.md` (sección "Business Central SaaS constraints").

**Texto a añadir:**

> **Antes de implementar cualquier `[EventSubscriber]`** que apunte a un codeunit estándar
> de Microsoft (por ejemplo `Purch.-Post`, `Sales-Post`, `Item Jnl.-Post Line`), verificar
> que el evento y todos sus parámetros existen en la versión BC 27 (runtime 15) consultando:
>
> - El **BC Symbol Reference** en VS Code (extensión AL).
> - El repositorio público [microsoft/ALAppExtensions](https://github.com/microsoft/ALAppExtensions).
>
> Los eventos de BC cambian entre versiones (renombrados, parámetros modificados, eliminados).
> Un suscriptor que apunta a un evento inexistente provoca AL0280 o AL0282 y rompe el build.

---

### Regla 3 — Verificación de nombres de páginas estándar antes de usar `extends`

**Dónde añadir:** `CONTRIBUTING.md` (sección "Regla de compatibilidad de API BC 27") y
`.github/copilot-instructions.md`.

**Texto a añadir:**

> **Antes de crear un `pageextension`** que extienda una página estándar de Microsoft,
> verificar que la página existe en BC 27 con ese nombre exacto consultando el
> Symbol Reference de BC 27.  
> Los nombres de páginas estándar han cambiado en varias versiones (renombrados, movidos
> a namespaces). Una cláusula `extends` con un nombre incorrecto provoca AL0247 y bloquea
> toda la compilación del módulo donde aparece.

---

### Regla 4 — Checklist de PR actualizado en CONTRIBUTING.md

Añadir los siguientes puntos al bloque **Definition of Done** en `CONTRIBUTING.md`:

```markdown
- [ ] Todos los nombres de objeto AL tienen ≤ 30 caracteres.
- [ ] Todos los `[EventSubscriber]` han sido verificados contra el Symbol Reference de BC 27
      (nombre de evento y parámetros correctos).
- [ ] Todos los `pageextension` han sido verificados contra el Symbol Reference de BC 27
      (nombre exacto de la página objetivo).
```

---

## Archivos a modificar

| Archivo | Tipo de cambio |
|---------|---------------|
| `app/src/pageextension/DUoMPostedSalesShipSubform.PageExt.al` | Renombrar objeto, corregir `extends` |
| `app/src/pageextension/DUoMPostedPurchRcptSubform.PageExt.al` | Renombrar objeto, corregir `extends` |
| `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al` | Corregir evento L79, corregir parámetro L95 |
| `CONTRIBUTING.md` | Añadir reglas preventivas (Reglas 1–4) |
| `.github/copilot-instructions.md` | Añadir reglas preventivas (Reglas 2–3) |
| `app/Translations/DualUoM-BC.en-US.xlf` | Solo si cambian textos visibles |
| `app/Translations/DualUoM-BC.es-ES.xlf` | Solo si cambian textos visibles |
| `test/src/codeunit/DUoMILEIntegrationTests.Codeunit.al` (50209) | Solo si cambia la lógica de propagación |

---

## Definition of Done

- [ ] El build compila sin ningún error ni warning en BC 27 (runtime 15).
- [ ] Los 10 errores descritos en la tabla anterior han desaparecido.
- [ ] Los page extensions apuntan a páginas que existen en BC 27 con nombres ≤ 30 caracteres.
- [ ] Los suscriptores `OnAfterInsertReceiptLine` y `OnAfterInsertShipmentLine` usan los
      nombres de evento y parámetros correctos en BC 27.
- [ ] `CONTRIBUTING.md` incluye las reglas preventivas 1–4.
- [ ] `.github/copilot-instructions.md` incluye las reglas preventivas 2–3.
- [ ] Ambos XLF actualizados si se modificaron textos visibles.
- [ ] Los tests E2E de `DUoMILEIntegrationTests` (50209) siguen siendo válidos o han
      sido ajustados.
- [ ] No se han introducido regresiones en los tests existentes.
