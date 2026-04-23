# Manual de Usuario — DualUoM-BC

**Extensión de Doble Unidad de Medida para Microsoft Dynamics 365 Business Central**

> **Versión del documento:** 1.2 (MVP + Issues 11b + 13 — Variantes + Ratios por Lote)
> **Módulos cubiertos:** Compras · Ventas · Inventario · Almacén (básico)
> **Audiencia:** Usuarios de negocio (sin conocimientos técnicos)

---

## Índice

1. [Introducción](#1-introducción)
2. [Configuración del artículo](#2-configuración-del-artículo)
   - [2.1 Cómo acceder a la configuración DUoM](#cómo-acceder-a-la-configuración-duom-de-un-artículo)
   - [2.2 Campos y modos de conversión](#campos-de-configuración-duom)
   - [2.3 Precisión de redondeo de la segunda UdM](#23-precisión-de-redondeo-de-la-segunda-udm)
   - [2.4 Configuración DUoM por variante (override opcional)](#24-configuración-duom-por-variante-override-opcional)
   - [2.5 DUoM Unit Cost (compras) y DUoM Unit Price (ventas)](#25-duom-unit-cost-compras-y-duom-unit-price-ventas)
3. [Compras](#3-compras)
4. [Ventas](#4-ventas)
5. [Inventario — Diario de productos](#5-inventario--diario-de-productos)
6. [Almacén (básico)](#6-almacén-básico)
7. [Consultas y análisis](#7-consultas-y-análisis)
8. [Preguntas frecuentes (FAQ)](#8-preguntas-frecuentes-faq)
9. [Ratios específicos por lote](#9-ratios-específicos-por-lote)

---

## 1. Introducción

### ¿Qué es la Doble Unidad de Medida (DUoM)?

La extensión **DualUoM-BC** añade a Business Central la capacidad de registrar **dos cantidades independientes** en cada transacción de un artículo: la cantidad principal (primera UdM) y una cantidad secundaria (segunda UdM). Ambas se almacenan, contabilizan y rastrean a lo largo del ciclo completo de compra, venta, inventario y almacén.

### Ejemplos de negocio reales

| Situación | Primera UdM | Segunda UdM | ¿Por qué es útil? |
|-----------|-------------|-------------|-------------------|
| Compra de lechuga fresca | 10 KG (facturado al peso) | 8 PCS (recibido en cajas) | El proveedor factura por kilo; el almacén cuenta cajas |
| Venta de queso curado | 2 PCS (piezas) | 1,85 KG (peso real pesado) | El cliente paga por kilo pero el pedido se gestiona por piezas |
| Ajuste de inventario de tornillos | 500 PCS (unidades) | 2,5 KG (peso para transporte) | Necesario para optimizar el embalaje y la logística |

### Conceptos clave

| Término | Definición |
|---------|------------|
| **Primera UdM** | Unidad de medida principal del artículo (ej. KG). Coincide con la UdM base del artículo en BC. |
| **Segunda UdM** | Unidad de medida secundaria configurada en DUoM (ej. PCS). |
| **Segunda Qty** (`DUoM Second Qty`) | La cantidad en la segunda unidad de medida, visible en las líneas de documento. |
| **Ratio DUoM** (`DUoM Ratio`) | El factor de conversión entre la primera y la segunda UdM para esa línea concreta. Fórmula: `Segunda Qty = Primera Qty × Ratio`. |
| **Modo de conversión** | Define cómo se calcula (o no) automáticamente el ratio. Véase la sección siguiente. |
| **DUoM Unit Cost** | Coste unitario en la **segunda UdM** (sólo en compras). Se sincroniza bidireccionalmente con el campo estándar **Coste directo unit.** usando el ratio. |
| **DUoM Unit Price** | Precio de venta unitario en la **segunda UdM** (sólo en ventas). Se sincroniza bidireccionalmente con el campo estándar **Precio unit.** usando el ratio. |
| **Precisión de redondeo** (`Qty. Rounding Precision`) | Paso mínimo permitido para la segunda cantidad. Configurado en BC en la tabla **Unidades de medida por artículo** (`Item Unit of Measure`). Véase la sección [2.3 — Precisión de redondeo de la segunda UdM](#23-precisión-de-redondeo-de-la-segunda-udm). |

---

## 2. Configuración del artículo

Antes de poder registrar la segunda cantidad en un documento, el artículo debe tener DUoM activado. Esta configuración se realiza una única vez por artículo.

### Cómo acceder a la configuración DUoM de un artículo

1. Abra la ficha del artículo (**Búsqueda** → escriba *Artículos* → seleccione el artículo).
2. En el menú de acciones superior, haga clic en **Navegar** → **DUoM Setup**.

> `[PENDIENTE CAPTURA]` *Ficha de artículo con el botón "DUoM Setup" destacado en la cinta de acciones.*

Se abrirá la página **DUoM Item Setup**, que contiene los siguientes campos.

### Campos de configuración DUoM

| Campo | Obligatorio | Descripción |
|-------|-------------|-------------|
| **Nº de artículo** | — | Identificador del artículo. Se rellena automáticamente. |
| **Dual UoM Enabled** | Sí | Active este interruptor para habilitar la doble UdM en este artículo. |
| **Second UoM Code** | Sí | Código de la segunda unidad de medida (ej. `PCS`, `BOX`, `KG`). No puede coincidir con la UdM base. |
| **Conversion Mode** | Sí | Modo de cálculo del ratio (Fijo / Variable / Siempre Variable). Véase tabla siguiente. |
| **Fixed Ratio** | Según modo | Ratio de conversión por defecto. Obligatorio en modo Fijo; opcional en modo Variable; no aplica en Siempre Variable. |

#### Acciones disponibles en la página DUoM Item Setup

| Acción | Descripción |
|--------|-------------|
| **Validate Setup** | Comprueba que la configuración DUoM del artículo es coherente y completa (p. ej. que Second UoM Code está informado si DUoM está activado). Muestra un mensaje de confirmación si todo es correcto. |
| **DUoM Lot Ratios** | Abre la lista de ratios reales registrados por lote para este artículo. Permite consultar y mantener la tabla **DUoM Lot Ratio**. Véase [sección 9 — Ratios específicos por lote](#9-ratios-específicos-por-lote). |

### Modos de conversión

| Modo | Descripción | Cuándo usarlo | Ejemplo |
|------|-------------|---------------|---------|
| **Fixed** (Fijo) | El ratio es constante en todas las transacciones. El sistema calcula la Segunda Qty automáticamente y **no permite modificarla** en la línea. | Artículos con un factor de conversión estable e inalterable. | 1 caja siempre contiene exactamente 12 piezas → `Ratio = 12`. Pedido de 5 cajas → Segunda Qty = 60 PCS automáticamente. |
| **Variable** | El sistema propone un ratio por defecto (el valor de **Fixed Ratio**), pero el usuario puede modificarlo en cada línea de documento. La Segunda Qty se recalcula al cambiar el ratio. | Artículos con conversión aproximada que puede variar entre pedidos o lotes. | El ratio estándar KG/PCS de la lechuga es 1,25, pero este albarán concreto mide 1,31 KG/PCS. El usuario corrige el ratio en la línea. |
| **AlwaysVariable** (Siempre Variable) | No hay ratio por defecto. El usuario introduce la Segunda Qty **manualmente** en cada línea. El campo Fixed Ratio no aplica. | Artículos cuya conversión nunca puede predecirse (fruta fresca, piezas únicas, etc.). | Cada envío de fruta pesa diferente. El operario introduce directamente la cantidad en PCS al registrar la recepción. |

### Pasos para configurar un artículo con DUoM

**Ejemplo:** Artículo *Lechuga Iceberg*, UdM base KG, segunda UdM PCS, modo Variable con ratio por defecto 1,25.

1. Abra la ficha del artículo *Lechuga Iceberg*.
2. Haga clic en **Navegar → DUoM Setup**.
3. Active el campo **Dual UoM Enabled** (póngalo en `Sí`).
4. En **Second UoM Code**, introduzca `PCS`.
5. En **Conversion Mode**, seleccione `Variable`.
6. En **Fixed Ratio**, introduzca `1,25`.
7. Cierre la página. La configuración se guarda automáticamente.

> `[PENDIENTE CAPTURA]` *Página DUoM Item Setup con los campos rellenos para el ejemplo anterior.*

> **Nota:** Si desactiva **Dual UoM Enabled** en un artículo, los campos Second UoM Code, Conversion Mode y Fixed Ratio se borran automáticamente. Las transacciones ya contabilizadas no se ven afectadas.

---

### 2.3 Precisión de redondeo de la segunda UdM

Cuando la segunda unidad de medida es **discreta** (por ejemplo PCS, CAJA, PALET), cantidades
fraccionarias como 11,5 piezas carecen de sentido físico. Business Central permite controlar esto
mediante el campo **Qty. Rounding Precision** en la tabla estándar de BC **Unidades de medida por
artículo** (`Item Unit of Measure`).

La extensión DUoM **lee automáticamente** ese campo y redondea la **DUoM Second Qty** al paso
mínimo configurado, tanto al calcular automáticamente como cuando el usuario introduce el valor
manualmente.

#### ¿Cómo configurar la precisión de redondeo?

La precisión **no** se configura en la página DUoM Setup — se configura directamente en BC,
en la ficha del artículo → pestaña **Unidades de medida**.

1. Abra la ficha del artículo.
2. Vaya a la pestaña **Unidades de medida** (o **Navegar → Unidades de medida**).
3. Localice la fila correspondiente a la **segunda UdM** (ej. `PCS`).
4. Edite el campo **Precisión de redondeo de cant.** (`Qty. Rounding Precision`) con el valor
   deseado:

| Valor | Efecto |
|-------|--------|
| `1` | La segunda cantidad siempre será un número entero (ej. 12, nunca 11,5). Adecuado para unidades discretas: piezas, cajas, palets. |
| `0,001` | La segunda cantidad se redondea a 3 decimales. Adecuado para unidades continuas de alta precisión: KG, litros. |
| `0,01` | La segunda cantidad se redondea a 2 decimales. |
| `0` *(vacío)* | Sin redondeo. La segunda cantidad puede tener hasta 5 decimales. |

> `[PENDIENTE CAPTURA]` *Pestaña "Unidades de medida" de la ficha del artículo, con el campo "Qty. Rounding Precision" visible para la UdM PCS con valor 1.*

#### Ejemplo práctico

**Artículo:** Lechuga Iceberg · **Segunda UdM:** PCS · **Qty. Rounding Precision = 1** · **Ratio = 1,15**

| Cantidad principal | Resultado bruto | Segunda Qty almacenada |
|--------------------|-----------------|------------------------|
| 10 KG | 10 × 1,15 = 11,5 PCS | **12 PCS** *(redondeado a 1)* |
| 7 KG | 7 × 1,15 = 8,05 PCS | **8 PCS** *(redondeado a 1)* |
| 20 KG | 20 × 1,15 = 23,0 PCS | **23 PCS** *(sin cambio, ya es entero)* |

> **Nota:** Si **Qty. Rounding Precision = 0** (campo vacío o sin configurar), el sistema no
> aplica redondeo y almacena el resultado exacto del cálculo (hasta 5 decimales). Este es el
> comportamiento por defecto cuando no se configura la precisión.

#### Redondeo en la entrada manual (modo Siempre Variable)

En el modo **AlwaysVariable**, el usuario introduce la **DUoM Second Qty** manualmente. Si la
segunda UdM tiene **Qty. Rounding Precision** configurada, el sistema también aplica el redondeo
al salir del campo:

- El usuario escribe `11,5` → el campo queda como `12` (con precisión = 1).
- El usuario escribe `8,07` → el campo queda como `8` (con precisión = 1).

Esto evita que el usuario guarde cantidades físicamente imposibles en unidades discretas.

---

## 2.4 Configuración DUoM por variante (override opcional)

Business Central permite que un artículo tenga varias **variantes** (por ejemplo, una lechuga puede tener las variantes ROMANA e ICEBERG). En DualUoM-BC es posible que cada variante tenga un ratio o una segunda unidad de medida distinta a la del artículo base.

### Jerarquía de configuración: Artículo → Variante → Lote

Cuando se registra una transacción con variante, el sistema aplica la siguiente jerarquía para determinar qué configuración DUoM usar:

```
1. Configuración base del artículo   → siempre obligatoria (activa/desactiva DUoM)
2. Override de variante (opcional)   → si existe, sus valores prevalecen sobre el artículo
3. Ratio real de lote (Fase 2)       → cuando aplica, prevalece sobre los anteriores
```

> **Regla clave:** La variante **no puede activar por sí sola** la DUoM si el artículo no la tiene activada. El interruptor **Dual UoM Enabled** siempre vive en la configuración del artículo.

### ¿Cuándo usar overrides de variante?

Use la configuración DUoM por variante cuando diferentes variantes del mismo artículo requieran:

- Una **segunda unidad de medida** diferente (por ejemplo, la variante ROMANA se cuenta en PCS pero la variante TROCEADA en BOLSAS).
- Un **ratio por defecto** diferente (ROMANA tiene en media 1,25 KG/PCS, ICEBERG tiene 1,05 KG/PCS).
- Un **modo de conversión** diferente (la variante estándar es Fijo, pero la variante premium es Variable por variabilidad de peso).

Si todas las variantes de un artículo comparten la misma segunda UdM y el mismo ratio, **no es necesario** crear ningún override de variante.

### Cómo acceder a los overrides DUoM de variantes

1. Abra la ficha del artículo (**Búsqueda** → *Artículos* → seleccione el artículo).
2. En el menú de acciones, haga clic en **Navegar → DUoM Variant Overrides**.

> `[PENDIENTE CAPTURA]` *Ficha de artículo con el botón "DUoM Variant Overrides" destacado en la cinta de acciones.*

Se abrirá la página **DUoM Variant Setup List**, filtrada automáticamente al artículo actual.

### Campos de la configuración DUoM por variante

| Campo | Obligatorio | Descripción |
|-------|-------------|-------------|
| **Item No.** | — | Nº de artículo. Se rellena automáticamente y no es editable. |
| **Variant Code** | Sí | Código de la variante del artículo a la que aplica este override. |
| **Second UoM Code** | No | Override de la segunda unidad de medida para esta variante. Si se deja en blanco, se hereda del artículo. |
| **Conversion Mode** | No | Override del modo de conversión para esta variante. Si no se cambia, se usa el del artículo. |
| **Fixed Ratio** | No | Override del ratio por defecto para esta variante. Si se deja a cero, se usa el del artículo. |

> **Nota:** Sólo es necesario crear un registro de override cuando la variante difiere del artículo en al menos uno de los campos anteriores. La ausencia de registro significa "hereda todo del artículo".

### Ejemplo completo: Artículo LECHUGA con dos variantes

**Configuración del artículo (nivel base):**

| Campo | Valor |
|-------|-------|
| Nº artículo | LECHUGA-001 |
| Dual UoM Enabled | Sí |
| Second UoM Code | PCS |
| Conversion Mode | Variable |
| Fixed Ratio | 1,25 |

Esto significa: por defecto, 1 KG de lechuga equivale a 1,25 piezas.

**Configuración de variantes (overrides):**

| Variante | Second UoM Code | Conversion Mode | Fixed Ratio | Efecto |
|----------|-----------------|-----------------|-------------|--------|
| ROMANA | *(sin override)* | *(sin override)* | *(sin override)* | Hereda todo del artículo: 1,25 KG/PCS, modo Variable |
| ICEBERG | *(sin override)* | *(sin override)* | 1,05 | Override sólo del ratio: 1,05 KG/PCS, mismo modo Variable |
| TROCEADA | BOLSAS | Fixed | 0,5 | Override de UdM y modo: 0,5 KG/BOLSA, modo Fijo |

**Resultado en los documentos:**

Cuando el usuario selecciona el artículo LECHUGA-001 y el **Código de variante**:

- ROMANA → Sistema usa ratio **1,25** (hereda del artículo). Pedido 10 KG → **12,5 PCS** propuesto.
- ICEBERG → Sistema usa ratio **1,05** (override de variante). Pedido 10 KG → **10,5 PCS** propuesto.
- TROCEADA → Sistema usa ratio **0,5** en modo Fijo. Pedido 10 KG → **5 BOLSAS** calculadas automáticamente (no editable).

> `[PENDIENTE CAPTURA]` *Página "DUoM Variant Setup List" con las tres variantes del ejemplo mostradas.*

### Pasos para crear un override de variante

1. Abra la ficha del artículo con DUoM ya configurado a nivel base.
2. Haga clic en **Navegar → DUoM Variant Overrides**.
3. Haga clic en **Nuevo** (o edite directamente en la línea en blanco al final de la lista).
4. En **Variant Code**, seleccione la variante a configurar.
5. Rellene sólo los campos que quieran difieren del artículo: **Second UoM Code**, **Conversion Mode** y/o **Fixed Ratio**.
6. Cierre la página. Los cambios se guardan automáticamente.

> **Precaución:** Si elimina una variante del artículo desde la ficha del artículo, su configuración DUoM de variante también se elimina automáticamente. Esta acción es irreversible.

### Comportamiento al cambiar el Código de variante en un documento

Cuando el usuario **cambia el código de variante en una línea de pedido** (compra o venta) que ya tiene una cantidad y una segunda cantidad introducidas:

1. Los campos **DUoM Ratio** y **DUoM Second Qty** se **resetean a cero**.
2. El sistema aplica la configuración DUoM efectiva de la nueva variante.
3. Si el modo de la nueva variante es Fijo o Variable, la **DUoM Second Qty** se **recalcula automáticamente** usando el ratio de la nueva variante y la cantidad principal ya introducida.
4. Si el modo es Siempre Variable, los campos quedan vacíos para que el usuario los introduzca.

**Ejemplo:**

| Acción del usuario | Resultado |
|--------------------|-----------|
| Selecciona artículo LECHUGA-001, variante ROMANA, cantidad 10 KG | DUoM Second Qty = **12,5 PCS** (ratio 1,25 heredado del artículo) |
| Cambia variante a ICEBERG (ratio 1,05) | DUoM Second Qty se resetea y recalcula: = **10,5 PCS** |
| Cambia variante a TROCEADA (Fijo, 0,5, BOLSAS) | DUoM Second Qty = **5 BOLSAS** (calculado automáticamente, no editable) |

---

## 2.5 DUoM Unit Cost (compras) y DUoM Unit Price (ventas)

Además de la segunda cantidad, DualUoM-BC añade un campo de **precio/coste en la segunda unidad de medida** en las líneas de compra y venta. Este campo permite introducir o consultar el importe unitario expresado en la segunda UdM y se sincroniza automáticamente con el precio/coste principal del artículo.

### DUoM Unit Cost — Líneas de compra

| Campo | Descripción |
|-------|-------------|
| **DUoM Unit Cost** | Coste unitario en la segunda UdM (ej. €/PCS cuando la UdM base es KG). |

**Comportamiento bidireccional:**

- Si el usuario introduce el **DUoM Unit Cost** (ej. 2,50 €/PCS con ratio 1,25):
  `Coste directo unit. = DUoM Unit Cost / DUoM Ratio = 2,50 / 1,25 = 2,00 €/KG`
  El campo **Coste directo unit.** se actualiza automáticamente.

- Si el usuario modifica el **Coste directo unit.** estándar de BC (ej. 2,00 €/KG):
  `DUoM Unit Cost = Coste directo unit. × DUoM Ratio = 2,00 × 1,25 = 2,50 €/PCS`
  El campo **DUoM Unit Cost** se recalcula automáticamente.

> **Nota:** Si el DUoM Ratio es 0 (modo Siempre Variable sin ratio introducido), la derivación automática no se aplica — el sistema no puede calcular el precio de la segunda UdM sin conocer el ratio.

### DUoM Unit Price — Líneas de venta

| Campo | Descripción |
|-------|-------------|
| **DUoM Unit Price** | Precio de venta unitario en la segunda UdM (ej. €/PCS cuando la UdM base es KG). |

**Comportamiento bidireccional:**

- Si el usuario introduce el **DUoM Unit Price** (ej. 3,75 €/PCS con ratio 1,25):
  `Precio unit. = DUoM Unit Price / DUoM Ratio = 3,75 / 1,25 = 3,00 €/KG`
  El campo **Precio unit.** estándar de BC se actualiza automáticamente.

- Si el usuario modifica el **Precio unit.** estándar (ej. 3,00 €/KG):
  `DUoM Unit Price = Precio unit. × DUoM Ratio = 3,00 × 1,25 = 3,75 €/PCS`
  El campo **DUoM Unit Price** se recalcula automáticamente.

> **Nota:** Igual que en compras, si DUoM Ratio = 0 no se aplica la derivación automática.

### Visibilidad del campo de precio/coste

| Documento | Campo DUoM de precio/coste | Editable |
|-----------|-----------------------------|----------|
| Líneas de pedido de compra | **DUoM Unit Cost** | ✅ Sí |
| Líneas de pedido de venta | **DUoM Unit Price** | ✅ Sí |
| Albarán de compra registrado | **DUoM Unit Cost** | ❌ No (inmutable) |
| Factura de compra registrada | **DUoM Unit Cost** | ❌ No (inmutable) |
| Abono de compra registrado | **DUoM Unit Cost** | ❌ No (inmutable) |
| Albarán de venta registrado | **DUoM Unit Price** | ❌ No (inmutable) |
| Factura de venta registrada | **DUoM Unit Price** | ❌ No (inmutable) |
| Abono de venta registrado | **DUoM Unit Price** | ❌ No (inmutable) |

---

## 3. Compras

La extensión añade dos campos en las **líneas de pedido de compra**: **DUoM Second Qty** y **DUoM Ratio**. Estos campos aparecen automáticamente cuando el artículo tiene DUoM activado.

### 3.1 Introducir un pedido de compra con segunda cantidad

#### Acceso

**Búsqueda** → *Pedidos de compra* → **Nuevo** (o abra un pedido existente).

#### Campos nuevos en las líneas

| Campo | Ubicación | Comportamiento |
|-------|-----------|----------------|
| **DUoM Second Qty** | Líneas del pedido, junto a **Cantidad** | Calculado automáticamente (modos Fijo y Variable) o editable por el usuario (modo Siempre Variable). El encabezado de la columna muestra el código de la segunda UdM (p. ej. **PCS**) cuando está disponible. |
| **DUoM Ratio** | Líneas del pedido | Siempre editable; permite ajustar el ratio línea a línea en modo Variable |
| **DUoM Unit Cost** | Líneas del pedido | Editable; se sincroniza bidireccionalmente con **Coste directo unit.** usando el ratio. Véase [sección 2.5](#25-duom-unit-cost-compras-y-duom-unit-price-ventas). |

> `[PENDIENTE CAPTURA]` *Líneas de pedido de compra con las columnas DUoM Second Qty y DUoM Ratio visibles.*

#### Comportamiento según el modo de conversión

**Modo Fijo:**
1. Introduzca el artículo y la cantidad (ej. 100 KG).
2. El sistema rellena automáticamente **DUoM Second Qty** aplicando la fórmula `Segunda Qty = Primera Qty × Ratio`. Por ejemplo, con Ratio = 0,8: `100 KG × 0,8 = 80 PCS`.
3. El campo **DUoM Second Qty** aparece en gris (no editable).
4. Si modifica la cantidad principal, la segunda se recalcula al instante.
5. Si la segunda UdM tiene **Qty. Rounding Precision** configurada, el resultado se redondea automáticamente (ej. 11,5 PCS → 12 PCS con precisión = 1). Véase [sección 2.3](#23-precisión-de-redondeo-de-la-segunda-udm).

**Modo Variable:**
1. Introduzca el artículo y la cantidad (ej. 100 KG).
2. El sistema propone la **DUoM Second Qty** usando el ratio por defecto del artículo (ej. 125 PCS si el ratio es 1,25).
3. El campo **DUoM Second Qty** aparece en gris (no editable directamente), pero puede modificar el **DUoM Ratio** en la línea.
4. Al cambiar el **DUoM Ratio** (ej. a 1,31), la **DUoM Second Qty** se recalcula (ej. 131 PCS) y se redondea si la segunda UdM tiene precisión configurada.

**Modo Siempre Variable:**
1. Introduzca el artículo y la cantidad (ej. 50 KG).
2. Los campos **DUoM Second Qty** y **DUoM Ratio** aparecen vacíos.
3. Introduzca directamente la **DUoM Second Qty** (ej. 42 PCS). El campo es editable.
4. Si la segunda UdM tiene **Qty. Rounding Precision = 1**, el sistema redondeará al entero más próximo al confirmar el campo (ej. si escribe 41,7 → queda 42).
5. (Opcional) El **DUoM Ratio** se puede dejar en blanco o introducir manualmente para registro histórico.

> **Consejo:** Si tiene varias líneas con el mismo artículo en modo Variable, puede ajustar el **DUoM Ratio** en cada línea de forma independiente. El ratio no afecta al precio de compra — sólo a la cantidad secundaria.

### 3.1.1 Pedido de compra con variante

Cuando el artículo tiene **variantes** configuradas con overrides DUoM (véase [sección 2.4](#24-configuración-duom-por-variante-override-opcional)):

**Pasos:**

1. Introduzca el artículo en la línea de pedido (ej. LECHUGA-001).
2. Seleccione el **Código de variante** (ej. ICEBERG). El sistema aplica automáticamente la configuración DUoM de esa variante.
3. Introduzca la **Cantidad** principal (ej. 20 KG).
4. La **DUoM Second Qty** y el **DUoM Ratio** se calculan con el ratio de la variante ICEBERG (ej. 1,05 → `20 × 1,05 = 21 PCS`).
5. Si cambia el **Código de variante** a otra (ej. ROMANA), los campos DUoM se resetean y se recalculan con el ratio de ROMANA (ej. 1,25 → `20 × 1,25 = 25 PCS`).

**Ejemplo con el artículo LECHUGA-001:**

| Código de variante | Ratio efectivo | Cantidad | DUoM Second Qty |
|--------------------|----------------|----------|-----------------|
| ROMANA (hereda artículo) | 1,25 | 20 KG | **25 PCS** |
| ICEBERG (override 1,05) | 1,05 | 20 KG | **21 PCS** |
| TROCEADA (Fijo 0,5 BOLSAS) | 0,5 | 20 KG | **10 BOLSAS** |

> `[PENDIENTE CAPTURA]` *Pedido de compra con artículo LECHUGA-001, variante ICEBERG, y campos DUoM calculados automáticamente con el ratio de la variante.*

### 3.2 Confirmar el albarán de compra con la segunda cantidad

Cuando el pedido de compra está listo para recibirse:

1. En el pedido de compra, haga clic en **Contabilizar** → **Recibir** (o **Recibir y facturar**).
2. Antes de contabilizar, verifique que cada línea con DUoM tiene una **DUoM Second Qty** correcta (especialmente en modo Siempre Variable).
3. Confirme la contabilización.

> `[PENDIENTE CAPTURA]` *Ventana de confirmación de contabilización del albarán de compra con líneas DUoM correctamente rellenadas.*

> **Importante:** Antes de contabilizar, verifique que cada línea con DUoM tiene una **DUoM Second Qty** correcta (especialmente en modo Siempre Variable). Si la segunda cantidad queda a cero, el sistema la registrará tal cual en el movimiento de producto — no hay bloqueo ni aviso automático en la versión actual.

### 3.3 Ver los campos DUoM en documentos registrados y movimientos de producto

Después de contabilizar el albarán, los campos DUoM son visibles en **dos lugares**:

#### 3.3.1 Documentos de compra registrados

Los campos **DUoM Second Qty**, **DUoM Ratio** y **DUoM Unit Cost** aparecen directamente en las líneas de los siguientes documentos registrados, sin necesidad de navegar a los movimientos de producto:

| Documento registrado | Cómo acceder |
|----------------------|--------------|
| **Albarán de compra registrado** | Compras → Historial → Recepciones registradas |
| **Factura de compra registrada** | Compras → Historial → Facturas registradas |
| **Abono de compra registrado** | Compras → Historial → Abonos registrados |

Todos los campos en documentos registrados son **de solo lectura** — los documentos contabilizados son inmutables.

#### 3.3.2 Movimientos de producto

Para ver el historial de doble UdM a nivel de movimiento contable:

1. Abra el artículo o el pedido de compra.
2. Navegue a **Movimientos de producto** (desde la ficha del artículo: **Movimientos → Movimientos de producto**; o desde el pedido: **Navegar → Movimientos contabilizados**).
3. En la lista de movimientos verá los campos **DUoM Second Qty** y **DUoM Ratio** que se registraron en el momento de la contabilización.

> `[PENDIENTE CAPTURA]` *Lista de movimientos de producto con las columnas DUoM Second Qty y DUoM Ratio.*

Los valores de **DUoM Second Qty** y **DUoM Ratio** en los movimientos de producto son **inmutables** una vez contabilizados. Proporcionan el historial exacto de la segunda cantidad usada en cada transacción.

---

## 4. Ventas

La extensión añade los mismos campos en las **líneas de pedido de venta**. El comportamiento es equivalente al de compras, con la única diferencia de que el campo de precio se denomina **DUoM Unit Price** (en lugar de DUoM Unit Cost).

### 4.1 Introducir un pedido de venta con segunda cantidad

#### Acceso

**Búsqueda** → *Pedidos de venta* → **Nuevo** (o abra un pedido existente).

#### Pasos

1. Cree o abra un pedido de venta e introduzca los datos del cliente.
2. En las líneas, añada el artículo con DUoM activado.
3. Introduzca la cantidad principal en el campo **Cantidad** (ej. 20 PCS).
4. Según el modo de conversión del artículo:
   - **Fijo:** La **DUoM Second Qty** se calcula automáticamente (ej. 25 KG si ratio = 1,25). No editable. Si la segunda UdM tiene **Qty. Rounding Precision** configurada, el resultado se redondea al salir del campo Cantidad.
   - **Variable:** Se propone la **DUoM Second Qty** según el ratio por defecto. Puede modificar el **DUoM Ratio** para ajustar. El resultado se redondea si hay precisión configurada.
   - **Siempre Variable:** Introduzca manualmente la **DUoM Second Qty**. Si hay precisión configurada, el valor se redondeará al salir del campo (ej. 11,5 → 12 con precisión = 1).

#### Campos nuevos en las líneas de venta

| Campo | Ubicación | Comportamiento |
|-------|-----------|----------------|
| **DUoM Second Qty** | Líneas del pedido, junto a **Cantidad** | Calculado automáticamente (modos Fijo y Variable) o editable (modo Siempre Variable). El encabezado de la columna muestra el código de la segunda UdM cuando está disponible. |
| **DUoM Ratio** | Líneas del pedido | Siempre editable; permite ajustar el ratio línea a línea en modo Variable |
| **DUoM Unit Price** | Líneas del pedido | Editable; se sincroniza bidireccionalmente con **Precio unit.** usando el ratio. Véase [sección 2.5](#25-duom-unit-cost-compras-y-duom-unit-price-ventas). |

> `[PENDIENTE CAPTURA]` *Líneas de pedido de venta con DUoM Second Qty y DUoM Ratio visibles.*

> **Nota de negocio:** En ventas, la segunda cantidad es informativa para la logística (ej. peso real para el transportista) pero no altera el precio ni la factura, que se basan en la cantidad principal.

### 4.1.1 Pedido de venta con variante

El comportamiento con variantes es idéntico al descrito para compras en la [sección 3.1.1](#311-pedido-de-compra-con-variante). Al seleccionar o cambiar el **Código de variante** en una línea de pedido de venta:

1. El sistema aplica la configuración DUoM de la variante seleccionada.
2. Los campos DUoM se calculan o resetean automáticamente según corresponda.

**Ejemplo:** Pedido de venta de LECHUGA-001 a un cliente mayorista.

| Código de variante | Cantidad vendida | DUoM Second Qty | Nota |
|--------------------|-----------------|-----------------|------|
| ROMANA (ratio 1,25) | 50 KG | **62,5 PCS** | Hereda ratio del artículo |
| ICEBERG (ratio 1,05) | 50 KG | **52,5 PCS** | Override de variante |
| *(sin variante)* | 50 KG | **62,5 PCS** | Sin variante → usa artículo directamente |

### 4.2 Confirmar el albarán de venta

1. Una vez preparado el pedido, haga clic en **Contabilizar** → **Enviar** (o **Enviar y facturar**).
2. Verifique que las líneas con DUoM tienen la **DUoM Second Qty** correcta.
3. Confirme la contabilización.

> `[PENDIENTE CAPTURA]` *Pedido de venta listo para contabilizar con líneas DUoM correctamente completadas.*

### 4.3 Ver los campos DUoM en documentos registrados y movimientos de producto

Tras contabilizar el albarán de venta, los campos DUoM son visibles en **dos lugares**:

#### 4.3.1 Documentos de venta registrados

Los campos **DUoM Second Qty**, **DUoM Ratio** y **DUoM Unit Price** aparecen directamente en las líneas de los siguientes documentos registrados:

| Documento registrado | Cómo acceder |
|----------------------|--------------|
| **Albarán de venta registrado** | Ventas → Historial → Envíos registrados |
| **Factura de venta registrada** | Ventas → Historial → Facturas registradas |
| **Abono de venta registrado** | Ventas → Historial → Abonos registrados |

Todos los campos en documentos registrados son **de solo lectura**.

#### 4.3.2 Movimientos de producto

Desde la ficha del artículo, navegue a **Movimientos → Movimientos de producto**.
Localice los movimientos de tipo *Venta* generados por el albarán.
Compruebe los campos **DUoM Second Qty** (negativo, ya que representa una salida) y **DUoM Ratio**.

> `[PENDIENTE CAPTURA]` *Movimientos de producto de tipo Venta con columnas DUoM.*

---

## 5. Inventario — Diario de productos

El **Diario de productos** permite registrar ajustes de inventario (entradas, salidas, transferencias). DualUoM-BC extiende también estas líneas con los campos **DUoM Second Qty** y **DUoM Ratio**.

### 5.1 Registrar un ajuste de inventario con segunda cantidad

#### Acceso

**Búsqueda** → *Diarios de productos* → abra una sección del diario.

#### Pasos

1. Cree una nueva línea en el diario de productos.
2. Seleccione el **Tipo mov.**: *Entrada* (para añadir stock) o *Salida* (para reducirlo).
3. Seleccione el **Nº de artículo** con DUoM activado.
4. Introduzca la **Cantidad** principal (ej. 50 KG).
5. Según el modo de conversión:
   - **Fijo / Variable:** La **DUoM Second Qty** se calcula automáticamente. Puede ajustar el **DUoM Ratio** si el modo es Variable.
   - **Siempre Variable:** Introduzca manualmente la **DUoM Second Qty** (ej. 38 PCS).
6. Una vez revisadas todas las líneas, haga clic en **Registrar**.

> `[PENDIENTE CAPTURA]` *Diario de productos con línea de ajuste de inventario y campos DUoM rellenos.*

### 5.2 Verificar el movimiento de producto resultante

1. Tras registrar el diario, vaya a la ficha del artículo.
2. Haga clic en **Movimientos → Movimientos de producto**.
3. Localice el movimiento recién creado. Compruebe que **DUoM Second Qty** y **DUoM Ratio** coinciden con los valores introducidos en el diario.

> `[PENDIENTE CAPTURA]` *Movimiento de producto de tipo Ajuste positivo/negativo con columnas DUoM.*

> **Consejo:** Para los recuentos físicos de inventario, utilice el **Diario de inventario físico** de la misma manera. Los campos DUoM aparecen del mismo modo y con el mismo comportamiento.

---

## 6. Almacén (básico)

### 6.1 Situación actual (Fase 1 — MVP)

En la fase actual, los campos **DUoM Second Qty** y **DUoM Ratio** son visibles en las líneas de pedido de compra y venta, que son los documentos de origen para los flujos de almacén básico (sin almacén dirigido).

**Qué está disponible en Fase 1:**

| Flujo | DUoM disponible |
|-------|-----------------|
| Pedido de compra → Recepción directa (sin almacén) | ✅ Sí |
| Pedido de venta → Envío directo (sin almacén) | ✅ Sí |
| Diario de productos (ajuste manual) | ✅ Sí |
| Movimientos de producto (historial) | ✅ Sí |
| Albarán de almacén (warehouse receipt) | ⏳ Fase 2 |
| Albarán de expedición (warehouse shipment) | ⏳ Fase 2 |
| Picking / put-away dirigido | ⏳ Fase 2 |
| Movimientos de almacén (warehouse entries) | ⏳ Fase 2 |

### 6.2 Cómo opera el almacén básico hoy

Si su empresa utiliza ubicaciones o almacenes con configuración básica (no almacén dirigido), el flujo es:

1. El pedido de compra o venta ya contiene la **DUoM Second Qty** y el **DUoM Ratio** en sus líneas.
2. Al recibir o enviar mercancía y contabilizar el documento, los valores DUoM se propagan automáticamente a los **Movimientos de producto**.
3. Los operarios de almacén pueden visualizar ambas cantidades en las líneas del pedido para orientar su trabajo físico.

> **Nota para responsables de almacén:** La segunda cantidad es informativa en los documentos de almacén actuales. No interfiere con la ubicación ni con la gestión de lotes en Fase 1.

### 6.3 Fase 2 — Almacén dirigido (a documentar cuando se implemente)

En la Fase 2 del proyecto se añadirá soporte completo para:

- **Albaranes de almacén (warehouse receipts):** Campos DUoM Second Qty y DUoM Ratio en las líneas de recepción de almacén.
- **Albaranes de expedición (warehouse shipments):** Ídem para salidas.
- **Picking:** La lista de picking mostrará las dos cantidades para facilitar la doble verificación física.
- **Put-away:** El operario puede confirmar la segunda cantidad al ubicar la mercancía.
- **Movimientos de almacén (warehouse entries):** La segunda cantidad quedará registrada en el historial de almacén.

Este manual se actualizará con los pasos detallados cuando la Fase 2 esté disponible.

---

## 7. Consultas y análisis

### 7.1 Cómo localizar movimientos de producto con segunda cantidad

La forma más directa de consultar el historial de doble UdM es a través de los **Movimientos de producto**.

**Desde la ficha del artículo:**

1. Abra la ficha del artículo.
2. Haga clic en el número que aparece en el campo **Inventario** (o vaya a **Movimientos → Movimientos de producto**).
3. En la lista resultante, desplace la vista hacia la derecha o personalice las columnas para mostrar **DUoM Second Qty** y **DUoM Ratio**.

> `[PENDIENTE CAPTURA]` *Movimientos de producto con columnas DUoM Second Qty y DUoM Ratio visibles tras personalizar la vista.*

**Desde el módulo de Compras o Ventas:**

1. Abra el albarán de compra o venta contabilizado (en el historial de documentos).
2. Haga clic en **Navegar → Movimientos contabilizados**.
3. Seleccione **Movimientos de producto**. Verá las entradas con sus valores DUoM.

### 7.2 Filtros y vistas útiles

| Objetivo | Cómo filtrarlo |
|----------|----------------|
| Ver todos los movimientos con segunda qty distinta de cero | En Movimientos de producto, aplique filtro: **DUoM Second Qty ≠ 0** |
| Analizar un artículo concreto | Filtro por **Nº artículo** |
| Ver movimientos de un período | Filtro por **Fecha mov.** |
| Comparar ratio real vs. ratio estándar | Exporte a Excel y compare el campo **DUoM Ratio** con el **Fixed Ratio** del artículo |

### 7.3 Exportar a Excel

1. En cualquier lista de Business Central (p. ej. Movimientos de producto), haga clic en el icono **Compartir** (o **Abrir en Excel**).
2. Los campos **DUoM Second Qty** y **DUoM Ratio** se incluirán en el archivo Excel si están visibles en la vista actual.
3. Desde Excel puede crear tablas dinámicas para analizar la segunda cantidad por artículo, proveedor, cliente o período.

> `[PENDIENTE CAPTURA]` *Exportación a Excel de movimientos de producto con columnas DUoM.*

---

## 8. Preguntas frecuentes (FAQ)

### ¿Qué ocurre si dejo la DUoM Second Qty a cero?

Depende del contexto:

- **Modo Fijo:** El sistema siempre calcula la segunda cantidad automáticamente. No es posible dejarla a cero si la cantidad principal es mayor que cero.
- **Modo Variable:** Si el **DUoM Ratio** es cero (o no se ha introducido), la **DUoM Second Qty** será cero. El sistema registrará ese cero en el movimiento de producto sin bloquear la contabilización.
- **Modo Siempre Variable:** La segunda cantidad permanece a cero si el usuario no la introduce. El sistema no bloquea la contabilización; el cero se registra en el movimiento de producto tal cual.

En todos los casos, los movimientos de producto registrarán el valor exacto que tenía la línea en el momento de contabilizar, aunque sea cero.

---

### ¿Puedo cambiar el ratio después de contabilizar?

**No.** Una vez contabilizado un movimiento de producto, los campos **DUoM Second Qty** y **DUoM Ratio** son **inmutables** en ese movimiento. Esto garantiza la integridad del historial de trazabilidad.

Si necesita corregir un error:
1. Cree un movimiento corrector (p. ej. una nota de crédito de compra o una línea de ajuste en el Diario de productos con los valores correctos).
2. El nuevo movimiento compensador reflejará la corrección con sus propios valores DUoM.

---

### ¿El modo Variable guarda el ratio que usé en cada línea?

**Sí.** En modo Variable, cada línea de documento almacena el **DUoM Ratio** que se usó (ya sea el ratio por defecto del artículo o uno modificado manualmente por el usuario). Este ratio se propaga al **Movimiento de producto** al contabilizar.

Esto permite:
- Auditar el ratio real utilizado en cada transacción.
- Comparar el ratio real con el ratio estándar del artículo.
- Analizar la variación del ratio a lo largo del tiempo para un artículo.

---

### ¿Puedo activar DUoM en un artículo que ya tiene movimientos contabilizados?

**Sí.** Activar DUoM en un artículo existente no afecta a los movimientos anteriores. A partir del momento en que se activa, las nuevas transacciones incluirán los campos DUoM.

Los movimientos anteriores a la activación tendrán **DUoM Second Qty = 0** y **DUoM Ratio = 0**, que es el valor por defecto para todos los campos extendidos en BC.

---

### ¿Qué ocurre si desactivo DUoM para un artículo?

Si desactiva el campo **Dual UoM Enabled** en un artículo:

1. Los campos **Second UoM Code**, **Conversion Mode** y **Fixed Ratio** se borran automáticamente de la configuración del artículo.
2. Los movimientos de producto ya contabilizados **no se modifican** — conservan sus valores DUoM históricos.
3. Las nuevas transacciones ya no mostrarán los campos DUoM en las líneas de ese artículo.

---

### ¿La segunda cantidad afecta al precio de compra o venta?

**No.** La segunda cantidad y el ratio DUoM son campos puramente informativos / operativos. No intervienen en el cálculo del precio, el coste ni el importe de ningún documento. El precio siempre se basa en la **primera cantidad** (la principal del artículo).

---

### ¿Se puede usar DUoM con seguimiento de lotes?

**Sí, completamente.** DualUoM-BC es compatible con artículos que tienen seguimiento de lotes activado. Además, la extensión soporta **ratios específicos por lote**: es posible registrar el ratio real medido para cada lote (ej. el peso por pieza pesado en recepción) y que el sistema lo proponga automáticamente cuando ese lote se asigna en el Diario de productos.

**Funcionalidad disponible:**

- En el **Diario de productos**, al asignar un número de lote (`Lot No.`) a una línea, el sistema busca en la tabla **DUoM Lot Ratio** si existe un ratio registrado para ese lote. Si existe y el modo de conversión del artículo es Variable o Siempre Variable, los campos **DUoM Ratio** y **DUoM Second Qty** se pre-rellenan automáticamente con el ratio del lote.
- El modo **Fixed** siempre usa el ratio fijo del artículo; el ratio de lote no lo sobrescribe.
- Al contabilizar, cada **Movimiento de producto** recibe el ratio real del lote (proporcional a la cantidad del movimiento cuando hay múltiples lotes en la misma línea).

Para más detalle sobre cómo registrar y gestionar ratios de lote, véase [sección 9 — Ratios específicos por lote](#9-ratios-específicos-por-lote).

---

### ¿Por qué la DUoM Second Qty se redondea automáticamente?

El sistema aplica la **Qty. Rounding Precision** configurada en la tabla estándar
**Unidades de medida por artículo** de BC para la segunda UdM del artículo.

Por ejemplo, si la segunda UdM es `PCS` con `Qty. Rounding Precision = 1`, el sistema
redondea cualquier resultado fraccionario al entero más próximo (11,5 PCS → 12 PCS).

**¿Cómo puedo cambiar o desactivar el redondeo?**

1. Abra la ficha del artículo.
2. Vaya a la pestaña **Unidades de medida**.
3. Localice la fila de la segunda UdM (ej. `PCS`).
4. Modifique el campo **Qty. Rounding Precision**:
   - Para redondeo a entero: `1`
   - Para 2 decimales: `0,01`
   - Para sin redondeo: deje el campo en `0` o vacío.

> **Nota:** Este campo es estándar de BC y puede afectar a otras partes del sistema
> (p. ej. al introducir cantidades en unidades de medida alternativas). Consúltelo con
> su administrador de sistema antes de modificarlo.

---

### ¿Por qué no veo los campos DUoM en las líneas de mi pedido?

Compruebe lo siguiente:

1. **El artículo tiene DUoM activado.** Abra la ficha del artículo → **DUoM Setup** y verifique que **Dual UoM Enabled** está en `Sí`.
2. **El tipo de la línea es Artículo.** Los campos DUoM sólo aparecen en líneas de tipo *Artículo*. Las líneas de tipo *Cuenta C/G*, *Recurso* u otros tipos no muestran estos campos.
3. **Las columnas están ocultas.** Puede que las columnas existan pero estén ocultas. Haga clic en **Ajustar columnas** (icono de columnas en la cabecera de la tabla) y active **DUoM Second Qty** y **DUoM Ratio**.

> `[PENDIENTE CAPTURA]` *Diálogo "Ajustar columnas" con DUoM Second Qty y DUoM Ratio seleccionados.*

---

### ¿Puedo tener diferentes ratios para distintas variantes del mismo artículo?

**Sí.** Utilice la configuración DUoM por variante (véase [sección 2.4](#24-configuración-duom-por-variante-override-opcional)). Desde la ficha del artículo, haga clic en **Navegar → DUoM Variant Overrides** y cree un registro por cada variante que tenga un ratio o segunda UdM diferente al artículo base.

Las variantes sin registro de override **heredan automáticamente** la configuración del artículo.

---

### ¿Qué ocurre si cambio la variante en un pedido ya iniciado?

Si cambia el **Código de variante** en una línea de pedido que ya tiene cantidad y segunda cantidad introducidas:

1. Los campos **DUoM Ratio** y **DUoM Second Qty** se **resetean a cero** automáticamente.
2. Si la nueva variante tiene modo Fijo o Variable, la **DUoM Second Qty** se recalcula de inmediato con el ratio de la nueva variante y la cantidad principal ya introducida.
3. Si el modo de la nueva variante es Siempre Variable, los campos quedan vacíos para introducción manual.

Esto garantiza que el ratio aplicado sea siempre coherente con la variante seleccionada.

---

### ¿Una variante puede tener DUoM activado si el artículo no lo tiene?

**No.** El interruptor **Dual UoM Enabled** controla si el artículo usa DUoM y siempre vive en la configuración del artículo. Una variante sólo puede sobrescribir los valores de **Second UoM Code**, **Conversion Mode** y **Fixed Ratio**, nunca puede activar DUoM por sí sola.

---

### ¿Qué pasa si elimino una variante que tiene configuración DUoM?

La configuración DUoM de esa variante se **elimina automáticamente** al borrar la variante. Este comportamiento es intencionado para evitar configuraciones huérfanas. Las transacciones ya contabilizadas con esa variante no se ven afectadas — conservan los valores DUoM que tenían en el momento de la contabilización.

---

## 9. Ratios específicos por lote

### 9.1 ¿Para qué sirven los ratios por lote?

En artículos con seguimiento de lotes donde el ratio varía entre lotes (p. ej. fruta fresca, queso o cualquier producto pesado individualmente), DualUoM-BC permite registrar el **ratio real medido** para cada número de lote. Cuando ese lote se asigna posteriormente en una transacción, el sistema propone automáticamente el ratio real sin que el usuario tenga que introducirlo manualmente.

**Ejemplo:** El artículo *Queso Manchego* tiene Modo = Variable, ratio por defecto = 2,5 KG/PCS. Al pesar el lote `LOTE-2025-04` en recepción se midió 2,73 KG/PCS. Si se registra ese ratio en la tabla DUoM Lot Ratio, la próxima vez que alguien use el lote `LOTE-2025-04` en el Diario de productos, el sistema propondrá automáticamente ratio = 2,73 y calculará la segunda cantidad correcta.

### 9.2 Cuándo aplica el ratio de lote

| Modo de conversión | ¿Se aplica el ratio de lote? |
|--------------------|------------------------------|
| **Fixed** | ❌ No. El ratio fijo del artículo siempre prevalece. |
| **Variable** | ✅ Sí. El ratio de lote sobrescribe el ratio por defecto si existe. |
| **AlwaysVariable** | ✅ Sí. El ratio de lote pre-rellena los campos en lugar de dejarlos vacíos. |

### 9.3 Cómo registrar un ratio de lote

**Opción 1: desde la ficha DUoM del artículo**

1. Abra la ficha del artículo.
2. Haga clic en **Navegar → DUoM Setup** para abrir la configuración DUoM.
3. En la página **DUoM Item Setup**, haga clic en la acción **DUoM Lot Ratios**.
4. Se abre la página **DUoM Lot Ratio List**, filtrada al artículo actual.
5. Haga clic en **Nuevo** (o edite directamente la línea en blanco al final).
6. Rellene los campos:

| Campo | Descripción |
|-------|-------------|
| **Item No.** | Nº de artículo. Se rellena automáticamente por el filtro. |
| **Lot No.** | Número de lote al que corresponde este ratio (ej. `LOTE-2025-04`). |
| **Actual Ratio** | Ratio real medido (ej. `2,73`). Debe ser mayor que cero. |
| **Description** | Descripción opcional (ej. "Pesado en recepción 15-abr-2025"). |

7. Cierre la página. Los cambios se guardan automáticamente.

> `[PENDIENTE CAPTURA]` *Página DUoM Lot Ratio List con un registro de ejemplo para el artículo Queso Manchego.*

**Opción 2: búsqueda directa**

También puede acceder a la lista global de ratios de lote buscando **DUoM Lot Ratio List** en la búsqueda de BC.

### 9.4 Cómo funciona el ratio de lote en el Diario de productos

1. Cree una nueva línea en el **Diario de productos**.
2. Seleccione el artículo con DUoM activado y con seguimiento de lotes.
3. Introduzca la **Cantidad** principal (ej. 5 KG).
4. En el campo **Lot No.** (Nº de lote), introduzca o seleccione el número de lote.
5. El sistema busca automáticamente si existe un ratio registrado en **DUoM Lot Ratio** para ese artículo y ese lote.
   - Si **sí existe** y el modo es Variable o AlwaysVariable: los campos **DUoM Ratio** y **DUoM Second Qty** se pre-rellenan con el ratio del lote (ej. DUoM Ratio = 2,73; DUoM Second Qty = 5 × 2,73 = 13,65 → redondeado a 14 PCS si precisión = 1).
   - Si **no existe** ratio para ese lote: el sistema usa el comportamiento habitual según el modo (ratio por defecto en Variable, campos vacíos en AlwaysVariable).

> `[PENDIENTE CAPTURA]` *Diario de productos con un artículo de seguimiento de lotes y el campo DUoM Ratio pre-rellenado automáticamente tras introducir el Lot No.*

### 9.5 Propagación del ratio de lote al contabilizar

Cuando se contabiliza el Diario de productos con múltiples lotes en la misma línea (cada uno con cantidad parcial), el sistema crea un **Movimiento de producto** por lote. La extensión DualUoM-BC calcula la **DUoM Second Qty** de cada ILE proporcionalmente a la cantidad del movimiento:

```
DUoM Second Qty del ILE = Abs(Cantidad del ILE) × Ratio efectivo del lote
```

Esto garantiza que la suma de las segundas cantidades de todos los ILEs coincide con la segunda cantidad total de la línea, incluso con múltiples lotes.

### 9.6 Preguntas frecuentes sobre ratios por lote

**¿Puedo modificar el ratio de un lote que ya tiene movimientos contabilizados?**

Sí, puede actualizar el **Actual Ratio** en la tabla DUoM Lot Ratio en cualquier momento. Los movimientos ya contabilizados son inmutables (conservan el ratio que tenían cuando se contabilizaron). El nuevo ratio sólo afecta a las próximas transacciones en que se use ese lote.

**¿El ratio de lote se aplica en los pedidos de compra o venta?**

En la versión actual, el ratio de lote se aplica automáticamente en el **Diario de productos** (cuando el usuario valida el campo Lot No.). En los pedidos de compra y venta, la asignación de lotes se realiza a través de las líneas de seguimiento de artículos, y el sistema aplica el ratio de lote en el momento de la contabilización (al crear los ILEs), no en la línea de pedido.


---

*Este manual se actualizará en cada nueva fase del proyecto. Para la Fase 2 (almacén dirigido, informes avanzados) y la Fase 3 (órdenes de transferencia, devoluciones) se añadirán los capítulos correspondientes.*

*Última actualización: v1.2 — Issues 11b + 13 — Variantes, ratios por lote, DUoM Unit Cost/Price, documentos registrados.*

## Apéndice: Resumen de campos DUoM por documento

| Documento | Campo | Editable | Notas |
|-----------|-------|----------|-------|
| Pedido de compra (líneas) | **DUoM Second Qty** | Sólo en modo Siempre Variable | Auto-calculado en modo Fijo y Variable. Al cambiar Variante, se recalcula automáticamente. Encabezado de columna muestra el código de la segunda UdM. |
| Pedido de compra (líneas) | **DUoM Ratio** | Siempre | Permite ajuste línea a línea; se resetea al cambiar variante. |
| Pedido de compra (líneas) | **DUoM Unit Cost** | Siempre | Coste unitario en 2ª UdM. Se sincroniza bidireccionalmente con Coste directo unit. usando el ratio. |
| Pedido de venta (líneas) | **DUoM Second Qty** | Sólo en modo Siempre Variable | Ídem compras. Al cambiar Variante, se recalcula automáticamente. |
| Pedido de venta (líneas) | **DUoM Ratio** | Siempre | Permite ajuste línea a línea; se resetea al cambiar variante. |
| Pedido de venta (líneas) | **DUoM Unit Price** | Siempre | Precio de venta unitario en 2ª UdM. Se sincroniza bidireccionalmente con Precio unit. usando el ratio. |
| Diario de productos (líneas) | **DUoM Second Qty** | Sólo en modo Siempre Variable | Auto-calculado en modo Fijo y Variable. Respeta variante si se informa. Se pre-rellena desde ratio de lote si existe. |
| Diario de productos (líneas) | **DUoM Ratio** | Siempre | Permite ajuste línea a línea. Se pre-rellena desde ratio de lote si existe. |
| Movimiento de producto | **DUoM Second Qty** | ❌ No editable | Inmutable tras contabilizar. En transacciones de salida (venta, ajuste negativo) es negativo. |
| Movimiento de producto | **DUoM Ratio** | ❌ No editable | Inmutable tras contabilizar |
| Movimiento de valor (Value Entry) | **DUoM Second Qty** | ❌ No editable | Propagado automáticamente desde el Diario de productos al contabilizar. Negativo en salidas. |
| Albarán de compra registrado | **DUoM Second Qty** | ❌ No editable | Propagado desde la línea de compra origen |
| Albarán de compra registrado | **DUoM Ratio** | ❌ No editable | Propagado desde la línea de compra origen |
| Albarán de compra registrado | **DUoM Unit Cost** | ❌ No editable | Propagado desde la línea de compra origen |
| Factura de compra registrada | **DUoM Second Qty** | ❌ No editable | Propagado desde la línea de compra origen |
| Factura de compra registrada | **DUoM Ratio** | ❌ No editable | Propagado desde la línea de compra origen |
| Factura de compra registrada | **DUoM Unit Cost** | ❌ No editable | Propagado desde la línea de compra origen |
| Abono de compra registrado | **DUoM Second Qty** | ❌ No editable | Propagado desde la línea de compra origen |
| Abono de compra registrado | **DUoM Ratio** | ❌ No editable | Propagado desde la línea de compra origen |
| Abono de compra registrado | **DUoM Unit Cost** | ❌ No editable | Propagado desde la línea de compra origen |
| Albarán de venta registrado | **DUoM Second Qty** | ❌ No editable | Propagado desde la línea de venta origen |
| Albarán de venta registrado | **DUoM Ratio** | ❌ No editable | Propagado desde la línea de venta origen |
| Albarán de venta registrado | **DUoM Unit Price** | ❌ No editable | Propagado desde la línea de venta origen |
| Factura de venta registrada | **DUoM Second Qty** | ❌ No editable | Propagado desde la línea de venta origen |
| Factura de venta registrada | **DUoM Ratio** | ❌ No editable | Propagado desde la línea de venta origen |
| Factura de venta registrada | **DUoM Unit Price** | ❌ No editable | Propagado desde la línea de venta origen |
| Abono de venta registrado | **DUoM Second Qty** | ❌ No editable | Propagado desde la línea de venta origen |
| Abono de venta registrado | **DUoM Ratio** | ❌ No editable | Propagado desde la línea de venta origen |
| Abono de venta registrado | **DUoM Unit Price** | ❌ No editable | Propagado desde la línea de venta origen |
| Configuración DUoM artículo | **Dual UoM Enabled** | ✅ Sí | Interruptor principal; no puede ser sobrescrito por variante |
| Configuración DUoM artículo | **Second UoM Code** | ✅ Sí | Código de UdM secundaria base |
| Configuración DUoM artículo | **Conversion Mode** | ✅ Sí | Fijo / Variable / Siempre Variable |
| Configuración DUoM artículo | **Fixed Ratio** | ✅ Sí (modos Fijo y Variable) | No aplica en Siempre Variable |
| Override DUoM variante | **Variant Code** | ✅ Sí | Identifica la variante con override |
| Override DUoM variante | **Second UoM Code** | ✅ Sí | Override de segunda UdM para la variante |
| Override DUoM variante | **Conversion Mode** | ✅ Sí | Override del modo de conversión |
| Override DUoM variante | **Fixed Ratio** | ✅ Sí | Override del ratio por defecto |
| DUoM Lot Ratio | **Item No.** | ✅ Sí | Artículo al que pertenece el ratio de lote |
| DUoM Lot Ratio | **Lot No.** | ✅ Sí | Número de lote con ratio específico |
| DUoM Lot Ratio | **Actual Ratio** | ✅ Sí | Ratio real medido para este lote. Debe ser > 0. |
| DUoM Lot Ratio | **Description** | ✅ Sí | Descripción o comentario opcional del lote |
| Unid. medida por artículo (BC std.) | **Qty. Rounding Precision** | ✅ Sí | Controla el redondeo de `DUoM Second Qty`. Configurar en ficha artículo → pestaña Unidades de medida. |

---

*Este manual se actualizará en cada nueva fase del proyecto. Para la Fase 2 (almacén dirigido, informes avanzados) y la Fase 3 (órdenes de transferencia, devoluciones) se añadirán los capítulos correspondientes.*

*Última actualización: v1.2 — Issues 11b + 13 — Variantes, ratios por lote, DUoM Unit Cost/Price, documentos registrados.*

