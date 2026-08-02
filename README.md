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
