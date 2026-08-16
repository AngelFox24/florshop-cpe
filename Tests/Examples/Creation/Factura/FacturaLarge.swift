import Foundation
import Testing
import FlorShopCPE

/// Ejemplo ejecutable del flujo completo de una factura contra SUNAT beta.
///
/// No es una prueba unitaria. Solo se conecta a SUNAT cuando
/// `FLORSHOP_CPE_RUN_FACTURA_EXAMPLE=true`.
@Test func completeFacturaLifecycleExample() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["FLORSHOP_CPE_RUN_FACTURA_EXAMPLE"] == "true" else {
        return
    }

    var limaCalendar = Calendar(identifier: .gregorian)
    limaCalendar.timeZone = try #require(TimeZone(identifier: "America/Lima"))
    let now = Date()
    let components = limaCalendar.dateComponents(
        [.year, .month, .day, .hour, .minute, .second],
        from: now
    )
    let issueDate = IssueDate(
        year: try #require(components.year),
        month: try #require(components.month),
        day: try #require(components.day)
    )
    let dueDateValue = try #require(limaCalendar.date(byAdding: .day, value: 15, to: now))
    let dueDateComponents = limaCalendar.dateComponents([.year, .month, .day], from: dueDateValue)
    let dueDate = IssueDate(
        year: try #require(dueDateComponents.year),
        month: try #require(dueDateComponents.month),
        day: try #require(dueDateComponents.day)
    )
    let correlative = String(max(1, Int(now.timeIntervalSince1970) % 99_999_999))

    let factura = Factura(
        identifier: DocumentIdentifier(
            series: "F001",
            number: correlative
        ),
        issueDate: issueDate,
        issueTime: IssueTime(                              // Por defecto: nil
            hour: try #require(components.hour),
            minute: try #require(components.minute),
            second: try #require(components.second)        // Por defecto: 0
        ),
        currency: .pen,
        supplier: Supplier(
            taxIdentifier: PartyIdentifier(
                value: "10708255195",
                documentType: .ruc
            ),
            commercialName: "NKR PRODUCTS",               // Por defecto: nil
            legalName: "NKR PROFESSIONAL PRODUCTS S.A.C.",
            address: Address(                              // Por defecto: nil
                ubigeoCode: "150130",                     // Por defecto: nil
                addressTypeCode: "0000",                  // Por defecto: nil; lo proporciona el POS
                urbanization: "URB. SAN BORJA",           // Por defecto: nil
                city: "LIMA",                             // Por defecto: nil
                department: "LIMA",                       // Por defecto: nil
                district: "SAN BORJA",                    // Por defecto: nil
                line: "CAL. PABLO USANDIZAGA 670",
                countryCode: "PE"                         // Por defecto: "PE"
            ),
            contact: Contact(                              // Por defecto: nil
                telephone: "+51 999 999 999",             // Por defecto: nil
                email: "ventas@ejemplo.pe"                // Por defecto: nil
            )
        ),
        customer: Customer(
            identifier: PartyIdentifier(
                value: "20109072177",
                documentType: .ruc
            ),
            legalName: "CENCOSUD RETAIL PERU S.A.",
            address: Address(                              // Por defecto: nil
                ubigeoCode: "150103",                     // Por defecto: nil
                addressTypeCode: "0000",                  // Por defecto: nil
                urbanization: "URB. ATE",                 // Por defecto: nil
                city: "LIMA",                             // Por defecto: nil
                department: "LIMA",                       // Por defecto: nil
                district: "ATE",                          // Por defecto: nil
                line: "AV. NICOLAS AYLLON 4297",
                countryCode: "PE"                         // Por defecto: "PE"
            )
        ),
        lines: [
            // Precio gravado sin IGV. La tasa se escribe explícitamente aunque
            // 18 sea el valor predeterminado, para mostrar la forma completa.
            InvoiceLine(
                quantity: .units(15),
                pricing: .taxed(
                    75.07,
                    rate: 18,                              // Por defecto: 18
                    basis: .excludingTaxes
                ),
                item: Item(
                    description: "COLA ENTOMOLÓGICA K-GLUE X 1 LT",
                    sellerItemIdentifier: "KGLUE-1L",     // Por defecto: nil
                    commodityClassificationCode: "12161902" // Por defecto: nil
                )
            ),
            // Cantidad fraccionaria de kilogramos y precio gravado con IGV.
            InvoiceLine(
                quantity: .kilograms(34.521234),
                pricing: .taxed(
                    2.95,
                    rate: 18,                              // Por defecto: 18
                    basis: .includingTaxes                 // Por defecto: .includingTaxes
                ),
                item: Item(
                    description: "Café tostado vendido por kilogramo",
                    sellerItemIdentifier: "CAF-KG",       // Por defecto: nil
                    commodityClassificationCode: nil       // Por defecto: nil
                )
            ),
            // Operación exonerada, expresada en gramos con decimales.
            InvoiceLine(
                quantity: .grams(250.125),
                pricing: .exempt(0.08),
                item: Item(
                    description: "Producto exonerado vendido por gramos",
                    sellerItemIdentifier: nil,             // Por defecto: nil
                    commodityClassificationCode: nil       // Por defecto: nil
                )
            ),
            // Operación inafecta medida en litros.
            InvoiceLine(
                quantity: .liters(1.75),
                pricing: .unaffected(12.40),
                item: Item(
                    description: "Producto inafecto vendido por litros",
                    sellerItemIdentifier: "INA-LT",       // Por defecto: nil
                    commodityClassificationCode: nil       // Por defecto: nil
                )
            ),
            // Entrega gratuita: el importe es un valor referencial y no forma
            // parte del monto pendiente de pago de la factura.
            InvoiceLine(
                quantity: .meters(2.345678),
                pricing: .free(referenceValue: 4.80),
                item: Item(
                    description: "Muestra gratuita entregada por metros",
                    sellerItemIdentifier: nil,             // Por defecto: nil
                    commodityClassificationCode: nil       // Por defecto: nil
                )
            ),
            // La forma corta usa los dos valores predeterminados de `.taxed`:
            // tasa 18 y precio que incluye impuestos.
            InvoiceLine(
                quantity: .serviceUnits(1.5),
                pricing: .taxed(59.00),                    // Por defecto: rate 18 y .includingTaxes
                item: Item(
                    description: "Servicio cobrado por unidad de servicio",
                    sellerItemIdentifier: "SRV-001",      // Por defecto: nil
                    commodityClassificationCode: nil       // Por defecto: nil
                )
            )
        ],
        additionalNotes: [                                // Por defecto: []
            DocumentNote("ORDEN DE COMPRA 4301113494")
        ],
        orderReference: "4301113494",                    // Por defecto: nil
        despatchDocumentReferences: [                     // Por defecto: []
            DocumentReference(
                identifier: "EG07-00000280",
                documentTypeCode: "09",
                documentTypeDescription: "GUIA DE REMISION REMITENTE" // Por defecto: nil
            )
        ],
        buyerAddress: Address(                            // Por defecto: nil
            ubigeoCode: "150122",                       // Por defecto: nil
            addressTypeCode: "0000",                    // Por defecto: nil
            urbanization: "URB. MIRAFLORES",            // Por defecto: nil
            city: "LIMA",                               // Por defecto: nil
            department: "LIMA",                         // Por defecto: nil
            district: "MIRAFLORES",                     // Por defecto: nil
            line: "CAL. AUGUSTO ANGULO 130",
            countryCode: "PE"                           // Por defecto: "PE"
        ),
        // `paymentCondition` es obligatorio. Esta factura usa crédito; la API
        // también permite `.cash`, mostrado más abajo sin enviarlo a SUNAT.
        paymentCondition: .credit(
            installments: [
                PaymentInstallment(
                    amount: MonetaryAmount(value: 1560.78),
                    dueDate: dueDate
                )
            ]
        ),
        allowanceCharges: [],                            // Por defecto: []
        payableRoundingAmount: nil                       // Por defecto: nil
    )

    // Todos los importes derivados están disponibles antes de firmar.
    #expect(factura.netAmount == 1329.06)
    #expect(factura.taxAmount == 231.72)
    #expect(factura.totalAmount == 1560.78)
    #expect(factura.lines[1].lineExtensionAmount.value == 86.30)
    #expect(factura.lines[4].isFreeOfCharge == true)
    #expect(factura.lines[4].lineExtensionAmount.value == 11.26)

    // Otras variantes de términos comerciales. Se construyen por separado
    // porque no corresponden a la factura al crédito enviada en este ejemplo.
    let cashPaymentExample: PaymentCondition = .cash
    #expect(cashPaymentExample.pendingAmount == nil)

    let fixedDiscountExample = AllowanceCharge(
        isCharge: false,
        reasonCode: nil,                                   // Por defecto: nil
        amount: 10.00
    )
    let percentageChargeExample = AllowanceCharge(
        isCharge: true,
        reasonCode: nil,                                   // Por defecto: nil
        multiplierFactor: 0.05,
        baseAmount: 100.00
    )
    #expect(fixedDiscountExample.amount.value == 10.00)
    #expect(percentageChargeExample.amount.value == 5.00)

    let signingConfiguration = SigningConfiguration(
        credentials: .pkcs12(
            path: URL(fileURLWithPath: "/Users/angel/Downloads/LLAMA-PE-CERTIFICADO-DEMO-1070825519.pfx"),
            passwordProvider: { "Foxangel2498." }
        )
    )
    let signedFactura = try XMLSecCPESigner().sign(
        factura,
        configuration: signingConfiguration
    )
    #expect(try XMLSecSignatureVerifier().verify(signedFactura.xml))

    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-FacturaExample-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let document = try CPEDocumentWriter().write(
        signedFactura,
        output: CPEOutputConfiguration(rootDirectory: temporaryDirectory)
    )
    let signedXMLReadFromDisk = try Data(contentsOf: document.signedXMLURL)
    let zipReadFromDisk = try Data(contentsOf: document.zipURL)
    print("""

    ===== FACTURA FIRMADA Y EMPAQUETADA =====
    XML: \(document.signedXMLURL.path)
    ZIP: \(document.zipURL.path)
    Tamaño ZIP: \(zipReadFromDisk.count) bytes
    \(String(decoding: signedXMLReadFromDisk, as: UTF8.self))
    ===== FIN FACTURA FIRMADA Y EMPAQUETADA =====

    """)

    let result = try await SunatBillClient().submit(
        document: document,
        credentials: .beta(emitterRUC: factura.supplier.taxIdentifier.value)
    )
    let cdrArtifacts = try #require(result.cdrArtifacts)
    let cdrXMLReadFromDisk = try Data(contentsOf: cdrArtifacts.xmlURL)
    print("""

    ===== RESPUESTA SUNAT BETA =====
    Estado: \(result.status)
    Código: \(result.responseCode)
    Descripciones: \(result.descriptions)
    Observaciones: \(result.observations)
    CDR ZIP: \(cdrArtifacts.archiveURL.path)
    CDR XML: \(cdrArtifacts.xmlURL.path)
    \(String(decoding: cdrXMLReadFromDisk, as: UTF8.self))
    ===== FIN RESPUESTA SUNAT BETA =====

    """)

    #expect(result.status == .accepted)
    #expect(result.responseCode == "0")
    #expect(result.observations.isEmpty)
    #expect(!result.cdrArchive.isEmpty)
    #expect(!result.cdrXML.isEmpty)
}
