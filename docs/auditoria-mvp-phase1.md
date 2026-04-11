# 🔍 Auditoría MVP Phase 1: Caption faltantes, page extension IJ, huecos TDD y doc inconsistente

## 🎯 Objetivo

Repaso integral del proyecto tras los Issues 2–8 para detectar y corregir inconsistencias, huecos de cobertura TDD y defectos de localización antes de arrancar Phase 2.

---

## 🐛 Hallazgos y correcciones requeridas

### 1. 🔴 Localización — `Caption` ausente en campos de table extensions

**Archivos afectados:**
- `app/src/tableextension/DUoMPurchaseLine.TableExt.al`
- `app/src/tableextension/DUoMSalesLine.TableExt.al`
- `app/src/tableextension/DUoMItemJournalLine.TableExt.al`
- `app/src/tableextension/DUoMItemLedgerEntry.TableExt.al`

**Problema:** Los campos `DUoM Second Qty` (50100) y `DUoM Ratio` (50101) en las cuatro table extensions **carecen de la propiedad `Caption`**. Sin ella:
- ❌ El compilador AL no genera entradas `<trans-unit>` en el `.g.xlf`.
- ❌ Los XLF (`en-US` y `es-ES`) no contienen esas cadenas → sin traducción posible al español.
- ❌ En la UI los campos aparecen con su nombre interno en inglés.
- ❌ Viola la regla de localización obligatoria del proyecto.

**Corrección:** Añadir `Caption = 'DUoM Second Qty';` y `Caption = 'DUoM Ratio';` a cada campo en las 4 table extensions y actualizar **ambos XLF** en el mismo PR.

---

### 2. 🔴 Page extension ausente: Item Journal

**Problema:** `DUoM Inventory Subscribers` (50104) implementa el cálculo automático al validar `Quantity` en `Item Journal Line`, pero **no existe ninguna page extension** para la página `Item Journal`. Consecuencias:
- ❌ Los usuarios no pueden ver los campos `DUoM Second Qty` ni `DUoM Ratio` en el diario de artículos.
- ❌ En modo `AlwaysVariable` no es posible introducir la cantidad manualmente desde la UI.
- ❌ La funcionalidad de inventario manual está incompleta a nivel de interfaz.

**Corrección:** Crear `DUoMItemJournalExt.PageExt.al` (ID **50103**) que extienda la página `Item Journal` con los campos DUoM. `DUoM Second Qty` debe ser editable solo en modo `AlwaysVariable` (lógica paralela a las subformas de Purchase y Sales). Actualizar ambos XLF con los nuevos ToolTips.

---

### 3. 🟡 TDD — Huecos de cobertura de tests

#### 3a. 🧪 Modo Variable con ratio predeterminado no nulo

**Problema:** No existe test que verifique que el subscriber auto-computa `DUoM Second Qty` en modo `Variable` cuando el ítem tiene un `Fixed Ratio` no nulo (usado como default). La cobertura actual solo prueba `Fixed` y `AlwaysVariable`.

**Corrección:** Añadir en `DUoMPurchaseTests` y `DUoMSalesTests` un test:
```
*_ValidateQty_VariableMode_ComputesSecondQty
```

#### 3b. 🧪 Override del ratio por línea en modo Variable

**Problema:** No hay test que demuestre que si se pre-establece `DUoM Ratio` en la línea **antes** de validar `Quantity`, el subscriber respeta ese ratio sin sobreescribirlo con el del setup del artículo.

**Corrección:** Añadir en Purchase y Sales:
```
*_ValidateQty_VariableMode_LineRatioOverridesItemDefault
```

#### 3c. 🧪 Trigger `OnValidate` de `DUoM Ratio` en table extensions

**Problema:** Los tres table extensions con `DUoM Ratio` (`PurchaseLine`, `SalesLine`, `Item Journal Line`) tienen un trigger `OnValidate` que recomputa `DUoM Second Qty` cuando el ratio cambia. **No existe ningún test para esta lógica.**

**Corrección:** Añadir en los codeunits de test correspondientes un test que:
1. Establezca `Quantity` en la línea.
2. Valide `DUoM Ratio` con un nuevo valor.
3. Compruebe que `DUoM Second Qty` se recalcula correctamente.

---

### 4. 🟡 Inconsistencia documental: nombre de librería de test

**Problema:** `copilot-instructions.md` (sección *AL Test Data Creation*) referencia la librería como `"Tests-Libraries"` (ID `5d86850b`), pero `test/app.json` y `.AL-Go/settings.json` usan el nombre real de Microsoft: **`"Tests-TestLibraries"`** con el mismo ID. Puede confundir a futuros contribuidores.

**Corrección:** Actualizar `copilot-instructions.md` para usar `Tests-TestLibraries`.

---

### 5. ✅ Verificado correcto — sin acción requerida

| Área | Estado |
|------|--------|
| Ambos XLF con 35 `<trans-unit>` completos, sin `needs-translation` | ✅ |
| Todos los `Label` tienen propiedad `Comment` | ✅ |
| Todos los codeunits de test con `TestPermissions = Disabled` | ✅ |
| `DUoMTestHelpers` usa `Init()+Insert(false)` sobre tabla de extensión propia | ✅ |
| Permission sets `50100` y `50200` cubren la tabla de extensión actual | ✅ |
| `runs-on: windows-2022` en ambos settings files | ✅ |
| Lógica de salida `OnAfterInitItemLedgEntry` (exit solo si AMBOS campos son cero) | ✅ |
| Cálculo en Fixed, Variable, AlwaysVariable del CalcEngine | ✅ |
| Propagación ILE desde Purchase y Sales a través de IJ Line | ✅ |

---

## ✅ Checklist de entregables

- [ ] 🏷️ **Captions en table extensions**: añadir `Caption` a los 8 campos (2 × 4 extensions) + actualizar ambos XLF.
- [ ] 📄 **Page extension Item Journal**: crear `DUoMItemJournalExt.PageExt.al` (ID 50103) + ToolTips + entradas XLF.
- [ ] 🧪 **Test Variable mode con default ratio** (Purchase + Sales).
- [ ] 🧪 **Test Variable mode: line ratio override** (Purchase + Sales).
- [ ] 🧪 **Tests `OnValidate DUoM Ratio`** (PurchaseLine, SalesLine, Item Journal Line).
- [ ] 📝 **Documentación**: corregir nombre de librería en `copilot-instructions.md`.

---

## 🏁 Criterio de completitud

- 🟢 Cero warnings con `PerTenantExtensionCop`, `CodeCop`, `UICop`.
- 🟢 Todos los trans-units en `en-US.xlf` con `state="final"` y `es-ES.xlf` con `state="translated"`. Sin `needs-translation`.
- 🟢 Cada nuevo test sigue el patrón `// [GIVEN] / [WHEN] / [THEN]` y usa las librerías estándar de test (`Library - Inventory`, `Library - Purchase`, `Library - Sales`).
- 🟢 Build CICD verde tras el PR.
