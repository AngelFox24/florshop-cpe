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
        issueTime: IssueTime(                              // Opcional
            hour: try #require(components.hour),
            minute: try #require(components.minute),
            second: try #require(components.second)
        ),
        currency: .pen,
        supplier: Supplier(
            taxIdentifier: PartyIdentifier(
                value: "10708255195",
                documentType: .ruc
            ),
            commercialName: "NKR PRODUCTS",               // Opcional
            legalName: "NKR PROFESSIONAL PRODUCTS S.A.C.",
            address: Address(                              // Opcional
                ubigeoCode: "150130",                     // Opcional
                addressTypeCode: "0000",                  // Opcional; lo proporciona el POS
                urbanization: "URB. SAN BORJA",           // Opcional
                city: "LIMA",                             // Opcional
                department: "LIMA",                       // Opcional
                district: "SAN BORJA",                    // Opcional
                line: "CAL. PABLO USANDIZAGA 670",
                countryCode: "PE"
            ),
            contact: Contact(                              // Opcional
                telephone: "+51 999 999 999",             // Opcional
                email: "ventas@ejemplo.pe"                // Opcional
            )
        ),
        customer: Customer(
            identifier: PartyIdentifier(
                value: "20109072177",
                documentType: .ruc
            ),
            legalName: "CENCOSUD RETAIL PERU S.A.",
            address: Address(                              // Opcional
                ubigeoCode: "150103",                     // Opcional
                addressTypeCode: "0000",                  // Opcional
                urbanization: "URB. ATE",                 // Opcional
                city: "LIMA",                             // Opcional
                department: "LIMA",                       // Opcional
                district: "ATE",                          // Opcional
                line: "AV. NICOLAS AYLLON 4297",
                countryCode: "PE"
            )
        ),
        lines: [
            InvoiceLine(
                id: "1",
                quantity: Quantity(value: 15, unitCode: .unit),
                pricing: .taxed(75.07, basis: .excludingTaxes),
                item: Item(
                    description: "COLA ENTOMOLÓGICA K-GLUE X 1 LT",
                    sellerItemIdentifier: "KGLUE-1L",      // Opcional
                    commodityClassificationCode: "12161902" // Opcional
                )
            )
        ],
        additionalNotes: [                                  // Opcional
            DocumentNote(
                value: "ORDEN DE COMPRA 4301113494",
                languageLocaleID: "1002"
            )
        ],
        orderReference: "4301113494",                       // Opcional
        despatchDocumentReferences: [                       // Opcional
            DocumentReference(
                identifier: "EG07-00000280",
                documentTypeCode: "09",
                documentTypeDescription: "GUIA DE REMISION REMITENTE" // Opcional
            )
        ],
        buyerAddress: Address(                              // Opcional
            ubigeoCode: "150122",                         // Opcional
            addressTypeCode: "0000",                      // Opcional
            urbanization: "URB. MIRAFLORES",              // Opcional
            city: "LIMA",                                 // Opcional
            department: "LIMA",                           // Opcional
            district: "MIRAFLORES",                       // Opcional
            line: "CAL. AUGUSTO ANGULO 130",
            countryCode: "PE"
        ),
        paymentCondition: .credit(
            installments: [
                PaymentInstallment(
                    amount: MonetaryAmount(value: 1328.74),
                    dueDate: dueDate
                )
            ]
        ),
        allowanceCharges: []                               // Opcional; vacío porque no existe descuento/cargo real
    )
    #expect(factura.totalAmount == 1328.74)

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
