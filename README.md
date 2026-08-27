# FlorShopCPE

Librería Swift para construir, validar, transformar, firmar, empaquetar y
enviar comprobantes electrónicos UBL a SUNAT.

## API del flujo CPE

El flujo público no conserva estado: el certificado, la salida y las
credenciales SUNAT se proporcionan en cada operación. Esto permite procesar
documentos de varios emisores sin crear una instancia por empresa.

```swift
let signed = try FlorShopCPE.sign(
    document,
    configuration: signingConfiguration
)

guard try FlorShopCPE.verify(signed.xml) else {
    // La firma no coincide con el XML.
    return
}

let prepared = try FlorShopCPE.write(
    signed,
    output: outputConfiguration
)

let result = try await FlorShopCPE.submit(
    document: prepared,
    credentials: sunatCredentials
)
```

El tipo producido por `sign` y `write` selecciona automáticamente la
sobrecarga correcta. Para facturas, boletas y notas, `result` es un
`SunatBillSubmissionResult`. Para resúmenes diarios y comunicaciones de baja
es un `SunatSummarySubmission` que contiene el ticket. Este último se consulta
así:

```swift
let status = try await FlorShopCPE.status(
    ticket: result.ticket,
    document: prepared,
    credentials: sunatCredentials
)
```

## Boleta

El flujo completo y compilable para crear, firmar, empaquetar, enviar y leer
la CDR de una boleta está en
[`BoletaExampleTest.swift`](Tests/FlorShopCPETests/BoletaExampleTest.swift).
El ejemplo es ejecutable con Swift Testing, pero su objetivo es documentar el
uso público de la librería, no probar unidades aisladas.

Para ejecutar realmente el envío individual contra SUNAT beta debe definirse:

- `FLORSHOP_CPE_RUN_BOLETA_EXAMPLE=true`

El ejemplo muestra directamente dónde proporcionar la ruta del archivo
PKCS#12 y su contraseña. En una aplicación real, el POS debe seleccionar esas
credenciales en tiempo de ejecución para el RUC emisor y proteger la contraseña
en su propio almacén seguro.

El envío individual de este ejemplo sirve para validar la integración en el
ambiente beta. El flujo operativo de las boletas que deben informarse mediante
Resumen Diario se modela por separado con `ResumenDiarioBoletas`.

## Ejemplos ejecutables

Cada documento soportado tiene un ejemplo completo y compilable dentro del
target de tests. Todos construyen el modelo sin funciones auxiliares, firman el
XML, crean y leen el ZIP, envían a SUNAT beta y leen la respuesta disponible.
Los documentos asíncronos muestran además el ticket y una consulta de estado:

- [`FacturaExampleTest.swift`](Tests/FlorShopCPETests/FacturaExampleTest.swift):
  `FLORSHOP_CPE_RUN_FACTURA_EXAMPLE=true`.
- [`NotaCreditoExampleTest.swift`](Tests/FlorShopCPETests/NotaCreditoExampleTest.swift):
  `FLORSHOP_CPE_RUN_NOTA_CREDITO_EXAMPLE=true`.
- [`NotaDebitoExampleTest.swift`](Tests/FlorShopCPETests/NotaDebitoExampleTest.swift):
  `FLORSHOP_CPE_RUN_NOTA_DEBITO_EXAMPLE=true`.
- [`ResumenDiarioExampleTest.swift`](Tests/FlorShopCPETests/ResumenDiarioExampleTest.swift):
  `FLORSHOP_CPE_RUN_RESUMEN_DIARIO_EXAMPLE=true`.
- [`ComunicacionBajaExampleTest.swift`](Tests/FlorShopCPETests/ComunicacionBajaExampleTest.swift):
  `FLORSHOP_CPE_RUN_COMUNICACION_BAJA_EXAMPLE=true`.

El beta público puede entregar el ticket de un documento UBL 2.0 y no tener
disponible temporalmente `getStatus`. Los ejemplos imprimen esa condición. En
producción, el POS debe conservar el ticket y programar una nueva consulta.

## Notas de crédito

La API pública incluye `NotaCredito`, `CreditNoteLine`,
`CreditNoteReasonCode` y `CreditNoteValidator`.

- Una nota que afecta una factura se firma con
  `FlorShopCPE.sign(_:configuration:)`, se escribe con
  `FlorShopCPE.write(_:output:)` y se envía con
  `FlorShopCPE.submit(document:credentials:)`.
- Una nota que afecta una boleta se convierte con
  `DailySummaryLine(lineID:creditNote:condition:)` y se incluye en un
  `ResumenDiarioBoletas`.

La librería no administra correlativos, almacenamiento, colas ni reintentos.
El POS que la consume conserva esas responsabilidades.

## Notas de débito

La API pública incluye `NotaDebito`, `DebitNoteLine`,
`DebitNoteReasonCode` y `DebitNoteValidator`. Los motivos disponibles
corresponden al catálogo 10 vigente de SUNAT.

El emisor debe proporcionar en su dirección el `addressTypeCode` de cuatro
dígitos correspondiente al establecimiento declarado ante SUNAT (por ejemplo,
`0000`). La librería lo valida, pero no lo calcula ni asigna uno por defecto.

- Una nota que afecta una factura usa serie `F...`, se firma con
  `FlorShopCPE.sign(_:configuration:)` y se envía con
  `FlorShopCPE.submit(document:credentials:)` después de que la factura
  afectada haya sido aceptada.
- Una nota que afecta una boleta usa serie `B...`, se convierte con
  `DailySummaryLine(lineID:debitNote:condition:)` y se informa como documento
  `08` dentro de un `ResumenDiarioBoletas`.

La consulta de existencia y estado del comprobante afectado requiere datos de
SUNAT/OSE; por eso no forma parte de la validación local del modelo.

## Comunicación de bajas

La API pública incluye `ComunicacionBaja`, `VoidedDocumentsIdentifier`,
`VoidedDocumentLine` y `VoidedDocumentsValidator`. Genera el documento `RA`
UBL 2.0 exigido por SUNAT. `FlorShopCPE.submit` devuelve un ticket y
`FlorShopCPE.status` permite consultar la CDR.

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
