# DualUoM-BC

**Extensión de Doble Unidad de Medida para Microsoft Dynamics 365 Business Central SaaS.**

## Qué es esto

Una extensión de inquilino propio (PTE) que permite a los artículos llevar dos cantidades independientes de forma simultánea a través de los flujos de compras, ventas, inventario y almacén.

**Ejemplo:** 10 KG de lechuga recibida como 8 piezas. Ambas cantidades se almacenan, contabilizan y rastrean, incluso cuando el ratio varía por lote.

## Stack tecnológico

- Lenguaje: **AL**
- Plataforma: **Business Central SaaS** (BC 27 / runtime 15)
- CI/CD: **AL-Go for GitHub** (únicamente disparadores manuales `workflow_dispatch`)
- Pruebas: **AL Testability Framework** — TDD obligatorio

## Enlaces rápidos

| Documento | Descripción |
|---|---|
| [Visión](docs/00-vision.md) | Objetivo del proyecto, necesidad de negocio, módulos objetivo |
| [Alcance y MVP](docs/01-scope-mvp.md) | Qué está en el MVP, Fase 2 y fuera de alcance |
| [Diseño Funcional](docs/02-functional-design.md) | Configuración de artículo, modos de conversión, propagación |
| [Arquitectura Técnica](docs/03-technical-architecture.md) | Diseño de la extensión, eventos, principios SaaS |
| [Estrategia de Pruebas](docs/05-testing-strategy.md) | Reglas TDD, tipos de prueba, validación en CI |
| [Backlog](docs/06-backlog.md) | Backlog de entrega ordenado |
| [Decisiones de CI/Costo](docs/ci-cost-decisions.md) | Por qué el CI está configurado de esa manera |

## Módulos en alcance

- Compras · Ventas · Inventario · Almacén

## Módulos fuera de alcance

- Fabricación · Proyectos · Gestión de Servicios

## Rangos de IDs de objeto

| Extensión | Rango |
|---|---|
| App (`app/`) | 50100 – 50199 |
| Pruebas (`test/`) | 50200 – 50299 |
