import Foundation
import Testing
import FlorShopCPE

/// Ejemplo ejecutable del flujo `sendSummary` / `getStatus` para un Resumen
/// Diario de boletas. Solo se conecta cuando
/// `FLORSHOP_CPE_RUN_RESUMEN_DIARIO_EXAMPLE=true`.
@Test func completeResumenDiarioLifecycleExample() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["FLORSHOP_CPE_RUN_RESUMEN_DIARIO_EXAMPLE"] == "true" else {
        return
    }

    var limaCalendar = Calendar(identifier: .gregorian)
    limaCalendar.timeZone = try #require(TimeZone(identifier: "America/Lima"))
    let now = Date()
    let components = limaCalendar.dateComponents(
        [.year, .month, .day],
        from: now
    )
    let issueDate = IssueDate(
        year: try #require(components.year),
        month: try #require(components.month),
        day: try #require(components.day)
    )
    let base = max(1, Int(now.timeIntervalSince1970) % 99_999_990)
    let sequence = max(1, Int(now.timeIntervalSince1970) % 99_997)

    let supplier = Supplier(
        taxIdentifier: PartyIdentifier(
            value: "10708255195",
            documentType: .ruc
        ),
        commercialName: "ELECTRODOMÉSTICOS CRUZ DE MOTUPE", // Por defecto: nil
        legalName: "Vega Poblete Carlos Enrique",
        address: Address(                                      // Por defecto: nil
            ubigeoCode: "150130",                             // Por defecto: nil
            addressTypeCode: "0000",                          // Por defecto: nil; lo proporciona el POS
            urbanization: "URB. SAN BORJA",                   // Por defecto: nil
            city: "LIMA",                                     // Por defecto: nil
            department: "LIMA",                               // Por defecto: nil
            district: "SAN BORJA",                            // Por defecto: nil
            line: "CAL. PABLO USANDIZAGA 670",
            countryCode: "PE"                                 // Por defecto: "PE"
        ),
        contact: Contact(                                      // Por defecto: nil
            telephone: "+51 999 999 999",                     // Por defecto: nil
            email: "ventas@ejemplo.pe"                        // Por defecto: nil
        )
    )

    let customer = Customer(
        identifier: PartyIdentifier(
            value: "46237547",
            documentType: .dni
        ),
        legalName: "Pazos Atoche Luana Karina",
        address: nil                                           // Por defecto: nil
    )

    // Esta boleta reúne los tratamientos que el resumen sabe clasificar
    // automáticamente según el catálogo 11 de SUNAT.
    let boleta = Boleta(
        identifier: DocumentIdentifier(
            series: "BC01",
            number: String(base)
        ),
        issueDate: issueDate,
        issueTime: nil,                                        // Por defecto: nil
        currency: .pen,
        supplier: supplier,
        customer: customer,
        lines: [
            InvoiceLine(
                id: "1",
                quantity: .units(1),
                pricing: .taxed(
                    118.00,
                    rate: 18,                                  // Por defecto: 18
                    basis: .includingTaxes                     // Por defecto: .includingTaxes
                ),
                item: Item(
                    description: "Producto gravado",
                    sellerItemIdentifier: "GRAV-001",         // Por defecto: nil
                    commodityClassificationCode: nil           // Por defecto: nil
                )
            ),
            InvoiceLine(
                id: "2",
                quantity: .kilograms(2.345678),
                pricing: .exempt(12.50),
                item: Item(
                    description: "Producto exonerado por kilogramo",
                    sellerItemIdentifier: nil,                 // Por defecto: nil
                    commodityClassificationCode: nil           // Por defecto: nil
                )
            ),
            InvoiceLine(
                id: "3",
                quantity: .liters(1.75),
                pricing: .unaffected(8.40),
                item: Item(
                    description: "Producto inafecto por litro",
                    sellerItemIdentifier: "INA-LT",           // Por defecto: nil
                    commodityClassificationCode: nil           // Por defecto: nil
                )
            ),
            InvoiceLine(
                id: "4",
                quantity: .meters(3.125),
                pricing: .free(referenceValue: 4.80),
                item: Item(
                    description: "Muestra gratuita por metro",
                    sellerItemIdentifier: nil,                 // Por defecto: nil
                    commodityClassificationCode: nil           // Por defecto: nil
                )
            )
        ],
        payableRoundingAmount: nil,                             // Por defecto: nil
        additionalNotes: []                                    // Por defecto: []
    )

    // Segunda boleta para mostrar que el inicializador de conveniencia acepta
    // varias boletas y asigna lineID 1, 2, 3... automáticamente.
    let secondBoleta = Boleta(
        identifier: DocumentIdentifier(
            series: "BC01",
            number: String(base + 1)
        ),
        issueDate: issueDate,
        issueTime: nil,                                        // Por defecto: nil
        currency: .pen,
        supplier: supplier,
        customer: customer,
        lines: [
            InvoiceLine(
                id: "1",
                quantity: .serviceUnits(1.5),
                pricing: .taxed(59.00),                        // Por defecto: rate 18 y .includingTaxes
                item: Item(
                    description: "Servicio gravado",
                    sellerItemIdentifier: "SRV-001",          // Por defecto: nil
                    commodityClassificationCode: nil           // Por defecto: nil
                )
            )
        ],
        payableRoundingAmount: nil,                             // Por defecto: nil
        additionalNotes: []                                    // Por defecto: []
    )

    // Inicializador de conveniencia: deriva referenceDate, supplier, lineID,
    // ventas y tributos directamente desde las boletas.
    let convenienceSummaryExample = try ResumenDiarioBoletas(
        identifier: DailySummaryIdentifier(
            date: issueDate,
            sequence: sequence
        ),
        issueDate: issueDate,
        boletas: [boleta, secondBoleta]
    )
    #expect(convenienceSummaryExample.referenceDate == issueDate)
    #expect(convenienceSummaryExample.supplier == supplier)
    #expect(convenienceSummaryExample.lines.map(\.lineID) == [1, 2])
    #expect(convenienceSummaryExample.lines.allSatisfy { $0.condition == .add })

    // Las notas vinculadas a boletas también se informan mediante el Resumen
    // Diario como documentos 07 y 08. Sus datos monetarios se derivan de las
    // notas; el usuario no introduce manualmente los totales del resumen.
    let creditNote = NotaCredito(
        identifier: DocumentIdentifier(
            series: "BC02",
            number: String(base + 2)
        ),
        issueDate: issueDate,
        issueTime: nil,                                        // Por defecto: nil
        currency: .pen,
        supplier: supplier,
        customer: customer,
        affectedDocument: AffectedDocumentIdentifier(
            series: boleta.identifier.series,
            number: boleta.identifier.number,
            type: .boleta
        ),
        reasonCode: .devolucionPorItem,
        reasonDescription: nil,                                // Por defecto: descripción de .devolucionPorItem
        lines: [
            CreditNoteLine(
                id: "1",
                quantity: .units(1),
                pricing: .taxed(10.00, basis: .excludingTaxes),
                item: Item(
                    description: "Devolución parcial del producto gravado",
                    sellerItemIdentifier: nil,                 // Por defecto: nil
                    commodityClassificationCode: nil           // Por defecto: nil
                )
            )
        ],
        payableRoundingAmount: nil,                             // Por defecto: nil
        additionalNotes: []                                    // Por defecto: []
    )

    let debitNote = NotaDebito(
        identifier: DocumentIdentifier(
            series: "BD01",
            number: String(base + 3)
        ),
        issueDate: issueDate,
        issueTime: nil,                                        // Por defecto: nil
        currency: .pen,
        supplier: supplier,
        customer: customer,
        affectedDocument: AffectedDocumentIdentifier(
            series: boleta.identifier.series,
            number: boleta.identifier.number,
            type: .boleta
        ),
        reasonCode: .aumentoEnElValor,
        reasonDescription: nil,                                // Por defecto: descripción de .aumentoEnElValor
        lines: [
            DebitNoteLine(
                id: "1",
                quantity: .units(1),
                pricing: .taxed(5.00, basis: .excludingTaxes),
                item: Item(
                    description: "Aumento en el valor del producto",
                    sellerItemIdentifier: nil,                 // Por defecto: nil
                    commodityClassificationCode: nil           // Por defecto: nil
                )
            )
        ],
        payableRoundingAmount: nil,                             // Por defecto: nil
        additionalNotes: []                                    // Por defecto: []
    )

    // Inicializador avanzado: permite combinar boletas, notas de crédito y
    // notas de débito, además de elegir la condición de cada documento. La
    // librería asigna lineID 1, 2, 3... según el orden de `entries`.
    let resumen = try ResumenDiarioBoletas(
        identifier: DailySummaryIdentifier(
            date: issueDate,
            sequence: sequence
        ),
        issueDate: issueDate,
        referenceDate: issueDate,
        supplier: supplier,
        entries: [
            .boleta(
                boleta,
                condition: .add                              // Por defecto: .add
            ),
            .boleta(
                secondBoleta,
                condition: .add                              // Por defecto: .add
            ),
            .creditNote(
                creditNote,
                condition: .add                              // Por defecto: .add
            ),
            .debitNote(
                debitNote,
                condition: .add                              // Por defecto: .add
            )
        ]
    )
    #expect(resumen.lines.map(\.documentType) == [
        .boleta,
        .boleta,
        .notaDeCredito,
        .notaDeDebito
    ])
    #expect(resumen.lines[2].affectedDocument == boleta.identifier)
    #expect(resumen.lines[3].affectedDocument == boleta.identifier)

    // `.modify` y `.void` se construyen en resúmenes separados porque SUNAT
    // no permite repetir el mismo comprobante dentro de un único resumen.
    let modifiedSummaryExample = try ResumenDiarioBoletas(
        identifier: DailySummaryIdentifier(
            date: issueDate,
            sequence: sequence + 1
        ),
        issueDate: issueDate,
        referenceDate: issueDate,
        supplier: supplier,
        entries: [
            .boleta(
                boleta,
                condition: .modify
            )
        ]
    )
    let voidedSummaryExample = try ResumenDiarioBoletas(
        identifier: DailySummaryIdentifier(
            date: issueDate,
            sequence: sequence + 2
        ),
        issueDate: issueDate,
        referenceDate: issueDate,
        supplier: supplier,
        entries: [
            .boleta(
                boleta,
                condition: .void
            )
        ]
    )
    #expect(modifiedSummaryExample.lines[0].condition == .modify)
    #expect(voidedSummaryExample.lines[0].condition == .void)

    let signingConfiguration = SigningConfiguration(
        credentials: .pkcs12(
            path: URL(fileURLWithPath: "/Users/angel/Downloads/LLAMA-PE-CERTIFICADO-DEMO-1070825519.pfx"),
            passwordProvider: { "Foxangel2498." }
        )
    )
    let signedSummary = try XMLSecCPESigner().sign(
        resumen,
        configuration: signingConfiguration
    )
    #expect(try XMLSecSignatureVerifier().verify(signedSummary.xml))

    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-ResumenDiarioExample-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let document = try CPEDocumentWriter().write(
        signedSummary,
        output: CPEOutputConfiguration(rootDirectory: temporaryDirectory)
    )
    let xmlReadFromDisk = try Data(contentsOf: document.signedXMLURL)
    let zipReadFromDisk = try Data(contentsOf: document.zipURL)
    print("""

    ===== RESUMEN DIARIO FIRMADO Y EMPAQUETADO =====
    XML: \(document.signedXMLURL.path)
    ZIP: \(document.zipURL.path) (\(zipReadFromDisk.count) bytes)
    \(String(decoding: xmlReadFromDisk, as: UTF8.self))
    ===== FIN RESUMEN DIARIO =====

    """)

    let credentials = SunatCredentials.beta(
        emitterRUC: resumen.supplier.taxIdentifier.value
    )
    let client = SunatSummaryClient()
    let submission = try await client.submit(
        document: document,
        credentials: credentials
    )
    print("SUNAT BETA recibió el resumen. Ticket: \(submission.ticket)")
    #expect(!submission.ticket.isEmpty)

    // Consulta única de ejemplo. Si devuelve `.processing`, el POS persiste
    // el ticket y decide cuándo volver a consultar.
    do {
        let processingResult = try await client.status(
            ticket: submission.ticket,
            document: document,
            credentials: credentials
        )
        switch processingResult {
        case .processing:
            print("SUNAT todavía está procesando el resumen diario.")
        case let .completed(result):
            let cdr = try #require(result.cdrArtifacts)
            let cdrXML = try Data(contentsOf: cdr.xmlURL)
            print("""

            RESUMEN COMPLETADO: \(result.status), código \(result.responseCode)
            Descripciones: \(result.descriptions)
            Observaciones: \(result.observations)
            \(String(decoding: cdrXML, as: UTF8.self))

            """)
        case let .failed(result):
            let cdrXML = result.cdrArtifacts.flatMap { try? Data(contentsOf: $0.xmlURL) }
            print("""

            RESUMEN RECHAZADO: código \(result.responseCode)
            Descripciones: \(result.descriptions)
            Observaciones: \(result.observations)
            \(cdrXML.map { String(decoding: $0, as: UTF8.self) } ?? "CDR no disponible")

            """)
            Issue.record("SUNAT rechazó el resumen diario: \(result.responseCode)")
        }
    } catch {
        // El beta público entrega tickets, pero su getStatus para documentos
        // UBL 2.0 no siempre está disponible. En producción este error debe
        // persistirse junto con el ticket para que el POS reprograme la consulta.
        print("No fue posible consultar el ticket en SUNAT beta: \(error)")
    }
}
