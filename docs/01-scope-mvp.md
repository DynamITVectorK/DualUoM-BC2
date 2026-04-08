# Alcance y MVP — DualUoM-BC

## MVP (Fase 1)

El MVP entrega el conjunto mínimo de funcionalidades necesarias para comprar, recepcionar, vender y enviar
un artículo usando dos unidades de medida con un ratio de conversión variable.

### En alcance para el MVP

- **Configuración DUoM del artículo** — indicador por artículo para activar DUoM, elección del modo de conversión
  (fijo / variable / siempre variable), código de segunda UdM
- **Motor de cálculo** — codeunit para calcular y validar la segunda cantidad a partir de la primera
  usando el modo de conversión activo
- **Líneas de compra** — campo de segunda cantidad en líneas de pedido de compra y líneas de recepción
- **Asientos del libro de artículos** — segunda cantidad y ratio persistidos en los asientos del libro de artículos
- **Líneas de venta** — campo de segunda cantidad en líneas de pedido de venta y líneas de envío
- **Diario de inventario** — campo de segunda cantidad en líneas del diario de artículos
- **Validación básica de contabilización** — garantizar que la segunda cantidad esté presente cuando DUoM está habilitado
  antes de contabilizar
- **Pruebas automatizadas** — pruebas unitarias e integradas para todo lo anterior

### Criterios de éxito del MVP

- Un artículo con DUoM habilitado puede comprarse con ambas cantidades visibles y contabilizadas
- Un artículo con DUoM habilitado puede venderse con ambas cantidades visibles y contabilizadas
- Los asientos del libro de artículos llevan la segunda cantidad y el ratio correctos
- Todas las pruebas pasan en CI

---

## Fase 2

- Ratio real específico por lote (segunda cantidad por lote almacenada en Seguimiento de artículos)
- Inventario físico con segunda cantidad
- Recepciones y envíos de almacén con segunda cantidad
- Put-away y picking dirigido con segunda cantidad
- Propagación de asientos de valor (para la precisión de costes)
- Extensiones de informes (columnas de segunda cantidad en informes estándar)

---

## Fase 3 / Posterior

- Pedidos de transferencia con segunda cantidad
- Pedidos de devolución (compra y venta) con segunda cantidad
- Ensamblado (si alguna vez se añade al alcance)
- Flujos entre empresas

---

## Permanentemente fuera de alcance

- Fabricación (órdenes de producción, diario de salida, capacidad)
- Proyectos (planificación de trabajo, libro de trabajo)
- Gestión de Servicios (órdenes de servicio)
- Integración con básculas / hardware
- Traducción a múltiples idiomas (la característica de archivo de traducción está habilitada pero no es un objetivo de entrega)
- Mapeo E-Document / EDI para segunda cantidad
