# Manual de Usuario — DualUoM-BC

**Extensión de Doble Unidad de Medida para Microsoft Dynamics 365 Business Central**

> **Versión del documento:** 1.0 (MVP — Fase 1)
> **Módulos cubiertos:** Compras · Ventas · Inventario · Almacén (básico)
> **Audiencia:** Usuarios de negocio (sin conocimientos técnicos)

---

## Índice

1. [Introducción](#1-introducción)
2. [Configuración del artículo](#2-configuración-del-artículo)
   - [2.1 Cómo acceder a la configuración DUoM](#cómo-acceder-a-la-configuración-duom-de-un-artículo)
   - [2.2 Campos y modos de conversión](#campos-de-configuración-duom)
   - [2.3 Precisión de redondeo de la segunda UdM](#23-precisión-de-redondeo-de-la-segunda-udm)
3. [Compras](#3-compras)
4. [Ventas](#4-ventas)
5. [Inventario — Diario de productos](#5-inventario--diario-de-productos)
6. [Almacén (básico)](#6-almacén-básico)
7. [Consultas y análisis](#7-consultas-y-análisis)
8. [Preguntas frecuentes (FAQ)](#8-preguntas-frecuentes-faq)

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

La extensión añade dos campos en las **líneas de pedido de compra**: **DUoM Second Qty** y **DUoM Ratio**. Estos campos aparecen automáticamente cuando el artículo tiene DUoM activado.

### 3.1 Introducir un pedido de compra con segunda cantidad

#### Acceso

**Búsqueda** → *Pedidos de compra* → **Nuevo** (o abra un pedido existente).

#### Campos nuevos en las líneas

| Campo | Ubicación | Comportamiento |
|-------|-----------|----------------|
| **DUoM Second Qty** | Líneas del pedido, junto a **Cantidad** | Calculado automáticamente (modos Fijo y Variable) o editable por el usuario (modo Siempre Variable) |
| **DUoM Ratio** | Líneas del pedido | Siempre editable; permite ajustar el ratio línea a línea en modo Variable |

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

### 3.2 Confirmar el albarán de compra con la segunda cantidad

Cuando el pedido de compra está listo para recibirse:

1. En el pedido de compra, haga clic en **Contabilizar** → **Recibir** (o **Recibir y facturar**).
2. Antes de contabilizar, verifique que cada línea con DUoM tiene una **DUoM Second Qty** correcta (especialmente en modo Siempre Variable).
3. Confirme la contabilización.

> `[PENDIENTE CAPTURA]` *Ventana de confirmación de contabilización del albarán de compra con líneas DUoM correctamente rellenadas.*

> **Importante:** Antes de contabilizar, verifique que cada línea con DUoM tiene una **DUoM Second Qty** correcta (especialmente en modo Siempre Variable). Si la segunda cantidad queda a cero, el sistema la registrará tal cual en el movimiento de producto — no hay bloqueo ni aviso automático en la versión actual.

### 3.3 Ver los movimientos de producto resultantes

Después de contabilizar el albarán:

1. Abra el artículo o el pedido de compra.
2. Navegue a **Movimientos de producto** (desde la ficha del artículo: **Movimientos → Movimientos de producto**; o desde el pedido: **Navegar → Movimientos contabilizados**).
3. En la lista de movimientos verá los campos **DUoM Second Qty** y **DUoM Ratio** que se registraron en el momento de la contabilización.

> `[PENDIENTE CAPTURA]` *Lista de movimientos de producto con las columnas DUoM Second Qty y DUoM Ratio.*

Los valores de **DUoM Second Qty** y **DUoM Ratio** en los movimientos de producto son **inmutables** una vez contabilizados. Proporcionan el historial exacto de la segunda cantidad usada en cada transacción.

---

## 4. Ventas

La extensión añade los mismos campos (**DUoM Second Qty** y **DUoM Ratio**) en las **líneas de pedido de venta**. El comportamiento es equivalente al de compras.

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

> `[PENDIENTE CAPTURA]` *Líneas de pedido de venta con DUoM Second Qty y DUoM Ratio visibles.*

> **Nota de negocio:** En ventas, la segunda cantidad es informativa para la logística (ej. peso real para el transportista) pero no altera el precio ni la factura, que se basan en la cantidad principal.

### 4.2 Confirmar el albarán de venta

1. Una vez preparado el pedido, haga clic en **Contabilizar** → **Enviar** (o **Enviar y facturar**).
2. Verifique que las líneas con DUoM tienen la **DUoM Second Qty** correcta.
3. Confirme la contabilización.

> `[PENDIENTE CAPTURA]` *Pedido de venta listo para contabilizar con líneas DUoM correctamente completadas.*

### 4.3 Ver los movimientos de producto resultantes

Tras contabilizar el albarán de venta:

1. Desde la ficha del artículo, navegue a **Movimientos → Movimientos de producto**.
2. Localice los movimientos de tipo *Venta* generados por el albarán.
3. Compruebe los campos **DUoM Second Qty** (negativo, ya que representa una salida) y **DUoM Ratio**.

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

**Sí, con matices.** En la **Fase 1 (MVP)**, DUoM es compatible con artículos que tienen seguimiento de lotes activado. La segunda cantidad y el ratio se registran a nivel de línea de documento, por lo que funcionan con normalidad aunque el artículo use lotes.

La limitación en Fase 1 es que **el ratio no es específico por lote**: todos los lotes del mismo artículo comparten el mismo ratio por defecto (el configurado en **Fixed Ratio**). Si el peso real de un lote concreto difiere del ratio por defecto, el usuario puede ajustar el **DUoM Ratio** en la línea de ese albarán.

El soporte de **ratios específicos por lote** (es decir, registrar y reutilizar el ratio pesado de cada lote de forma automática) estará disponible en la **Fase 2** del proyecto.

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

## Apéndice: Resumen de campos DUoM por documento

| Documento | Campo | Editable | Notas |
|-----------|-------|----------|-------|
| Pedido de compra (líneas) | **DUoM Second Qty** | Sólo en modo Siempre Variable | Auto-calculado en modo Fijo y Variable. Se redondea según `Qty. Rounding Precision` de la segunda UdM. |
| Pedido de compra (líneas) | **DUoM Ratio** | Siempre | Permite ajuste línea a línea |
| Pedido de venta (líneas) | **DUoM Second Qty** | Sólo en modo Siempre Variable | Auto-calculado en modo Fijo y Variable. Se redondea según `Qty. Rounding Precision` de la segunda UdM. |
| Pedido de venta (líneas) | **DUoM Ratio** | Siempre | Permite ajuste línea a línea |
| Diario de productos (líneas) | **DUoM Second Qty** | Sólo en modo Siempre Variable | Auto-calculado en modo Fijo y Variable. Se redondea según `Qty. Rounding Precision` de la segunda UdM. |
| Diario de productos (líneas) | **DUoM Ratio** | Siempre | Permite ajuste línea a línea |
| Movimiento de producto | **DUoM Second Qty** | ❌ No editable | Inmutable tras contabilizar |
| Movimiento de producto | **DUoM Ratio** | ❌ No editable | Inmutable tras contabilizar |
| Configuración DUoM artículo | **Dual UoM Enabled** | ✅ Sí | Interruptor principal |
| Configuración DUoM artículo | **Second UoM Code** | ✅ Sí | Código de UdM secundaria |
| Configuración DUoM artículo | **Conversion Mode** | ✅ Sí | Fijo / Variable / Siempre Variable |
| Configuración DUoM artículo | **Fixed Ratio** | ✅ Sí (modos Fijo y Variable) | No aplica en Siempre Variable |
| Unid. medida por artículo (BC std.) | **Qty. Rounding Precision** | ✅ Sí | Controla el redondeo de `DUoM Second Qty`. Configurar en ficha artículo → pestaña Unidades de medida. |

---

*Este manual se actualizará en cada nueva fase del proyecto. Para la Fase 2 (almacén dirigido, ratios por lote, informes) y la Fase 3 (órdenes de transferencia, devoluciones) se añadirán los capítulos correspondientes.*

*Última actualización: Fase 1 — MVP + Issue 11 (Qty. Rounding Precision).*
