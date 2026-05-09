# AL Object ID Registry

Este documento registra los IDs de objetos AL asignados en el proyecto DualUoM-BC.

## Reglas

- Cada objeto AL debe tener una combinación única de **Tipo de objeto + ID** dentro de su app.
- Antes de crear un nuevo objeto, busca el ID previsto en el repositorio.
- No reutilices un ID de objeto al copiar un objeto existente.
- El ID elegido debe estar dentro del `idRanges` configurado en el `app.json` correspondiente.
- Actualiza este fichero en el mismo PR en que crees o elimines objetos AL.

---

## App principal (`app/`) — rango 50100–50199

### Tablas

| ID    | Nombre                    | Fichero                                   |
|------:|---------------------------|-------------------------------------------|
| 50100 | DUoM Item Setup           | app/src/table/DUoMItemSetup.Table.al      |
| 50101 | DUoM Item Variant Setup   | app/src/table/DUoMItemVariantSetup.Table.al |
| 50102 | DUoM Lot Ratio            | app/src/table/DUoMLotRatio.Table.al       |

### Extensiones de tabla

| ID    | Nombre                         | Extiende                  |
|------:|--------------------------------|---------------------------|
| 50100 | DUoM Item TableExt             | Item                      |
| 50110 | DUoM Purchase Line Ext         | Purchase Line             |
| 50111 | DUoM Sales Line Ext            | Sales Line                |
| 50112 | DUoM Item Journal Line Ext     | Item Journal Line         |
| 50113 | DUoM Item Ledger Entry Ext     | Item Ledger Entry         |
| 50114 | DUoM Purch. Rcpt. Line Ext     | Purch. Rcpt. Line         |
| 50115 | DUoM Sales Shipment Line Ext   | Sales Shipment Line       |
| 50116 | DUoM Purch. Inv. Line Ext      | Purch. Inv. Line          |
| 50117 | DUoM Purch. Cr. Memo Line Ext  | Purch. Cr. Memo Line      |
| 50118 | DUoM Sales Inv. Line Ext       | Sales Invoice Line        |
| 50119 | DUoM Sales Cr.Memo Line Ext    | Sales Cr.Memo Line        |
| 50120 | DUoM Item Variant Ext          | Item Variant              |
| 50121 | DUoM Value Entry Ext           | Value Entry               |
| 50122 | DUoM Tracking Spec Ext         | Tracking Specification    |
| 50123 | DUoM Reservation Entry Ext     | Reservation Entry         |

### Páginas

| ID    | Nombre                    | Fichero                                    |
|------:|---------------------------|--------------------------------------------|
| 50100 | DUoM Item Setup           | app/src/page/DUoMItemSetup.Page.al         |
| 50101 | DUoM Variant Setup List   | app/src/page/DUoMVariantSetupList.Page.al  |
| 50102 | DUoM Lot Ratio List       | app/src/page/DUoMLotRatioList.Page.al      |

### Extensiones de página

| ID    | Nombre                         | Extiende                          |
|------:|--------------------------------|-----------------------------------|
| 50100 | DUoM Item Card Ext             | Item Card                         |
| 50101 | DUoM Purchase Order Subform    | Purchase Order Subform            |
| 50102 | DUoM Sales Order Subform       | Sales Order Subform               |
| 50103 | DUoM Item Journal Ext          | Item Journal                      |
| 50104 | DUoM Posted Rcpt. Subform      | Posted Purchase Rcpt. Subform     |
| 50105 | DUoM Posted Ship. Subform      | Posted Sales Shpt. Subform        |
| 50106 | DUoM Pstd Purch Inv Subform    | Posted Purch. Invoice Subform     |
| 50107 | DUoM Pstd Purch CrM Subform    | Posted Purch. Cr. Memo Subform    |
| 50108 | DUoM Pstd Sales Inv Subform    | Posted Sales Invoice Subform      |
| 50109 | DUoM Pstd Sales CrM Subform    | Posted Sales Cr. Memo Subform     |
| 50110 | DUoM Item UoM Subform          | Item Units of Measure             |
| 50111 | DUoM Item Ledger Entry         | Item Ledger Entries               |
| 50112 | DUoM Item Tracking Lines       | Item Tracking Lines               |
| 50124 | DUoM Posted Item Trk. Lines    | Posted Item Tracking Lines        |

### Codeunits

| ID    | Nombre                              | Fichero                                                  |
|------:|-------------------------------------|----------------------------------------------------------|
| 50101 | DUoM Calc Engine                    | app/src/codeunit/DUoMCalcEngine.Codeunit.al              |
| 50102 | DUoM Purchase Subscribers           | app/src/codeunit/DUoMPurchaseSubscribers.Codeunit.al     |
| 50103 | DUoM Sales Subscribers              | app/src/codeunit/DUoMSalesSubscribers.Codeunit.al        |
| 50104 | DUoM Inventory Subscribers          | app/src/codeunit/DUoMInventorySubscribers.Codeunit.al    |
| 50105 | DUoM Doc Transfer Helper            | app/src/codeunit/DUoMDocTransferHelper.Codeunit.al       |
| 50106 | DUoM UoM Helper                     | app/src/codeunit/DUoMUoMHelper.Codeunit.al               |
| 50107 | DUoM Setup Resolver                 | app/src/codeunit/DUoMSetupResolver.Codeunit.al           |
| 50108 | DUoM Lot Subscribers                | app/src/codeunit/DUoMLotSubscribers.Codeunit.al          |
| 50109 | DUoM Tracking Subscribers           | app/src/codeunit/DUoMTrackingSubscribers.Codeunit.al     |
| 50110 | DUoM Tracking Copy Subscribers      | app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al |
| 50111 | DUoM Tracking Coherence Mgt         | app/src/codeunit/DUoMTrackingCoherenceMgt.Codeunit.al    |
| 50125 | DUoM Tracking Prop. Mgt            | app/src/codeunit/DUoMTrackingPropMgt.Codeunit.al         |
| 50126 | DUoM Sign Mgt                       | app/src/codeunit/DUoMSignMgt.Codeunit.al                 |

