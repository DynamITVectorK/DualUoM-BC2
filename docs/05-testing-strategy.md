# Estrategia de Pruebas — DualUoM-BC

## TDD obligatorio

El Desarrollo Guiado por Pruebas (TDD) es **obligatorio** para este proyecto. No se escribe código AL de
producción sin una prueba que falle que defina primero el comportamiento esperado.

Flujo de trabajo para cada nueva funcionalidad:

1. Escribir un codeunit de prueba con uno o más procedimientos `[Test]` que fallen
2. Escribir el mínimo código de producción para que las pruebas pasen
3. Refactorizar si es necesario, manteniendo todas las pruebas en verde
4. Abrir el PR — el CI debe mostrar `TestResults.xml` en verde antes de considerar la fusión

---

## Tipos de prueba

### Pruebas unitarias

- Probar procedimientos individuales de codeunit de forma aislada
- Sin dependencia de los flujos de contabilización de documentos de BC donde sea evitable
- Rápidas, deterministas, sin estado externo
- Ejemplo: `DUoM Calc Engine Tests` que verifica que `ComputeSecondQty` devuelve el
  valor correcto para cada modo de conversión con entradas en los límites

### Pruebas de integración

- Probar un flujo completo de documento desde la creación hasta la contabilización
- Verificar que `Item Ledger Entry` contiene la segunda cantidad esperada tras la contabilización
- Usar los helpers de la biblioteca estándar de BC (`Library - Purchase`, `Library - Sales`, etc.) donde
  estén disponibles en la app de pruebas
- Aceptablemente más lentas; se ejecutan como parte del CI completo únicamente

### Pruebas de regresión

- Se añaden cada vez que se corrige un bug
- Nombradas para referenciar el issue que causó el bug
- Deben permanecer en el conjunto de pruebas de forma permanente

---

## Convenciones de codeunits de prueba

- Un codeunit de prueba por codeunit de producción (mínimo)
- IDs de objeto en el rango **50200–50299**
- Usar el atributo `[Test]` en cada procedimiento de prueba
- Usar `[HandlerFunctions(...)]` y manejadores de página modal para flujos iniciados por la UI
- Usar el patrón de comentarios `// [GIVEN] / [WHEN] / [THEN]` en cada procedimiento de prueba
- Usar `Library Assert` (`Codeunit "Library Assert"`) para todas las aserciones — sin helpers de aserción personalizados

Estructura de ejemplo:

```al
codeunit 50201 "DUoM Calc Engine Tests"
{
    Subtype = Test;

    [Test]
    procedure ComputeSecondQty_Fixed_ReturnsProduct()
    var
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with fixed conversion ratio 1.25
        // [WHEN] ComputeSecondQty is called with Qty = 10
        // [THEN] Result is 12.5
        LibraryAssert.AreEqual(12.5, ComputeFixed(10, 1.25), 'Fixed ratio calculation failed');
    end;
}
```

---

## Escenarios de negocio principales (deben cubrirse antes de ampliar el alcance)

Los siguientes escenarios deben tener pruebas que pasen antes de iniciar cualquier trabajo de Fase 2:

1. **Conversión fija** — segunda cantidad calculada correctamente a partir de la primera cantidad y el ratio
2. **Conversión variable** — el usuario puede sobreescribir el ratio predeterminado; almacenado correctamente
3. **Conversión siempre variable** — segunda cantidad aceptada solo como entrada manual
4. **Contabilización de compras** — ILE contiene la segunda cantidad correcta tras contabilizar una recepción de compra
5. **Contabilización de ventas** — ILE contiene la segunda cantidad correcta tras contabilizar un envío de venta
6. **Contabilización de diario de artículos** — ILE contiene la segunda cantidad correcta tras contabilizar una línea de diario
7. **Artículo con DUoM deshabilitado** — ningún campo DUoM afecta al flujo de contabilización estándar

---

## Validación en CI

- Todas las pruebas se ejecutan mediante AL-Go en runner `windows-latest` usando un contenedor Docker de BC
- `TestResults.xml` debe estar presente y en verde para que una ejecución se considere correcta
- Los workflows usan únicamente `workflow_dispatch` — ver `docs/ci-cost-decisions.md`
- Ninguna prueba puede omitirse ni comentarse para que pase el CI
