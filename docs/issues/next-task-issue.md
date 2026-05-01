# Issue 13 — Ratio Real por Lote (DUoM Lot Ratio)

> **⚠️ DOCUMENTO HISTÓRICO — Issue 13 está COMPLETADO.**
>
> Este documento fue la propuesta de tarea para Issue 13. La implementación se realizó
> en la fecha prevista incluyendo Issues 13, 20 y 21, que refactorizaron el modelo de
> lotes de 1:1 a 1:N y consolidaron la arquitectura correcta `TryApplyLotRatioToILE`.
> Posteriormente se completaron también Issues 22, 23, 24 y 154 relacionados con lotes.
>
> El **próximo issue pendiente** es **Issue 14 — Warehouse Basic Documents DUoM Fields**
> (soporte de campos DUoM en Warehouse Receipt/Shipment Lines).
>
> Ver `docs/06-backlog.md` sección "Estado vigente (fuente de verdad)" para el listado
> completo de issues completados y la priorización actualizada.

## 1. Título propuesto

**DualUoM — Issue 13: Ratio Real por Lote (`DUoM Lot Ratio`)**

---

## 2. Objetivo

Almacenar y recuperar el ratio de conversión real —medido en el momento del pesaje o
recepción— asociado a un número de lote específico. Cuando el usuario asigna un lote en
una línea de documento o diario, el sistema debe proponer automáticamente el ratio
registrado para ese lote, siempre que el modo de conversión sea Variable (no Fixed ni
AlwaysVariable).

---

## 3. Contexto

### Estado actual del repositorio

- **Phase 1 MVP:** completada (Issues 1–10).
- **Issue 11 (Rounding Precision):** ✅ implementado — `DUoM UoM Helper` (50106),
  `ComputeSecondQtyRounded` en `DUoM Calc Engine` (50101).
- **Issue 11b (Item Variants):** ✅ implementado — `DUoM Item Variant Setup` (50101),
  `DUoM Setup Resolver` (50107), jerarquía Item → Variante.
- **Issue 12 (Coste/Precio):** ✅ implementado — `DUoM Unit Cost` en líneas de compra,
  `DUoM Unit Price` en líneas de venta, `DUoM Value Entry Ext` (50121),
  `DUoM Cost Price Tests` (50216).
- **Issue 13 (Lote):** ✅ COMPLETADO — `DUoM Lot Ratio` (50102), `DUoM Lot Subscribers` (50108),
  `DUoM Lot Ratio Tests` (50217) y documentación completa implementados.

### Motivación funcional

En sectores agroalimentarios y similares, el ratio KG/PCS varía por lote
(p. ej., un lote de lechugas Romanas pesa de media 0,38 kg/unidad, mientras que otro
lote del mismo artículo pesa 0,41 kg/unidad). Registrar este ratio medido en el momento
de la recepción y reutilizarlo en todas las transacciones posteriores del lote evita
tener que introducirlo manualmente cada vez.

### Diseño jerárquico previsto

El `DUoM Setup Resolver` (50107) ya gestiona la jerarquía Item → Variante. El backlog
y el diseño técnico prevén un tercer nivel: Lote. La resolución de prioridad queda así:

```
1. Item Setup (master switch — Dual UoM Enabled)
2. Variant Override (si existe para el par Item No. / Variant Code)
3. Lot Ratio (si existe para el par Item No. / Lot No.) — solo en modo Variable
```

El ratio de lote **prevalece** sobre el ratio de variante/artículo cuando el modo es
Variable, pero **no modifica** los modos Fixed ni AlwaysVariable.

### IDs libres confirmados

| Tipo de objeto | ID libre siguiente |
|----------------|--------------------|
| Table          | **50102**          |
| Page           | **50102**          |
| Codeunit       | **50108**          |
| Test Codeunit  | **50217**          |

---

## 4. Alcance

### Dentro del alcance

- Nueva tabla `DUoM Lot Ratio` (50102): registros (Item No., Lot No., Actual Ratio,
  Description).
- Nueva página de lista `DUoM Lot Ratio List` (50102): mantenimiento de ratios por lote.
- Acción de apertura desde la `DUoM Item Setup` (page 50100) para navegar a los ratios
  de lote del artículo.
- Nuevo codeunit `DUoM Lot Subscribers` (50108): suscriptores a `Lot No.` en
  `Purchase Line`, `Sales Line` e `Item Journal Line`.
