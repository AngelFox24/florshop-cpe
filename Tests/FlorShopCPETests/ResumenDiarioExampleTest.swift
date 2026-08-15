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
    let correlative = String(max(1, Int(now.timeIntervalSince1970) % 99_999_999))
    let sequence = max(1, Int(now.timeIntervalSince1970) % 99_999)

    let supplier = Supplier(
        taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
        commercialName: "ELECTRODOMÉSTICOS CRUZ DE MOTUPE", // Opcional
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
    )
    let boleta = Boleta(
        identifier: DocumentIdentifier(series: "BC01", number: correlative),
        issueDate: issueDate,
        currency: .pen,
        supplier: supplier,
        customer: Customer(
            identifier: PartyIdentifier(value: "46237547", documentType: .dni),
            legalName: "Pazos Atoche Luana Karina"
        ),
        lines: [InvoiceLine(
            id: "1",
            quantity: Quantity(value: 1, unitCode: .unit),
            pricing: .taxed(100, basis: .excludingTaxes),
            item: Item(description: "PRODUCTO")
        )]
    )
    let resumen = try ResumenDiarioBoletas(
        identifier: DailySummaryIdentifier(
            date: issueDate,
            sequence: sequence
        ),
        issueDate: issueDate,
        boletas: [boleta]
    )

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
