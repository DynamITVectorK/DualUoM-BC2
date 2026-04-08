# Visión — DualUoM-BC

## Objetivo del proyecto

Construir una extensión de **Doble Unidad de Medida (DUoM)** para Business Central SaaS que permita a los artículos
llevar dos cantidades independientes de forma simultánea a lo largo del ciclo de vida completo de documentos, entradas
y almacén — sin modificar la aplicación estándar de BC.

## Necesidad de negocio

Muchas industrias (alimentación, química, agricultura, metales) comercian bienes medidos en dos unidades distintas
al mismo tiempo. Un lote de lechuga puede ser:

- comprado como **10 KG** (peso — facturado y costado)
- recibido como **8 pzs** (piezas — recogidas, contadas y rastreadas)

Ambas cantidades son legal y operativamente relevantes. Ninguna puede derivarse de forma fiable de
la otra usando un ratio fijo, porque la conversión real varía por lote.

BC estándar soporta una única UdM alternativa (el factor `Qty. per Unit of Measure` en la tabla
Item Unit of Measure), pero esto solo cubre un ratio fijo a nivel de artículo. No puede:

- almacenar un ratio variable por transacción o por lote
- llevar una segunda cantidad de forma independiente a través de todas las líneas de documento y asientos contables
- exigir el seguimiento de ratios por lote para la trazabilidad

## Por qué la UdM estándar de BC es insuficiente

| Requisito | BC estándar | Extensión DUoM |
|---|---|---|
| Ratio fijo entre dos UdMs | ✔ Tabla Item UoM | ✔ reutilizado |
| Ratio variable por transacción | ✗ | ✔ campo DUoM en líneas |
| Siempre variable (ratio nunca fijo) | ✗ | ✔ indicador en configuración del artículo |
| Ratio real por lote | ✗ | ✔ campo de ratio a nivel de lote |
| Segunda cantidad en líneas de documento | ✗ | ✔ extensión de tabla |
| Segunda cantidad en asientos de valor/inventario | ✗ | ✔ extensión de tabla |
| Picking/put-away en almacén con dos cantidades | ✗ | ✔ extensión de almacén |

## Módulos objetivo

- **Compras** — pedidos de compra, recepciones, facturas, notas de crédito
- **Ventas** — pedidos de venta, envíos, facturas, notas de crédito, pedidos de devolución
- **Inventario** — asientos del libro de artículos, asientos de valor, diarios de artículos, inventario físico
- **Almacén** — recepciones de almacén, envíos, put-away, picking, asientos de almacén

## Exclusiones

Los siguientes módulos de BC están **permanentemente fuera de alcance** para este proyecto:

- Fabricación (órdenes de producción, rutas, salida)
- Proyectos (líneas de planificación de trabajo, asientos de libro de trabajo)
- Gestión de Servicios (órdenes de servicio, artículos de servicio)

La integración con básculas (captura automática de peso desde hardware) también está fuera de alcance en todas las fases.