- Actualización de permission sets `DUoM - All` (50100) y `DUoM - Test All` (50200).
- XLF actualizado (`en-US` y `es-ES`) para todas las cadenas visibles por el usuario.
- Tests TDD (codeunit 50217): mínimo 5 tests que cubran los escenarios descritos en
  el apartado de Requisitos funcionales.
- Documentación: `docs/03-technical-architecture.md`, `docs/02-functional-design.md`,
  `docs/04-item-setup-model.md` y `docs/06-backlog.md` actualizados en el mismo PR.

### Fuera del alcance

Ver sección 7.

---

## 5. Requisitos funcionales

### RF-01 — Tabla de ratios por lote

- Existe una tabla dedicada `DUoM Lot Ratio` con clave primaria compuesta
  `(Item No., Lot No.)`.
- Campos adicionales: `Actual Ratio` (Decimal, 0:5, obligatorio > 0),
  `Description` (Text[100], opcional).
- El campo `Actual Ratio` debe impedir valores ≤ 0 (validación en tabla).

### RF-02 — Mantenimiento vía página de lista

- La página `DUoM Lot Ratio List` permite crear, editar y eliminar registros de ratio
  por lote.
- Es posible filtrarla por artículo desde la acción en `DUoM Item Setup` (page 50100).

### RF-03 — Pre-rellenado automático del ratio en línea de compra

- Cuando el usuario valida `Lot No.` en una `Purchase Line` para un artículo con
  DUoM activado y modo Variable:
  1. El sistema busca un registro en `DUoM Lot Ratio` para `(Item No., Lot No.)`.
  2. Si existe, escribe el `Actual Ratio` en el campo `DUoM Ratio` de la línea.
  3. A continuación recalcula `DUoM Second Qty` con la cantidad principal ya introducida
     y el nuevo ratio, usando `DUoM Calc Engine.ComputeSecondQtyRounded`.
- Si no existe registro de ratio para el lote, `DUoM Ratio` permanece sin cambios
  (respeta el valor previo o el default del artículo/variante).

### RF-04 — Pre-rellenado automático en línea de venta

- Mismo comportamiento que RF-03 pero en `Sales Line`.

### RF-05 — Pre-rellenado automático en línea de diario

- Mismo comportamiento que RF-03 pero en `Item Journal Line`.

### RF-06 — Modo Fixed: el ratio de lote NO sobreescribe

- Cuando el modo de conversión efectivo es `Fixed`, el ratio de lote **no** modifica
  `DUoM Ratio`. El ratio fijo siempre prevalece.

### RF-07 — Modo AlwaysVariable: el ratio de lote SÍ se pre-rellena

- Cuando el modo es `AlwaysVariable`, si existe un ratio para el lote, se pre-rellena
  `DUoM Ratio` como sugerencia editable (el usuario puede sobreescribirlo).
  Esto facilita la operativa sin eliminar la flexibilidad del modo.

### RF-08 — Propagación a documentos históricos y a ILE

- El campo `DUoM Ratio` ya se propaga a históricos e ILE mediante los suscriptores
  existentes. No se requieren cambios en ese flujo; el ratio de lote llega a los
  históricos a través del valor ya escrito en `DUoM Ratio` de la línea origen.

---

## 6. Requisitos técnicos

### RT-01 — Nuevo codeunit `DUoM Lot Subscribers` (50108)

- `Access = Internal`.
- Suscriptores independientes para `Purchase Line`, `Sales Line` e `Item Journal Line`,
  en el evento `OnAfterValidateEvent` del campo `Lot No.` de cada tabla.
- Cada suscriptor llama a un método centralizado (no duplicar lógica).
- Firmas a usar en BC 27 (verificar en Symbol Reference antes de implementar):
  - `[EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnAfterValidateEvent', 'Lot No.', false, false)]`
  - `[EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'Lot No.', false, false)]`
  - `[EventSubscriber(ObjectType::Table, Database::"Item Journal Line", 'OnAfterValidateEvent', 'Lot No.', false, false)]`

> **Verificación obligatoria:** antes de implementar, confirmar que `'Lot No.'` es el
> nombre exacto del campo en BC 27 (puede estar en `Item Tracking Lines` únicamente o
> también en la línea principal). Si el campo `Lot No.` no existe directamente en
> `Purchase Line` / `Sales Line`, documentar la alternativa correcta y justificar en
> un comentario en el subscriber.

### RT-02 — Método helper centralizado en `DUoM Lot Subscribers`

