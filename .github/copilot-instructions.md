# DualUoM-BC — Instrucciones para Copilot

## Idioma del proyecto

**El idioma oficial del proyecto es el español.**

- Toda documentación nueva, comentarios en issues y PRs, mensajes de commit y respuestas del agente Copilot deben escribirse en **español**.
- Los identificadores de objetos AL, nombres de campos, nombres de archivos y mensajes de error de BC se mantienen en inglés (requisito del lenguaje AL y las APIs de BC).
- Los comentarios dentro del código AL (`// [GIVEN] / [WHEN] / [THEN]`) pueden escribirse en inglés o en español, a elección del equipo.
- Los bloques de código y nombres de archivos/objetos permanecen en su forma original (inglés).

---

## Propósito del proyecto

Este repositorio contiene la extensión **DualUoM-BC** para Business Central SaaS.
El objetivo es añadir soporte de doble unidad de medida (UdM) a todos los módulos de BC
**excepto** Fabricación, Proyectos y Servicio.

Ejemplo de negocio: se compran 10 KG de lechuga y se reciben como 8 piezas. Ambas cantidades deben
almacenarse, contabilizarse y rastrearse, con soporte para ratios variables y por lote.

Stack tecnológico: AL · AL-Go for GitHub · Business Central SaaS (BC 27 / runtime 15) · TDD

## Estructura del repositorio

```
app/          Extensión principal (PTE)
  app.json    Manifiesto de la extensión — plataforma 27, runtime 15, destino Cloud
  src/
    enum/             Objetos enum de AL
    table/            Objetos table de AL
    tableextension/   Objetos tableextension de AL
    codeunit/         Objetos codeunit de AL
    page/             Objetos page de AL
    pageextension/    Objetos pageextension de AL
    permissionset/    Objetos permissionset de AL
    report/           Objetos report de AL

test/         Extensión de pruebas
  app.json    Manifiesto de la app de pruebas (depende de app/)
  src/
    codeunit/ Codeunits de prueba AL (testability framework)

.github/
  AL-Go-Settings.json   Configuración AL-Go a nivel de repositorio
  workflows/            GitHub Actions — TODOS manuales (workflow_dispatch)
  copilot-instructions.md  (este archivo)

docs/
  00-vision.md              Objetivo del proyecto, necesidad de negocio, módulos objetivo
  01-scope-mvp.md           MVP vs fases posteriores vs fuera de alcance
  02-functional-design.md   Modos de conversión, propagación, ratios por lote
  03-technical-architecture.md  Diseño de la extensión, eventos, principios SaaS
  05-testing-strategy.md    Reglas TDD, tipos de prueba, validación en CI
  06-backlog.md             Backlog de entrega ordenado
  ci-cost-decisions.md      Decisiones de ahorro de costes en CI
```

## Convenciones de codificación AL

- Rango de IDs de objeto: **50100–50199** (app), **50200–50299** (pruebas)
- Seguir las directrices de codificación AL de Microsoft y nomenclatura PascalCase
- Cada nueva funcionalidad AL debe tener un codeunit de prueba correspondiente en `test/src/codeunit/`
- Usar los analizadores `PerTenantExtensionCop`, `CodeCop` y `UICop` — política de cero advertencias
- Usar `NoImplicitWith` — nunca depender del ámbito implícito `with`
- Módulos en alcance: Sales, Purchase, Inventory, Warehouse
- Módulos **fuera de alcance**: Manufacturing, Projects, Service

## Regla de permission sets (obligatoria)

Cualquier nueva tabla u otro objeto asegurable que requiera cobertura de permisos **debe** ir acompañado de una actualización del permission set en el **mismo issue/PR**. En concreto:

- Cada nuevo objeto `table` debe tener una entrada `tabledata` correspondiente (RIMD o subconjunto apropiado) en un objeto `permissionset` bajo `app/src/permissionset/`.
- El archivo de permission set debe seguir la convención de nombres `<Nombre>.PermissionSet.al` y usar el rango de IDs del proyecto (50100–50199).
- El permission set global del proyecto es `permissionset 50100 "DUoM - All"` (`app/src/permissionset/DUoMAll.PermissionSet.al`). Añadir nuevas entradas de tabla ahí; crear permission sets adicionales solo si se necesitan niveles de acceso diferentes.
- No incluirlo provoca el error de compilación `PTE0004` — se aplica una política de tolerancia cero.

## Restricciones de Business Central SaaS

- Solo extensión: sin modificaciones a la app base, sin SQL directo, sin RPC
- Toda integración estándar de BC debe realizarse a través de eventos de integración publicados
- Sin patrones intrusivos: sin estado global, sin `OnBeforeInsert` que bloquee flujos de contabilización
- Sin APIs deprecadas — usar siempre los patrones actuales de BC 27
- Los despliegues SaaS son solo en la nube; sin código específico para OnPrem
- No asumir acceso a Docker ni al sistema de archivos en tiempo de ejecución

## Reglas de entrega

- Implementar solo lo que el issue actual requiere explícitamente — sin alcance especulativo
- Cada issue debe incluir pruebas automatizadas que pasen antes de considerarse terminado
- Seguir el orden del backlog en `docs/06-backlog.md` — los issues posteriores dependen de los anteriores
- No implementar lógica de almacén o lotes hasta que se abran los issues relevantes de Fase 2
- No implementar lógica de costes o entradas de valor a menos que esté explícitamente en el alcance

## Reglas de pruebas

- TDD es obligatorio: primero escribir una prueba que falle, luego el código de producción
- Los codeunits de prueba usan `Subtype = Test` y el atributo `[Test]` en cada procedimiento
- Usar el patrón de comentarios `// [GIVEN] / [WHEN] / [THEN]`
- Usar `Library Assert` (Microsoft) para todas las aserciones
- Ninguna prueba puede omitirse ni desactivarse para que pase el CI

## CI/CD — enfoque de mínimo coste

Cada archivo de workflow usa **únicamente** el disparador `workflow_dispatch:`.
Consultar `docs/ci-cost-decisions.md` para la justificación completa.

NO añadir disparadores automáticos (`push:`, `pull_request:`, `schedule:`) a ningún workflow.