### Enums

| ID    | Nombre                  | Fichero                                   |
|------:|-------------------------|-------------------------------------------|
| 50100 | DUoM Conversion Mode    | app/src/enum/DUoMConversionMode.Enum.al   |

### Permission Sets

| ID    | Nombre        | Fichero                                             |
|------:|---------------|-----------------------------------------------------|
| 50100 | DUoM - All    | app/src/permissionset/DUoMAll.PermissionSet.al      |

---

## App de test (`test/`) — rango 50200–50299

### Codeunits de test

| ID    | Nombre                            | Fichero                                                          |
|------:|-----------------------------------|------------------------------------------------------------------|
| 50201 | DUoM Item Setup Tests             | test/src/codeunit/DUoMItemSetupTests.Codeunit.al                 |
| 50202 | DUoM Item Card Opening Tests      | test/src/codeunit/DUoMItemCardOpeningTests.Codeunit.al           |
| 50203 | DUoM Item Delete Tests            | test/src/codeunit/DUoMItemDeleteTests.Codeunit.al                |
| 50204 | DUoM Calc Engine Tests            | test/src/codeunit/DUoMCalcEngineTests.Codeunit.al                |
| 50205 | DUoM Purchase Tests               | test/src/codeunit/DUoMPurchaseTests.Codeunit.al                  |
| 50206 | DUoM Sales Tests                  | test/src/codeunit/DUoMSalesTests.Codeunit.al                     |
| 50207 | DUoM Inventory Tests              | test/src/codeunit/DUoMInventoryTests.Codeunit.al                 |
| 50208 | DUoM Test Helpers                 | test/src/codeunit/DUoMTestHelpers.Codeunit.al                    |
| 50209 | DUoM ILE Integration Tests        | test/src/codeunit/DUoMILEIntegrationTests.Codeunit.al            |
| 50210 | DUoM Inv CrMemo Post Tests        | test/src/codeunit/DUoMInvCrMemoPostTests.Codeunit.al             |
| 50211 | DUoM Variant Tests                | test/src/codeunit/DUoMVariantTests.Codeunit.al                   |
| 50212 | DUoM Item UoM Round Tests         | test/src/codeunit/DUoMItemUoMRoundTests.Codeunit.al              |
| 50213 | DUoM UoM Helper Tests             | test/src/codeunit/DUoMUoMHelperTests.Codeunit.al                 |
| 50214 | DUoM Variable Mode Post Tests     | test/src/codeunit/DUoMVarModePostTests.Codeunit.al               |
| 50215 | DUoM Variant Del Tests            | test/src/codeunit/DUoMVariantDelTests.Codeunit.al                |
| 50216 | DUoM Cost Price Tests             | test/src/codeunit/DUoMCostPriceTests.Codeunit.al                 |
| 50217 | DUoM Lot Ratio Tests              | test/src/codeunit/DUoMLotRatioTests.Codeunit.al                  |
| 50218 | DUoM Item Tracking Tests          | test/src/codeunit/DUoMItemTrackingTests.Codeunit.al              |
| 50219 | DUoM Purch Tracking Persist       | test/src/codeunit/DUoMPurchTrackingPersistTests.Codeunit.al      |
| 50220 | DUoM Tracking Coherence Tests     | test/src/codeunit/DUoMTrackingCoherenceTests.Codeunit.al         |
| 50221 | DUoM Purch Tracking Post Tests    | test/src/codeunit/DUoMPurchTrackingPostTests.Codeunit.al         |
| 50222 | DUoM Purch Track Close Tests      | test/src/codeunit/DUoMPurchTrackingCloseTests.Codeunit.al        |
| 50223 | DUoM Purch Track Val Tests        | test/src/codeunit/DUoMPurchTrackValTests.Codeunit.al             |
| 50224 | DUoM Pstd Item Trk. Tests         | test/src/codeunit/DUoMPstdItemTrkTests.Codeunit.al               |
| 50225 | DUoM Purch Sync Tests             | test/src/codeunit/DUoMPurchSyncTests.Codeunit.al                 |
| 50226 | DUoM Purch Lot Ratio Tests        | test/src/codeunit/DUoMPurchLotRatioTests.Codeunit.al             |
| 50227 | DUoM Undo Rcpt Shpt Tests         | test/src/codeunit/DUoMUndoRcptShptTests.Codeunit.al              |
| 50228 | DUoM Sign Mgt Tests               | test/src/codeunit/DUoMSignMgtTests.Codeunit.al                   |

### Permission Sets de test

| ID    | Nombre            | Fichero                                                    |
|------:|-------------------|------------------------------------------------------------|
| 50200 | DUoM - Test All   | test/src/permissionset/DUoMTestAll.PermissionSet.al        |

---

## Próximos IDs disponibles

| App      | Tipo                           | Próximo ID libre |
|----------|--------------------------------|-----------------|
| app/     | Cualquier tipo de objeto       | 50127           |
| test/    | Codeunit / permissionset       | 50229           |