- Procedimiento local `ApplyLotRatioIfExists(ItemNo, LotNo, ConversionMode, var DUoMRatio, var DUoMSecondQty, Quantity, ItemNo2)`:
  - Lee `DUoM Lot Ratio` para el par `(ItemNo, LotNo)`.
  - En modo `Fixed`: sale sin modificar nada.
  - En modos `Variable` y `AlwaysVariable`: si existe el registro, sobreescribe
    `DUoMRatio` y recalcula `DUoMSecondQty`.

### RT-03 — Tabla `DUoM Lot Ratio` (50102)

- `DataClassification = CustomerContent` en todos los campos.
- `LookupPageId` y `DrillDownPageId` apuntando a la página `DUoM Lot Ratio List`.
- Relación de tabla con `Item` (TableRelation) en el campo `Item No.` y con
  `Item Tracking Code` / `Lot No. Info` **si** existen en BC 27 (a verificar);
  de lo contrario dejar sin TableRelation estricta para mayor flexibilidad.
- Validación en `OnValidate` de `Actual Ratio`: lanzar error con `Label` si valor ≤ 0.

### RT-04 — Página `DUoM Lot Ratio List` (50102)

- Tipo: `List`.
- Columnas: `Item No.`, `Lot No.`, `Actual Ratio`, `Description`.
- SourceTable: `DUoM Lot Ratio`.
- Accesible como lookup standalone y desde la acción en `DUoM Item Setup`.

### RT-05 — Acción en `DUoM Item Setup` (page 50100)

- Añadir una acción `DUoM Lot Ratios` en el grupo de acciones existente que abra
  `DUoM Lot Ratio List` filtrado por el `Item No.` actual.

### RT-06 — Permission sets

- `tabledata "DUoM Lot Ratio" = RIMD` en **ambos** permission sets:
  - `app/src/permissionset/DUoMAll.PermissionSet.al` (50100)
  - `test/src/permissionset/DUoMTestAll.PermissionSet.al` (50200)

### RT-07 — Localization (obligatorio)

- Todos los textos visibles por el usuario (captions, tooltips, errores) deben
  declararse como variables `Label` con propiedad `Comment`.
- Ambos ficheros XLF actualizados en el mismo PR:
  - `app/Translations/DualUoM-BC.en-US.xlf`
  - `app/Translations/DualUoM-BC.es-ES.xlf`

### RT-08 — TDD estricto

- Escribir el codeunit de test `DUoM Lot Ratio Tests` (50217) con todos los tests en
  estado **fallando** antes de implementar el código de producción.
- Usar `// [GIVEN] / [WHEN] / [THEN]` en cada test.
- Usar `Library Assert` para todas las aserciones.
- Usar `LibraryPurchase`, `LibrarySales`, `LibraryInventory` para creación de datos;
  `DUoM Test Helpers` para setup DUoM.
- `Subtype = Test; TestPermissions = Disabled;` en el codeunit.

### RT-09 — Longitud de nombres de objetos

- Verificar que ningún nombre de objeto supera 30 caracteres (AL0305):
  - `"DUoM Lot Ratio"` = 14 chars ✅
  - `"DUoM Lot Ratio List"` = 19 chars ✅
  - `"DUoM Lot Subscribers"` = 20 chars ✅
  - `"DUoM Lot Ratio Tests"` = 20 chars ✅

### RT-10 — Documentación (obligatorio por regla del proyecto)

Actualizar en el mismo PR:
- `docs/02-functional-design.md` — sección "Lot-Specific Real Ratio" con el diseño
  implementado.
- `docs/03-technical-architecture.md` — añadir `DUoM Lot Ratio` en las tablas de
  objetos y suscriptores.
- `docs/04-item-setup-model.md` — añadir nivel "Lote" en la jerarquía de resolución.
- `docs/06-backlog.md` — marcar Issue 13 como ✅ IMPLEMENTADO.
- `docs/TestCoverageAudit.md` — añadir `DUoM Lot Ratio` (50102) y `DUoM Lot Subscribers`
  (50108) en el inventario de objetos y en la matriz de cobertura.

---

## 7. Exclusiones

Las siguientes funcionalidades quedan explícitamente **fuera del alcance** de este issue:

| Exclusión | Issue futuro |
|-----------|-------------|
| Soporte de lote en documentos de almacén (Warehouse Receipt/Shipment Lines) | Issue 14 |
| Soporte de lote en actividades de almacén dirigido (Directed Put-Away/Pick) | Issue 15 |
| Soporte de lote en documentos de devolución (`Return Shipment`, `Return Receipt`) | Issue 16 |
| Inventario físico con segunda cantidad | Issue 17 |
| Informes con columnas DUoM | Issue 18 |
| Integración con `Item Tracking Lines` (página estándar de trazabilidad) | Phase 3+ |
| Múltiples lotes por línea de documento | Fuera de alcance MVP |
| Historial o auditoría de cambios de ratio por lote | Fuera de alcance MVP |

