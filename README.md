# FlorShopCPE

Librería Swift para construir, validar, transformar, firmar, empaquetar y
enviar comprobantes electrónicos UBL a SUNAT.

## Notas de crédito

La API pública incluye `NotaCredito`, `CreditNoteLine`,
`CreditNoteReasonCode`, `CreditNoteValidator` y
`CreditNoteXMLTransformer`.

- Una nota que afecta una factura se firma con
  `XMLSecCPESigner.sign(_:configuration:)`, se escribe mediante
  `CPEDocumentWriter` y se envía individualmente con `SunatBillClient`.
- Una nota que afecta una boleta se convierte con
  `DailySummaryLine(lineID:creditNote:condition:)` y se incluye en un
  `ResumenDiarioBoletas`.

La librería no administra correlativos, almacenamiento, colas ni reintentos.
El POS que la consume conserva esas responsabilidades.

## Notas de débito

La API pública incluye `NotaDebito`, `DebitNoteLine`,
`DebitNoteReasonCode`, `DebitNoteValidator` y
`DebitNoteXMLTransformer`. Los motivos disponibles corresponden al catálogo
10 vigente de SUNAT.

El emisor debe proporcionar en su dirección el `addressTypeCode` de cuatro
dígitos correspondiente al establecimiento declarado ante SUNAT (por ejemplo,
`0000`). La librería lo valida, pero no lo calcula ni asigna uno por defecto.

- Una nota que afecta una factura usa serie `F...`, se firma con
  `XMLSecCPESigner.sign(_:configuration:)` y se envía individualmente con
  `SunatBillClient` después de que la factura afectada haya sido aceptada.
- Una nota que afecta una boleta usa serie `B...`, se convierte con
  `DailySummaryLine(lineID:debitNote:condition:)` y se informa como documento
  `08` dentro de un `ResumenDiarioBoletas`.

La consulta de existencia y estado del comprobante afectado requiere datos de
SUNAT/OSE; por eso no forma parte de la validación local del modelo.

## Comunicación de bajas

La API pública incluye `ComunicacionBaja`, `VoidedDocumentsIdentifier`,
`VoidedDocumentLine`, `VoidedDocumentsValidator` y
`VoidedDocumentsXMLTransformer`. Genera el documento `RA` UBL 2.0 exigido por
SUNAT y usa el flujo asíncrono de `SunatSummaryClient`: primero `submit` devuelve
un ticket y después `status` permite consultar la CDR.

Una Comunicación de Baja se usa para facturas y notas de crédito o débito con
serie `F...` que fueron generadas pero no otorgadas al cliente. La librería no
permite incluir boletas ni notas de serie `B...`: esos documentos se informan
con condición de baja dentro de `ResumenDiarioBoletas`.

La validación local comprueba el identificador `RA-YYYYMMDD-#####`, fechas,
RUC, líneas, tipo de documento, serie, correlativo y motivo. SUNAT comprueba al
recibirla que el documento exista, que su estado permita la baja y que se
respete el plazo normativo. La persistencia del ticket, la consulta periódica,
los reintentos y el control de correlativos siguen siendo responsabilidad del
POS.
