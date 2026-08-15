import Foundation
import Testing
import FlorShopCPE

/// Ejemplo ejecutable del flujo completo de una boleta contra SUNAT beta.
///
/// No es una prueba unitaria: está dentro del target de tests para que Xcode
/// pueda compilarlo y ejecutarlo sin crear una aplicación adicional. Solo se
/// conecta a SUNAT cuando `FLORSHOP_CPE_RUN_BOLETA_EXAMPLE=true`.
@Test func completeBoletaLifecycleExample() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["FLORSHOP_CPE_RUN_BOLETA_EXAMPLE"] == "true" else {
        return
    }

    var limaCalendar = Calendar(identifier: .gregorian)
    limaCalendar.timeZone = try #require(TimeZone(identifier: "America/Lima"))
    let now = Date()
    let dateComponents = limaCalendar.dateComponents(
        [.year, .month, .day, .hour, .minute, .second],
        from: now
    )
    let issueDate = IssueDate(
        year: try #require(dateComponents.year),
        month: try #require(dateComponents.month),
        day: try #require(dateComponents.day)
    )
    let issueTime = IssueTime(
        hour: try #require(dateComponents.hour),
        minute: try #require(dateComponents.minute),
        second: try #require(dateComponents.second)
    )
    let correlative = String(max(1, Int(now.timeIntervalSince1970) % 99_999_999))
    let identifier = DocumentIdentifier(
        series: "BC01",
        number: correlative
    )

    let boleta = Boleta(
        identifier: identifier,
        issueDate: issueDate,
        issueTime: issueTime,                                  // Opcional
        currency: .pen,
        supplier: Supplier(
            taxIdentifier: PartyIdentifier(
                value: "10708255195",
                documentType: .ruc
            ),
            commercialName: "Electrodomésticos Cruz de Motupe", // Opcional
            legalName: "Vega Poblete Carlos Enrique",
            address: Address(                                  // Opcional
                ubigeoCode: "150130",                         // Opcional
                addressTypeCode: "0000",                      // Opcional; lo proporciona el POS
                urbanization: "URB. SAN BORJA",               // Opcional
                city: "LIMA",                                 // Opcional
                department: "LIMA",                           // Opcional
                district: "SAN BORJA",                        // Opcional
                line: "CAL. PABLO USANDIZAGA 670",
                countryCode: "PE"
            ),
            contact: Contact(                                  // Opcional
                telephone: "+51 999 999 999",                 // Opcional
                email: "ventas@ejemplo.pe"                    // Opcional
            )
        ),
        customer: Customer(
            identifier: PartyIdentifier(
                value: "46237547",
                documentType: .dni
            ),
            legalName: "Pazos Atoche Luana Karina",
            address: Address(                                  // Opcional
                ubigeoCode: "150122",                         // Opcional
                addressTypeCode: "0000",                      // Opcional
                urbanization: "URB. MIRAFLORES",              // Opcional
                city: "LIMA",                                 // Opcional
                department: "LIMA",                           // Opcional
                district: "MIRAFLORES",                       // Opcional
                line: "CAL. AUGUSTO ANGULO 130",
                countryCode: "PE"
            )
        ),
        taxTotal: TaxTotal(
            amount: MonetaryAmount(value: 266.65),
            subtotals: [
                TaxSubtotal(
                    taxableAmount: MonetaryAmount(value: 1481.35),
                    taxAmount: MonetaryAmount(value: 266.65),
                    scheme: .igv
                )
            ]
        ),
        monetaryTotal: MonetaryTotal(
            lineExtensionAmount: MonetaryAmount(value: 1481.35),
            taxInclusiveAmount: MonetaryAmount(value: 1748.00),
            allowanceTotalAmount: MonetaryAmount(              // Opcional
                value: 0.00
            ),
            chargeTotalAmount: MonetaryAmount(                 // Opcional
                value: 0.00
            ),
            prepaidAmount: MonetaryAmount(                     // Opcional
                value: 0.00
            ),
            payableAmount: MonetaryAmount(value: 1748.00)
        ),
        lines: [
            InvoiceLine(
                id: "1",
                quantity: Quantity(value: 1, unitCode: .unit),
                lineExtensionAmount: MonetaryAmount(value: 845.76),
                alternativePrices: [
                    AlternativePrice(
                        amount: MonetaryAmount(value: 998.00),
                        type: .unitPriceIncludingTaxes
                    )
                ],
                taxTotal: LineTaxTotal(
                    amount: MonetaryAmount(value: 152.24),
                    subtotals: [
                        LineTaxSubtotal(
                            taxableAmount: MonetaryAmount(value: 845.76),
                            taxAmount: MonetaryAmount(value: 152.24),
                            category: TaxCategory(
                                percent: 18,                                      // Opcional
                                exemptionReasonCode: .gravadoOperacionOnerosa,    // Opcional
                                scheme: .igv
                            )
                        )
                    ]
                ),
                item: Item(
                    description: "Refrigeradora marca AXM no frost de 200 ltrs.",
                    sellerItemIdentifier: "REF564",             // Opcional
                    commodityClassificationCode: "52141501"     // Opcional
                ),
                price: MonetaryAmount(value: 845.76),
                isFreeOfCharge: false                            // Opcional
            ),
            InvoiceLine(
                id: "2",
                quantity: Quantity(value: 1, unitCode: .unit),
                lineExtensionAmount: MonetaryAmount(value: 635.59),
                alternativePrices: [
                    AlternativePrice(
                        amount: MonetaryAmount(value: 750.00),
                        type: .unitPriceIncludingTaxes
                    )
                ],
                taxTotal: LineTaxTotal(
                    amount: MonetaryAmount(value: 114.41),
                    subtotals: [
                        LineTaxSubtotal(
                            taxableAmount: MonetaryAmount(value: 635.59),
                            taxAmount: MonetaryAmount(value: 114.41),
                            category: TaxCategory(
                                percent: 18,                                      // Opcional
                                exemptionReasonCode: .gravadoOperacionOnerosa,    // Opcional
                                scheme: .igv
                            )
                        )
                    ]
                ),
                item: Item(
                    description: "Cocina a gas GLP, marca AXM de 5 hornillas",
                    sellerItemIdentifier: "COC124",             // Opcional
                    commodityClassificationCode: "52141504"     // Opcional
                ),
                price: MonetaryAmount(value: 635.59),
                isFreeOfCharge: false                            // Opcional
            )
        ],
        additionalNotes: []                                     // Opcional
    )
    //MARK: SING
    let signingConfiguration = SigningConfiguration(
        credentials: .pkcs12(
            path: URL(fileURLWithPath: "/Users/angel/Downloads/LLAMA-PE-CERTIFICADO-DEMO-1070825519.pfx"),
            passwordProvider: { "Foxangel2498." }
        )
    )

    let signedBoleta = try XMLSecCPESigner().sign(
        boleta,
        configuration: signingConfiguration
    )
    #expect(try XMLSecSignatureVerifier().verify(signedBoleta.xml))

    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-BoletaExample-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer {
        try? fileManager.removeItem(at: temporaryDirectory)
    }
    //MARK: ZIP
    let document = try CPEDocumentWriter().write(
        signedBoleta,
        output: CPEOutputConfiguration(rootDirectory: temporaryDirectory)
    )
    let signedXMLReadFromDisk = try Data(contentsOf: document.signedXMLURL)
    let zipReadFromDisk = try Data(contentsOf: document.zipURL)

    print("""

    ===== BOLETA FIRMADA Y EMPAQUETADA =====
    XML: \(document.signedXMLURL.path)
    ZIP: \(document.zipURL.path)
    Tamaño ZIP: \(zipReadFromDisk.count) bytes
    \(String(decoding: signedXMLReadFromDisk, as: UTF8.self))
    ===== FIN BOLETA FIRMADA Y EMPAQUETADA =====

    """)

    let result = try await SunatBillClient().submit(
        document: document,
        credentials: .beta(emitterRUC: boleta.supplier.taxIdentifier.value)
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