---

## 8. Checklist de validación (Definition of Done)

### Código y tests

- [ ] **T01** — Lote con ratio registrado, `Lot No.` validado en `Purchase Line` (modo Variable)
  → `DUoM Ratio` = ratio del lote; `DUoM Second Qty` recalculada correctamente.
- [ ] **T02** — Lote **sin** ratio registrado, `Lot No.` validado en `Purchase Line`
  → `DUoM Ratio` sin cambios (mantiene valor previo).
- [ ] **T03** — Lote con ratio registrado, modo **Fixed**
  → `DUoM Ratio` **no** sobreescrito (ratio fijo prevalece).
- [ ] **T04** — Lote con ratio registrado, `Lot No.` validado en `Sales Line` (modo Variable)
  → `DUoM Ratio` pre-rellenado; `DUoM Second Qty` recalculada.
- [ ] **T05** — Lote con ratio registrado, `Lot No.` validado en `Item Journal Line` (modo Variable)
  → `DUoM Ratio` pre-rellenado; `DUoM Second Qty` recalculada.
- [ ] **T06** — `Actual Ratio ≤ 0` en tabla `DUoM Lot Ratio`
  → error de validación con mensaje localizado.
- [ ] **T07** *(recomendado)* — Flujo E2E compra con lote: creación pedido con lote →
  validación lote pre-rellena ratio → contabilización → ILE con `DUoM Second Qty` correcto.

### Calidad

- [ ] Cero warnings de `PerTenantExtensionCop`, `CodeCop` y `UICop`.
- [ ] Sin `with` implícito (`NoImplicitWith`).
- [ ] Sin uso de `Permissions` en codeunits (AL0246).
- [ ] Todos los `Label` tienen propiedad `Comment` (con descripción o `'Sin placeholders.'`).
- [ ] Nombres de objetos ≤ 30 caracteres.

### Localización

- [ ] `DualUoM-BC.en-US.xlf` actualizado con todos los nuevos `trans-unit`.
- [ ] `DualUoM-BC.es-ES.xlf` actualizado con las traducciones al español.

### Permission sets

- [ ] `tabledata "DUoM Lot Ratio" = RIMD` en `DUoMAll.PermissionSet.al`.
- [ ] `tabledata "DUoM Lot Ratio" = RIMD` en `DUoMTestAll.PermissionSet.al`.

### Documentación

- [ ] `docs/02-functional-design.md` actualizado (sección Lot-Specific Real Ratio).
- [ ] `docs/03-technical-architecture.md` actualizado (Object Structure).
- [ ] `docs/04-item-setup-model.md` actualizado (jerarquía resolución con nivel Lote).
- [ ] `docs/06-backlog.md` — Issue 13 marcado ✅ IMPLEMENTADO.
- [ ] `docs/TestCoverageAudit.md` actualizado.
- [ ] `docs/issues/` — fichero de issue creado en `docs/issues/issue-13-lot-ratio.md`.

---

## 9. Riesgos y dependencias

### Dependencias previas (todas completadas)

| Issue | Estado |
|-------|--------|
| Issue 2 — DUoM Calc Engine | ✅ |
| Issue 3 — Item DUoM Setup | ✅ |
| Issue 4 / 6 — Purchase/Sales Line DUoM Fields | ✅ |
| Issue 8 — Item Journal DUoM Fields | ✅ |
| Issue 11 — Rounding Precision | ✅ |
| Issue 11b — Item Variants | ✅ |
| Issue 12 — Coste/Precio en doble UoM | ✅ |

### Riesgos técnicos

