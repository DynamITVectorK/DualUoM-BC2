# Arquitectura Técnica — DualUoM-BC

## Enfoque de solo extensión

La solución se entrega exclusivamente como una **extensión de inquilino propio (PTE)** que se ejecuta en
Business Central SaaS. No se modifica ningún código de la aplicación base. Todas las adiciones usan:

- Extensiones de tabla (`tableextension`) para añadir campos a las tablas estándar
- Extensiones de página (`pageextension`) para mostrar los nuevos campos en las páginas existentes
- Nuevas tablas y páginas personalizadas para la configuración específica de DUoM
- Suscriptores de eventos para interceptar los flujos estándar de contabilización, validación y cálculo
- Codeunits para la lógica de negocio, completamente independientes del código estándar

Esto garantiza la compatibilidad con futuras actualizaciones de BC y una desinstalación segura.

---

## Principios de diseño seguros para SaaS

| Principio | Justificación |
|---|---|
| Sin acceso directo a tablas internas de BC mediante `RecordRef` cuando sea evitable | Frágil ante cambios de esquema |
| Sin suscriptores `OnBeforeInsert`/`OnBeforeModify` que lancen errores a mitad de flujo | Preferir `OnAfterValidate` y codeunits de validación dedicados |
| Sin campos `BLOB` salvo que sea inevitable | Riesgo de rendimiento y actualización |
| Sin IDs de objeto hardcodeados de la aplicación base | Usar `Codeunit.RUN` y `Page.RUN` por nombre donde sea posible |
| Sin APIs deprecadas de BC | Usar siempre los patrones de la versión actual |
| Sin lógica que bloquee la UI en disparadores de tabla | Mover la validación a la capa de página/codeunit |

---

## Filosofía estándar primero

Antes de añadir cualquier nuevo campo, tabla o lógica, considerar si un mecanismo estándar de BC
ya cubre la necesidad:

- Usar la tabla existente `Item Unit of Measure` para los datos base de ratio fijo
- Usar la infraestructura existente de `Item Tracking` para el vínculo de lotes (Fase 2)
- Usar la estructura existente de `Warehouse Activity Line` para las extensiones de almacén (Fase 2)
- Solo extender o añadir cuando BC estándar genuinamente no pueda soportar el requisito

---

## Estructura de objetos

### Tablas personalizadas

| Objeto | ID | Propósito |
|---|---|---|
| `DUoM Item Setup` | 50100 | Configuración DUoM por artículo (habilitado, segunda UdM, modo, ratio) |

### Extensiones de tabla

| Objeto | ID | Tabla extendida | Propósito |
|---|---|---|---|
| `DUoM Purchase Line Ext` | 50110 | `Purchase Line` | Campos de segunda cantidad y ratio |
| `DUoM Sales Line Ext` | 50111 | `Sales Line` | Campos de segunda cantidad y ratio |
| `DUoM Item Journal Line Ext` | 50112 | `Item Journal Line` | Campos de segunda cantidad y ratio |
| `DUoM Item Ledger Entry Ext` | 50113 | `Item Ledger Entry` | Segunda cantidad y ratio (contabilizado, inmutable) |

_Los IDs exactos de objeto se asignan en el momento de la implementación dentro del rango 50100–50199._

### Codeunits

| Objeto | ID | Propósito |
|---|---|---|
| `DualUoM Pipeline Check` | 50100 | Validación del pipeline de compilación (temporal) |
| `DUoM Calc Engine` | 50101 | Cálculo y validación de la segunda cantidad (núcleo) |
| `DUoM Purchase Subscribers` | 50102 | Suscriptores de eventos para el flujo de compras |
| `DUoM Sales Subscribers` | 50103 | Suscriptores de eventos para el flujo de ventas |
| `DUoM Inventory Subscribers` | 50104 | Suscriptores de eventos para el flujo de diario de artículos / ILE |

---

## Diseño basado en eventos

Toda la integración con los flujos estándar de BC se realiza mediante **eventos de integración publicados**
(`[IntegrationEvent(false, false)]`) y **eventos de negocio** donde estén disponibles.

Los codeunits de suscriptores se mantienen pequeños y enfocados. Cada módulo (Compras, Ventas, Inventario,
Almacén) tiene su propio codeunit de suscriptores para limitar el impacto de los cambios.

Ningún codeunit de suscriptores debe contener lógica de contabilización. La lógica de contabilización reside en codeunits
dedicados llamados desde los suscriptores.

---

## Expectativas de pruebas primero

- Cada codeunit debe tener un codeunit de prueba correspondiente en `test/src/codeunit/`
- Las pruebas usan el framework estándar de pruebas AL (`Subtype = Test`)
- `Library Assert` (Microsoft) es la única biblioteca de aserciones permitida
- Ningún código de producción se fusiona sin al menos una prueba que pase y cubra el nuevo comportamiento
- Ver `docs/05-testing-strategy.md` para la estrategia completa

---

## Arquitectura preparada para actualizaciones

- Sin migraciones de datos en el MVP (aún no existen datos)
- Cuando las migraciones de datos sean necesarias, usar `OnUpgradePerCompany` / `OnInstallAppPerCompany`
  en un codeunit de instalación/actualización dedicado
- Los campos de extensiones de tabla usan `ObsoleteState` apropiadamente cuando se deprecan
- Nunca renombrar ni renumerar objetos publicados existentes — crear nuevos en su lugar
