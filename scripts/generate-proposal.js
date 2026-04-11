"use strict";

/**
 * generate-proposal.js
 *
 * Genera el documento de oferta comercial de DualUoM-BC en formato .docx.
 * Ejecutar con: node scripts/generate-proposal.js
 * Requisito: npm install (docx >= 9.x)
 */

const path = require("path");
const fs = require("fs");
const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  HeadingLevel,
  AlignmentType,
  Table,
  TableRow,
  TableCell,
  WidthType,
  BorderStyle,
  ShadingType,
  PageBreak,
  Header,
  Footer,
  PageNumber,
  NumberFormat,
  convertInchesToTwip,
  TableOfContents,
  StyleLevel,
  LevelFormat,
  UnderlineType,
  LineRuleType,
  VerticalAlign,
  PageOrientation,
} = require("docx");

// ─────────────────────────────────────────────────────────────────────────────
// Colores corporativos
// ─────────────────────────────────────────────────────────────────────────────
const COLOR = {
  DARK_BLUE: "1F3864",
  MID_BLUE: "2E5FA3",
  LIGHT_BLUE: "D9E2F3",
  ACCENT: "4472C4",
  WHITE: "FFFFFF",
  LIGHT_GRAY: "F2F2F2",
  DARK_GRAY: "404040",
  GREEN: "375623",
  GREEN_BG: "E2EFDA",
  ORANGE: "843C0C",
  ORANGE_BG: "FCE4D6",
  TEXT: "1A1A1A",
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de formato
// ─────────────────────────────────────────────────────────────────────────────

function blankLine(space = 200) {
  return new Paragraph({ spacing: { before: space, after: space } });
}

function heading1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    children: [
      new TextRun({
        text,
        bold: true,
        color: COLOR.WHITE,
        size: 28,
        font: "Calibri",
      }),
    ],
    shading: { type: ShadingType.SOLID, color: COLOR.DARK_BLUE, fill: COLOR.DARK_BLUE },
    spacing: { before: 400, after: 200 },
    indent: { left: convertInchesToTwip(0.15), right: convertInchesToTwip(0.15) },
  });
}

function heading2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    children: [
      new TextRun({
        text,
        bold: true,
        color: COLOR.DARK_BLUE,
        size: 24,
        font: "Calibri",
      }),
    ],
    spacing: { before: 300, after: 100 },
    border: {
      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR.ACCENT },
    },
  });
}

function heading3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    children: [
      new TextRun({
        text,
        bold: true,
        color: COLOR.MID_BLUE,
        size: 22,
        font: "Calibri",
      }),
    ],
    spacing: { before: 200, after: 80 },
  });
}

function bodyText(text, opts = {}) {
  return new Paragraph({
    children: [
      new TextRun({
        text,
        size: 20,
        font: "Calibri",
        color: COLOR.TEXT,
        bold: opts.bold || false,
        italics: opts.italic || false,
      }),
    ],
    spacing: { before: 80, after: 80 },
    alignment: opts.align || AlignmentType.LEFT,
  });
}

function bulletText(text, opts = {}) {
  return new Paragraph({
    bullet: { level: opts.level || 0 },
    children: [
      new TextRun({
        text,
        size: 20,
        font: "Calibri",
        color: COLOR.TEXT,
        bold: opts.bold || false,
      }),
    ],
    spacing: { before: 60, after: 60 },
    indent: { left: convertInchesToTwip(0.25 * ((opts.level || 0) + 1)), hanging: convertInchesToTwip(0.25) },
  });
}

function noteBox(text, type = "info") {
  const bg = type === "warning" ? COLOR.ORANGE_BG : COLOR.LIGHT_BLUE;
  const textColor = type === "warning" ? COLOR.ORANGE : COLOR.DARK_BLUE;
  return new Paragraph({
    children: [
      new TextRun({
        text: type === "warning" ? "⚠  " : "ℹ  ",
        bold: true,
        color: textColor,
        size: 20,
        font: "Calibri",
      }),
      new TextRun({
        text,
        size: 20,
        font: "Calibri",
        color: textColor,
        italics: true,
      }),
    ],
    shading: { type: ShadingType.SOLID, color: bg, fill: bg },
    spacing: { before: 120, after: 120 },
    indent: { left: convertInchesToTwip(0.2), right: convertInchesToTwip(0.2) },
  });
}