| Riesgo | Probabilidad | Mitigación |
|--------|-------------|-----------|
| **[VERIFICADO - 2026-04-22]** `Lot No.` NO es campo directo en `Purchase Line` / `Sales Line` en BC 27 (reside SOLO en `Item Tracking Lines`) | Confirmado | Código especulativo removido. Issue 13 (Phase 2) debe diseñarse alrededor de Item Tracking Lines. Discovery obligatorio antes de implementar. |
| Colisión de IDs si otro issue paralelo reserva el mismo rango | Baja | Confirmar en `docs/06-backlog.md` que los IDs 50102 (table, page) y 50108 (codeunit) siguen libres antes de crear objetos. |
| `TableRelation` con `Lot No. Info` o tablas de trazabilidad de BC puede fallar si la tabla no es accesible en extensiones PTE | Baja-Media | Usar `TableRelation` sin validación estricta si la tabla de trazabilidad no está disponible para extensiones. Documentar la decisión. |
| Tests que requieren creación de `Item Tracking Lines` pueden ser frágiles en entornos SaaS sin licencia de ítem tracking | Baja | Usar `Library - Item Tracking` si existe, o crear el registro `DUoM Lot Ratio` directamente en el test sin pasar por el flujo completo de tracking estándar de BC. Priorizar tests que validen el comportamiento del subscriber DUoM, no el flujo nativo de BC. |

---

## 10. Instrucciones adicionales para @copilot

### Estrategia TDD — ACTUALIZADO (Cambio de scope Phase 2)

**NOTA IMPORTANTE (2026-04-22):** El diseño anterior de Issue 13 fue especulativo. 
Se descubrió que "Lot No." no es campo directo en Purchase Line / Sales Line en BC 27.
Por lo tanto, los tests y lógica de suscriptores especulativos han sido removidos del código.

Para Phase 2 (Issue 13 rediseñado):

1. **Primero:** sesión de discovery de Item Tracking Lines en BC 27:
   - Estructura de `Item Tracking Line` table (campos, eventos disponibles)
   - Cómo se asignan múltiples lotes a una línea de documento
   - Eventos de validación/posting en Item Tracking Line
   
2. **Segundo:** actualizar diseño en docs (02-functional-design, 03-technical-architecture)
   con la arquitectura Item Tracking correcta.

3. **Tercero:** crear tabla intermedia o extensión para asociar ratios DUoM a Item Tracking Lines.

4. **Cuarto:** implementar suscriptores en Item Tracking Line (no en Purchase/Sales Line).

5. **Quinto:** tests TDD cubriendo el flujo multi-lote correcto.

### Verificación COMPLETADA — "Lot No." en BC 27

**Hallazgo:** Se verificó en BC 27 Symbol Reference que `Lot No.` **NO es campo directo**
en `Purchase Line` (table 39) ni `Sales Line` (table 37). Los números de lote se gestionan
exclusivamente a través de `Item Tracking Lines` (table 6500).

Conclusión: El diseño anterior (MVP) de Issue 13 con suscriptores en Purchase/Sales Line
fue especulativo y ha sido removido del código (2026-04-22). La verdadera integración multi-lote
requiere suscriptores en Item Tracking Line en Phase 2.

### Patrón de suscriptor delegante (thin subscriber)

Seguir el mismo patrón que `DUoM Purchase Subscribers` (50102):

```al
// Suscriptor thin — solo valida y delega
[EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnAfterValidateEvent', 'Lot No.', false, false)]
local procedure OnAfterValidatePurchLineLotNo(var Rec: Record "Purchase Line"; var xRec: Record "Purchase Line")
var
    DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
    SecondUoMCode: Code[10];
    ConversionMode: Enum "DUoM Conversion Mode";
    FixedRatio: Decimal;
begin
    if Rec.Type <> Rec.Type::Item then exit;
    if Rec."No." = '' then exit;
    if not DUoMSetupResolver.GetEffectiveSetup(Rec."No.", Rec."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then exit;
    // Lógica centralizada en método local o helper
    ApplyLotRatioIfExists(Rec, ConversionMode, SecondUoMCode);
end;
```

### Validación de ratio en tabla

```al
// En DUoMActualRatio.OnValidate() de table 50102
if "Actual Ratio" <= 0 then
    Error(ErrActualRatioMustBePositiveLbl);
```

Con `ErrActualRatioMustBePositiveLbl` como `Label` con `Comment`.

### IDs de objetos a usar

| Objeto | ID |
|--------|----|
| `DUoM Lot Ratio` (table) | **50102** |
| `DUoM Lot Ratio List` (page) | **50102** |
| `DUoM Lot Subscribers` (codeunit) | **50108** |
| `DUoM Lot Ratio Tests` (test codeunit) | **50217** |

### Etiquetas recomendadas para el PR

`enhancement`, `phase-2`, `lot-tracking`, `tdd`, `al`

---

*Documento generado como propuesta de siguiente tarea. Basado en el análisis del estado
real del repositorio a fecha 2026-04-22: Phase 1 completada, Issues 11/11b/12 implementados,
ningún objeto de ratio por lote existe en el repositorio.*