function pageBreak() {
  return new Paragraph({ children: [new PageBreak()] });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper de tabla
// ─────────────────────────────────────────────────────────────────────────────

function makeTable(headers, rows, colWidths) {
  const headerCells = headers.map((h, i) =>
    new TableCell({
      children: [
        new Paragraph({
          children: [new TextRun({ text: h, bold: true, size: 18, color: COLOR.WHITE, font: "Calibri" })],
          alignment: AlignmentType.CENTER,
        }),
      ],
      shading: { type: ShadingType.SOLID, color: COLOR.DARK_BLUE, fill: COLOR.DARK_BLUE },
      width: colWidths ? { size: colWidths[i], type: WidthType.PERCENTAGE } : undefined,
      verticalAlign: VerticalAlign.CENTER,
    })
  );

  const dataRows = rows.map((row, ri) =>
    new TableRow({
      children: row.map((cell, ci) => {
        const isStatus = headers[ci] === "Estado";
        let bg = ri % 2 === 0 ? COLOR.WHITE : COLOR.LIGHT_GRAY;
        let textColor = COLOR.TEXT;
        if (isStatus) {
          if (typeof cell === "string" && cell.includes("✅")) { bg = COLOR.GREEN_BG; textColor = COLOR.GREEN; }
          else if (typeof cell === "string" && cell.includes("🔲")) { bg = COLOR.ORANGE_BG; textColor = COLOR.ORANGE; }
        }
        return new TableCell({
          children: [
            new Paragraph({
              children: [new TextRun({ text: String(cell), size: 18, font: "Calibri", color: textColor })],
              alignment: AlignmentType.LEFT,
            }),
          ],
          shading: { type: ShadingType.SOLID, color: bg, fill: bg },
          width: colWidths ? { size: colWidths[ci], type: WidthType.PERCENTAGE } : undefined,
          verticalAlign: VerticalAlign.CENTER,
          margins: { top: 80, bottom: 80, left: 120, right: 120 },
        });
      }),
    })
  );

  return new Table({
    rows: [
      new TableRow({ children: headerCells, tableHeader: true }),
      ...dataRows,
    ],
    width: { size: 100, type: WidthType.PERCENTAGE },
    margins: { top: 80, bottom: 80, left: 120, right: 120 },
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Portada
// ─────────────────────────────────────────────────────────────────────────────
function buildCover() {
  return [
    blankLine(800),
    new Paragraph({
      children: [
        new TextRun({
          text: "DualUoM-BC",
          bold: true,
          size: 64,
          color: COLOR.DARK_BLUE,
          font: "Calibri",
        }),
      ],
      alignment: AlignmentType.CENTER,
      spacing: { before: 0, after: 160 },
    }),
    new Paragraph({
      children: [
        new TextRun({
          text: "Segunda Unidad de Medida para Microsoft Dynamics 365 Business Central",
          size: 28,
          color: COLOR.MID_BLUE,
          font: "Calibri",
          italics: true,
        }),
      ],
      alignment: AlignmentType.CENTER,
      spacing: { before: 0, after: 480 },
    }),
    new Paragraph({
      children: [
        new TextRun({
          text: "PROPUESTA COMERCIAL",
          bold: true,
          size: 36,
          color: COLOR.WHITE,
          font: "Calibri",
          allCaps: true,
        }),
      ],
      alignment: AlignmentType.CENTER,
      shading: { type: ShadingType.SOLID, color: COLOR.ACCENT, fill: COLOR.ACCENT },
      spacing: { before: 120, after: 120 },
    }),
    blankLine(600),
    new Paragraph({
      children: [
        new TextRun({
          text: "Preparada para:",
          size: 22,
          color: COLOR.DARK_GRAY,
          font: "Calibri",
        }),
      ],
      alignment: AlignmentType.CENTER,
      spacing: { before: 0, after: 80 },
    }),
    new Paragraph({
      children: [
        new TextRun({
          text: "[NOMBRE DEL CLIENTE]",
          bold: true,
          size: 30,
          color: COLOR.DARK_BLUE,
          font: "Calibri",
          underline: { type: UnderlineType.SINGLE, color: COLOR.DARK_BLUE },
        }),
      ],
      alignment: AlignmentType.CENTER,
      spacing: { before: 0, after: 400 },
    }),
    new Paragraph({
      children: [
        new TextRun({
          text: `Versión 1.0  ·  ${new Date().toLocaleDateString("es-ES", { year: "numeric", month: "long", day: "numeric" })}`,
          size: 18,
          color: COLOR.DARK_GRAY,
          font: "Calibri",
        }),
      ],
      alignment: AlignmentType.CENTER,
      spacing: { before: 0, after: 80 },
    }),
    new Paragraph({
      children: [
        new TextRun({
          text: "Confidencial · No distribuir sin autorización del emisor",
          size: 16,
          color: COLOR.DARK_GRAY,
          font: "Calibri",
          italics: true,
        }),
      ],
      alignment: AlignmentType.CENTER,
    }),
    pageBreak(),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Secciones del documento
// ─────────────────────────────────────────────────────────────────────────────

function buildIntroduction() {
  return [
    heading1("1. Resumen ejecutivo"),
    bodyText(
      "La presente propuesta describe la implantación de DualUoM-BC, una extensión certificada para Microsoft Dynamics 365 Business Central SaaS que permite gestionar simultáneamente dos unidades de medida distintas para el mismo artículo a lo largo de toda la cadena logística: compras, ventas, almacén e inventario."
    ),
    blankLine(80),
    bodyText(
      "Muchas empresas de los sectores agroalimentario, químico, agrícola y metalúrgico comercializan productos que se pesan en una unidad (p. ej. kilogramos) y se cuentan o facturan en otra (p. ej. piezas, cajas, bandejas). La conversión entre ambas unidades varía por lote, y Business Central estándar no permite gestionarla de forma flexible y trazable."
    ),
    blankLine(80),
    bodyText(
      "DualUoM-BC resuelve este problema de forma nativa, sin modificar la aplicación base de Business Central, garantizando la compatibilidad con futuras actualizaciones de Microsoft y la posibilidad de desinstalación limpia."
    ),
    blankLine(80),
    noteBox(
      "La extensión ya cuenta con una base funcional completa (Fase 1 / MVP) en producción. Esto reduce significativamente el riesgo del proyecto y acorta los plazos de puesta en marcha."
    ),
    pageBreak(),
  ];
}

function buildBusinessContext() {
  return [
    heading1("2. Problemática y necesidad del negocio"),
    heading2("2.1 El problema"),
    bodyText(
      "Business Central soporta una unidad de medida alternativa por artículo mediante la tabla de 'Unidades de medida de artículo'. Sin embargo, esta solución estándar tiene limitaciones críticas para muchas operativas:"
    ),
    blankLine(60),
    makeTable(
      ["Requisito operativo", "Business Central estándar", "DualUoM-BC"],
      [
        ["Ratio fijo entre dos UdM", "✅ Tabla UdM artículo", "✅ Reaprovechado"],
        ["Ratio variable por transacción", "❌ No soportado", "✅ Campo en líneas de documento"],
        ["Siempre variable (sin ratio fijo)", "❌ No soportado", "✅ Modo 'Siempre Variable'"],
        ["Ratio real por lote (trazabilidad)", "❌ No soportado", "✅ Fase 2 — ratio por lote"],
        ["Segunda cantidad en líneas de compra/venta", "❌ No soportado", "✅ Extensión de tabla"],
        ["Segunda cantidad en asientos de producto", "❌ No soportado", "✅ Extensión de tabla"],
        ["Segunda cantidad en almacén", "❌ No soportado", "✅ Fase 2 — almacén avanzado"],
      ],
      [45, 27, 28]
    ),
    blankLine(100),
    heading2("2.2 Ejemplo de negocio"),
    bodyText(
      "Una empresa hortofrutícola compra 10 kg de lechuga (facturado por peso) pero los recibe como 8 piezas (contados y almacenados por unidad). La relación 10 kg / 8 pcs varía en cada entrega según el peso real de la mercancía. Sin DualUoM-BC, el equipo debe gestionar esta conversión en hojas de cálculo externas, con el consiguiente riesgo de errores, pérdida de trazabilidad y trabajo manual."
    ),
    blankLine(80),
    heading2("2.3 Módulos cubiertos"),
    bodyText("La solución se integra en los siguientes módulos de Business Central:"),
    blankLine(40),
    bulletText("Compras: pedidos, recepciones, facturas y abonos"),
    bulletText("Ventas: pedidos, albaranes, facturas y abonos"),
    bulletText("Inventario: diarios de producto, asientos de producto, inventario físico"),
    bulletText("Almacén: recepciones y expediciones de almacén, picking y ubicación dirigidos (Fase 2)"),
    blankLine(80),
    bodyText("Quedan fuera del alcance de forma permanente: Fabricación, Proyectos y Gestión de servicios.", { italic: true }),
    pageBreak(),
  ];
}

function buildSolution() {
  return [
    heading1("3. La solución: DualUoM-BC"),
    heading2("3.1 Arquitectura técnica"),
    bodyText(
      "DualUoM-BC es una extensión de tipo PTE (Per-Tenant Extension) que se despliega directamente en el entorno Business Central SaaS del cliente a través del centro de administración de Microsoft. No requiere ninguna modificación de la aplicación base y es compatible con las actualizaciones continuas de Microsoft."
    ),
    blankLine(80),
    bodyText("Principios de diseño:"),
    bulletText("Solo extensiones: ninguna tabla ni código base de BC es modificado"),
    bulletText("Diseño orientado a eventos: toda integración se realiza mediante suscriptores a eventos publicados de BC"),
    bulletText("Sin estado global ni dependencias externas"),
    bulletText("Compatible con cloud-only (SaaS): no requiere Docker ni acceso al sistema de archivos en tiempo de ejecución"),
    bulletText("Cero APIs obsoletas: construido sobre las APIs actuales de BC 27"),
    blankLine(80),
    heading2("3.2 Modos de conversión"),
    bodyText("La extensión soporta tres modos de conversión, configurables por artículo:"),
    blankLine(60),
    makeTable(
      ["Modo", "Descripción", "Caso de uso típico"],
      [
        ["Fijo", "La segunda cantidad se calcula automáticamente multiplicando la cantidad principal por el ratio fijo configurado. El usuario no puede modificarla.", "1 caja = siempre 12 uds."],
        ["Variable", "El sistema propone un ratio por defecto pero el usuario puede modificarlo en cada línea de documento. El ratio real queda registrado.", "KG/pcs con peso promedio por defecto, ajustable al pesaje real."],
        ["Siempre Variable", "No hay ratio por defecto. El usuario introduce manualmente la segunda cantidad en cada transacción.", "Productos frescos donde cada partida tiene un peso distinto."],
      ],
      [18, 52, 30]
    ),
    blankLine(100),
    heading2("3.3 Propagación de la segunda cantidad"),
    bodyText(
      "La segunda cantidad y el ratio utilizado se propagan y almacenan en todos los niveles del documento y del asiento contable:"
    ),
    blankLine(60),
    makeTable(
      ["Punto de la cadena", "Segunda cantidad visible", "Segunda cantidad editable"],
      [
        ["Línea de pedido de compra", "✅", "✅ (según modo)"],
        ["Línea de albarán de compra", "✅", "✅ (según modo)"],
        ["Línea de pedido de venta", "✅", "✅ (según modo)"],
        ["Línea de albarán de venta", "✅", "✅ (según modo)"],
        ["Línea de diario de producto", "✅", "✅"],
        ["Asiento de producto (histórico)", "✅", "❌ Inmutable tras contabilizar"],
        ["Línea de albarán de almacén (Fase 2)", "✅", "✅"],
      ],
      [45, 30, 25]
    ),
    pageBreak(),
  ];
}

function buildImplementationStatus() {
  return [
    heading1("4. Estado actual de implementación"),
    bodyText(
      "A continuación se detalla el estado de cada elemento del backlog de desarrollo:"
    ),
    blankLine(80),
    heading2("4.1 Fase 1 — MVP (completada)"),
    blankLine(60),
    makeTable(
      ["Nº", "Funcionalidad", "Estado", "Entregables"],
      [
        ["1", "Documentación de gobernanza y arquitectura", "✅ Completado", "Docs, README, copilot-instructions"],
        ["2", "Motor de cálculo DUoM (Calc Engine)", "✅ Completado", "DUoMCalcEngine (50101) + tests (50204)"],
        ["3", "Tabla y página de configuración por artículo", "✅ Completado", "DUoMItemSetup (50100) + page (50100) + page ext. Item Card"],
        ["4", "Campos DUoM en líneas de compra", "✅ Completado", "TableExt Purchase Line (50110) + PageExt (50101) + tests (50205)"],
        ["5", "Propagación DUoM a asientos de producto (compras)", "✅ Completado", "DUoMInventorySubscribers (50104) + ILE TableExt (50113)"],
        ["6", "Campos DUoM en líneas de venta", "✅ Completado", "TableExt Sales Line (50111) + PageExt (50102) + tests (50206)"],
        ["7", "Propagación DUoM a asientos de producto (ventas)", "✅ Completado", "Incluido en DUoMInventorySubscribers (50104)"],
        ["8", "Campos DUoM en diario de producto y propagación", "✅ Completado", "TableExt Item Journal Line (50112) + tests (50207)"],
      ],
      [5, 38, 20, 37]
    ),
    blankLine(100),
    noteBox(
      "Toda la Fase 1 ha superado las pruebas automatizadas de integración (TDD). Los tests cubren los siete escenarios de negocio críticos: conversión fija, variable y siempre variable; contabilización de compras, ventas y diario; e ítems sin DUoM habilitado."
    ),
    blankLine(80),
    heading2("4.2 Fase 2 — Almacén avanzado y trazabilidad por lote (pendiente)"),
    blankLine(60),
    makeTable(
      ["Nº", "Funcionalidad", "Estado"],
      [
        ["9", "Ratio real por lote (Item Tracking)", "🔲 Pendiente"],
        ["10", "Campos DUoM en albaranes de almacén (recepción y expedición)", "🔲 Pendiente"],
        ["11", "Campos DUoM en picking y ubicación dirigidos", "🔲 Pendiente"],
        ["12", "Inventario físico con segunda cantidad", "🔲 Pendiente"],
        ["13", "Extensiones de informes (columnas segunda cantidad)", "🔲 Pendiente"],
      ],
      [5, 75, 20]
    ),
    blankLine(100),
    heading2("4.3 Fase 3 — Documentos adicionales (posterior a Fase 2)"),
    blankLine(60),
    makeTable(
      ["Nº", "Funcionalidad", "Estado"],
      [
        ["14", "Órdenes de traslado con segunda cantidad", "🔲 Pendiente"],
        ["15", "Devoluciones de compra y venta con segunda cantidad", "🔲 Pendiente"],
      ],
      [5, 75, 20]
    ),
    pageBreak(),
  ];
}

function buildDeliverables() {
  return [
    heading1("5. Entregables por fase"),
    heading2("5.1 Fase 1 — Puesta en marcha (MVP ya implementado)"),
    bodyText(
      "La Fase 1 incluye la instalación y configuración del MVP en el entorno del cliente, formación básica y soporte durante la puesta en marcha:"
    ),
    blankLine(60),
    bulletText("Instalación de la extensión DualUoM-BC en el entorno SaaS del cliente"),
    bulletText("Configuración de la segunda unidad de medida para los artículos del cliente"),
    bulletText("Revisión de la parametrización junto al equipo del cliente"),
    bulletText("Formación práctica a usuarios clave (compras, ventas, almacén)"),
    bulletText("Soporte post-implantación (20 horas hábiles)"),
    bulletText("Documentación de usuario personalizada"),
    blankLine(80),
    heading2("5.2 Fase 2 — Almacén avanzado y trazabilidad por lote"),
    bulletText("Ratio real por lote: almacenamiento y prellenado automático al seleccionar lote"),
    bulletText("Albaranes de almacén con campo de segunda cantidad (recepción y expedición)"),
    bulletText("Documentos de picking y ubicación con segunda cantidad"),
    bulletText("Inventario físico: recuento con segunda cantidad"),
    bulletText("Extensiones de informes: columnas de segunda cantidad en informes estándar (albarán de compra, albarán de venta, inventario)"),
    bulletText("Tests de integración completos para todos los flujos de Fase 2"),
    blankLine(80),
    heading2("5.3 Fase 3 — Documentos adicionales"),
    bulletText("Órdenes de traslado: segunda cantidad en líneas de traslado y asientos"),
    bulletText("Devoluciones de compra y venta: segunda cantidad en todos los documentos de retorno"),
    bulletText("Tests de integración completos para todos los flujos de Fase 3"),
    pageBreak(),
  ];
}

function buildEstimates() {
  return [
    heading1("6. Estimación de esfuerzo y coste"),
    bodyText(
      "La tarifa de trabajo es de 500 €/jornada (jornada de 8 horas). El proyecto se factura a precio cerrado por fases, eliminando el riesgo de desviación para el cliente. Los importes no incluyen IVA."
    ),
    blankLine(80),
    heading2("6.1 Desglose por fase"),
    blankLine(60),
    makeTable(
      ["Fase", "Alcance", "Jornadas", "Importe (€)"],
      [
        [
          "Fase 1 — Puesta en marcha",
          "Instalación, configuración, formación y soporte (MVP ya desarrollado)",
          "4",
          "2.000 €",
        ],
        [
          "Fase 2 — Almacén y trazabilidad",
          "Issues 9–13: ratio por lote, almacén avanzado, inventario físico, informes",
          "20",
          "10.000 €",
        ],
        [
          "Fase 3 — Documentos adicionales",
          "Issues 14–15: traslados y devoluciones",
          "8",
          "4.000 €",
        ],
        ["", "TOTAL DEL PROYECTO", "32", "16.000 €"],
      ],
      [27, 45, 12, 16]
    ),
    blankLine(100),
    noteBox(
      "Precio cerrado por fase. El cliente sólo contrata las fases que necesita. Es posible iniciar con Fase 1 y ampliar el contrato a Fase 2 y/o Fase 3 más adelante."
    ),
    blankLine(80),
    heading2("6.2 Desglose detallado — Fase 2"),
    blankLine(60),
    makeTable(
      ["Funcionalidad", "Análisis", "Desarrollo", "Pruebas", "Total jornadas"],
      [
        ["Ratio real por lote (Issue 9)", "0,5", "2,5", "1", "4"],
        ["Almacén: recepción y expedición (Issue 10)", "0,5", "3", "1", "4,5"],
        ["Picking y ubicación dirigidos (Issue 11)", "0,5", "2", "0,5", "3"],
        ["Inventario físico (Issue 12)", "0,5", "1,5", "0,5", "2,5"],
        ["Extensiones de informes (Issue 13)", "0,5", "2", "0,5", "3"],
        ["QA integral + documentación", "—", "—", "—", "3"],
        ["TOTAL Fase 2", "—", "—", "—", "20"],
      ],
      [40, 12, 16, 12, 20]
    ),
    blankLine(100),
    heading2("6.3 Condiciones de pago"),
    makeTable(
      ["Hito de facturación", "Importe"],
      [
        ["Firma del contrato / inicio Fase 1", "50% de la fase contratada"],
        ["Aceptación del cliente / entrega final", "50% de la fase contratada"],
      ],
      [60, 40]
    ),
    pageBreak(),
  ];
}

function buildTimeline() {
  return [
    heading1("7. Plazos de entrega"),
    bodyText(
      "Los plazos indicados son orientativos a partir de la firma del contrato y la provisión por parte del cliente de acceso al entorno Business Central."
    ),
    blankLine(80),
    makeTable(
      ["Fase", "Inicio estimado", "Duración", "Entrega estimada"],
      [
        ["Fase 1 — Puesta en marcha", "Semana 1 tras firma", "1–2 semanas", "Semana 2–3"],
        ["Fase 2 — Almacén y trazabilidad", "Tras aceptación Fase 1", "4–6 semanas", "Semana 7–9"],
        ["Fase 3 — Documentos adicionales", "Tras aceptación Fase 2", "2–3 semanas", "Semana 10–12"],
      ],
      [27, 25, 20, 28]
    ),
    blankLine(100),
    noteBox(
      "Los plazos pueden ajustarse en función de la disponibilidad del equipo del cliente para sesiones de validación y aceptación."
    ),
    pageBreak(),
  ];
}

function buildQuality() {
  return [
    heading1("8. Calidad y metodología"),
    heading2("8.1 Desarrollo orientado a pruebas (TDD)"),
    bodyText(
      "Todo el código de la extensión se desarrolla siguiendo la metodología TDD (Test-Driven Development): primero se escriben los tests que definen el comportamiento esperado, luego se implementa el código que los hace pasar. Esto garantiza:"
    ),
    blankLine(60),
    bulletText("Cada funcionalidad tiene cobertura de test desde el primer día"),
    bulletText("Los errores se detectan antes de llegar al entorno del cliente"),
    bulletText("El código es verificable y refactorizable con seguridad"),
    blankLine(80),
    heading2("8.2 Integración continua (CI)"),
    bodyText(
      "El proyecto utiliza AL-Go for GitHub para ejecutar automáticamente el compilado y los tests en cada entrega. El cliente recibe la extensión sólo cuando todos los tests pasan en el pipeline de CI."
    ),
    blankLine(80),
    heading2("8.3 Arquitectura compatible con actualizaciones"),
    bodyText(
      "Al construirse exclusivamente mediante extensiones PTE sin modificar la base de Business Central, la solución es:"
    ),
    blankLine(60),
    bulletText("Compatible con los ciclos de actualización automática de Microsoft (wave updates)"),
    bulletText("Desinstalable de forma limpia si el cliente decide retirarla"),
    bulletText("Extensible en fases posteriores sin reescribir lo ya entregado"),
    pageBreak(),
  ];
}

function buildRisks() {
  return [
    heading1("9. Riesgos y plan de mitigación"),
    blankLine(40),
    makeTable(
      ["Riesgo", "Probabilidad", "Impacto", "Mitigación"],
      [
        [
          "Cambio de APIs de BC en actualización de Microsoft",
          "Baja",
          "Medio",
          "Arquitectura 100% extensión PTE; sin modificaciones a código base. Compilación continua en CI detecta incompatibilidades antes del despliegue.",
        ],
        [
          "Complejidad de los flujos de almacén avanzado (Fase 2)",
          "Media",
          "Medio",
          "Diseño modular por issue. Entregables incrementales. Los issues 9–13 son independientes y pueden priorizarse.",
        ],
        [
          "Retraso por disponibilidad del entorno cliente",
          "Media",
          "Bajo",
          "Fase 1 se puede validar en entorno de sandbox. Los plazos no empiezan a contar hasta provisión de acceso.",
        ],
        [
          "Alcance no cubierto detectado durante la implantación",
          "Baja",
          "Bajo",
          "Propuesta de alcance detallada y contrastada con el backlog del repositorio. Cualquier trabajo adicional se oferta como change request.",
        ],
      ],
      [28, 14, 10, 48]
    ),
    pageBreak(),
  ];
}

function buildOutOfScope() {
  return [
    heading1("10. Fuera del alcance de esta propuesta"),
    bodyText(
      "Para evitar malentendidos, se detalla lo que queda explícitamente excluido de esta propuesta:"
    ),
    blankLine(60),
    bulletText("Módulo de Fabricación (órdenes de producción, hojas de ruta, salida)"),
    bulletText("Módulo de Proyectos (líneas de planificación, asientos de proyecto)"),
    bulletText("Gestión de Servicios (órdenes de servicio, artículos de servicio)"),
    bulletText("Integración con básculas o hardware de pesaje automático"),
    bulletText("Flujos de empresa a empresa (intercompany)"),
    bulletText("Adaptaciones de documentos EDI o e-Document para la segunda cantidad"),
    bulletText("Formación avanzada más allá de la formación básica de puesta en marcha incluida en Fase 1"),
    blankLine(80),
    noteBox(
      "Cualquier funcionalidad fuera del alcance descrito puede ofertarse como un trabajo adicional (change request) con su propia estimación.",
      "warning"
    ),
    pageBreak(),
  ];
}

function buildNextSteps() {
  return [
    heading1("11. Pasos siguientes"),
    bodyText("Para avanzar con este proyecto:"),
    blankLine(60),
    bulletText("1. Revisión de la presente propuesta por parte de [NOMBRE DEL CLIENTE]", { bold: true }),
    bulletText("   Plazo sugerido: 5 días hábiles desde la recepción.", { level: 1 }),
    blankLine(40),
    bulletText("2. Reunión de aclaración (si procede)", { bold: true }),
    bulletText("   Resolución de dudas técnicas u operativas. Duración estimada: 1 hora.", { level: 1 }),
    blankLine(40),
    bulletText("3. Firma del contrato y definición del primer hito de Fase 1", { bold: true }),
    bulletText("   Provisión de acceso al entorno Business Central (sandbox o producción).", { level: 1 }),
    blankLine(40),
    bulletText("4. Inicio de la Fase 1 — Puesta en marcha", { bold: true }),
    bulletText("   Instalación, configuración y formación. Duración estimada: 1–2 semanas.", { level: 1 }),
    blankLine(120),
    bodyText("Para aceptar esta propuesta o solicitar una reunión de aclaración, contáctenos en:"),
    blankLine(40),
    new Paragraph({
      children: [
        new TextRun({
          text: "[CORREO ELECTRÓNICO DEL EMISOR]",
          bold: true,
          size: 22,
          color: COLOR.MID_BLUE,
          font: "Calibri",
          underline: { type: UnderlineType.SINGLE, color: COLOR.MID_BLUE },
        }),
      ],
      spacing: { before: 80, after: 80 },
      alignment: AlignmentType.CENTER,
    }),
    new Paragraph({
      children: [
        new TextRun({
          text: "[TELÉFONO DEL EMISOR]",
          bold: true,
          size: 22,
          color: COLOR.MID_BLUE,
          font: "Calibri",
        }),
      ],
      spacing: { before: 80, after: 80 },
      alignment: AlignmentType.CENTER,
    }),
    pageBreak(),
  ];
}

function buildTermsAndConditions() {
  return [
    heading1("12. Condiciones generales"),
    heading2("12.1 Validez de la oferta"),
    bodyText(
      "Esta propuesta tiene una validez de 30 días naturales desde la fecha indicada en la portada. Transcurrido ese plazo, los precios y plazos podrán ser revisados."
    ),
    blankLine(80),
    heading2("12.2 Propiedad intelectual"),
    bodyText(
      "El código fuente entregado pasa a ser propiedad del cliente una vez liquidada la totalidad de la fase correspondiente. El proveedor conserva el derecho a reutilizar patrones genéricos y arquitectura en otros proyectos no competidores."
    ),
    blankLine(80),
    heading2("12.3 Confidencialidad"),
    bodyText(
      "Ambas partes se comprometen a mantener la confidencialidad sobre el contenido de esta propuesta, la información técnica compartida durante el proyecto y los datos del entorno del cliente."
    ),
    blankLine(80),
    heading2("12.4 Cambios de alcance"),
    bodyText(
      "Cualquier funcionalidad no descrita explícitamente en esta propuesta constituye un cambio de alcance y requerirá una oferta específica previa a su realización. No se realizará trabajo no presupuestado sin aprobación escrita del cliente."
    ),
    blankLine(80),
    heading2("12.5 Garantía"),
    bodyText(
      "Se garantiza la corrección de defectos en el código entregado durante un período de 60 días naturales tras la aceptación de cada fase, sin coste adicional para el cliente. Los defectos derivados de cambios en el entorno del cliente o de actualizaciones de Microsoft posteriores a la entrega quedan fuera de la garantía."
    ),
    blankLine(200),
    new Paragraph({
      children: [
        new TextRun({
          text: "Aceptación de la propuesta",
          bold: true,
          size: 24,
          color: COLOR.DARK_BLUE,
          font: "Calibri",
        }),
      ],
      spacing: { before: 200, after: 120 },
      alignment: AlignmentType.CENTER,
    }),
    makeTable(
      ["Por el proveedor", "Por el cliente"],
      [
        ["Nombre: ____________________________", "Nombre: ____________________________"],
        ["Cargo: _____________________________", "Cargo: _____________________________"],
        ["Fecha: _____________________________", "Fecha: _____________________________"],
        ["Firma: _____________________________", "Firma: _____________________________"],
      ],
      [50, 50]
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Encabezado y pie de página
// ─────────────────────────────────────────────────────────────────────────────

function buildHeader() {
  return new Header({
    children: [
      new Paragraph({
        children: [
          new TextRun({
            text: "DualUoM-BC — Propuesta Comercial Confidencial",
            size: 16,
            color: COLOR.DARK_GRAY,
            font: "Calibri",
            italics: true,
          }),
          new TextRun({
            text: "  ·  [NOMBRE DEL CLIENTE]",
            size: 16,
            color: COLOR.DARK_GRAY,
            font: "Calibri",
            italics: true,
          }),
        ],
        alignment: AlignmentType.RIGHT,
        border: {
          bottom: { style: BorderStyle.SINGLE, size: 2, color: COLOR.ACCENT },
        },
      }),
    ],
  });
}

function buildFooter() {
  return new Footer({
    children: [
      new Paragraph({
        children: [
          new TextRun({
            text: "Página ",
            size: 16,
            color: COLOR.DARK_GRAY,
            font: "Calibri",
          }),
          new TextRun({
            children: [PageNumber.CURRENT],
            size: 16,
            color: COLOR.DARK_GRAY,
            font: "Calibri",
          }),
          new TextRun({
            text: " de ",
            size: 16,
            color: COLOR.DARK_GRAY,
            font: "Calibri",
          }),
          new TextRun({
            children: [PageNumber.TOTAL_PAGES],
            size: 16,
            color: COLOR.DARK_GRAY,
            font: "Calibri",
          }),
          new TextRun({
            text: "  ·  Confidencial",
            size: 16,
            color: COLOR.DARK_GRAY,
            font: "Calibri",
            italics: true,
          }),
        ],
        alignment: AlignmentType.CENTER,
        border: {
          top: { style: BorderStyle.SINGLE, size: 2, color: COLOR.ACCENT },
        },
      }),
    ],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Construcción y guardado del documento
// ─────────────────────────────────────────────────────────────────────────────

async function generate() {
  const sections = [
    ...buildCover(),
    ...buildIntroduction(),
    ...buildBusinessContext(),
    ...buildSolution(),
    ...buildImplementationStatus(),
    ...buildDeliverables(),
    ...buildEstimates(),
    ...buildTimeline(),
    ...buildQuality(),
    ...buildRisks(),
    ...buildOutOfScope(),
    ...buildNextSteps(),
    ...buildTermsAndConditions(),
  ];

  const doc = new Document({
    creator: "DualUoM-BC Tools",
    title: "DualUoM-BC — Propuesta Comercial",
    description:
      "Propuesta comercial de precio cerrado para la implantación de DualUoM-BC en Microsoft Dynamics 365 Business Central SaaS.",
    subject: "Propuesta Comercial DualUoM-BC",
    keywords: "DualUoM, Business Central, Segunda Unidad de Medida, SaaS, Propuesta",
    styles: {
      default: {
        document: {
          run: {
            font: "Calibri",
            size: 20,
            color: COLOR.TEXT,
          },
          paragraph: {
            spacing: { line: 276, lineRule: LineRuleType.AUTO },
          },
        },
        heading1: {
          run: { font: "Calibri", size: 28, bold: true, color: COLOR.WHITE },
        },
        heading2: {
          run: { font: "Calibri", size: 24, bold: true, color: COLOR.DARK_BLUE },
        },
        heading3: {
          run: { font: "Calibri", size: 22, bold: true, color: COLOR.MID_BLUE },
        },
      },
    },
    sections: [
      {
        properties: {
          page: {
            margin: {
              top: convertInchesToTwip(1),
              right: convertInchesToTwip(1.1),
              bottom: convertInchesToTwip(1),
              left: convertInchesToTwip(1.1),
            },
          },
        },
        headers: { default: buildHeader() },
        footers: { default: buildFooter() },
        children: sections,
      },
    ],
  });

  const outputPath = path.join(__dirname, "..", "docs", "oferta-DualUoM-BC.docx");
  const buffer = await Packer.toBuffer(doc);
  fs.writeFileSync(outputPath, buffer);
  console.log(`✅ Documento generado: ${outputPath}`);
  console.log(`   Tamaño: ${(buffer.length / 1024).toFixed(1)} KB`);
}

generate().catch((err) => {
  console.error("❌ Error al generar el documento:", err);
  process.exit(1);
});
