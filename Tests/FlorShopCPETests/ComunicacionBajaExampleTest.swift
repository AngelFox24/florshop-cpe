import Foundation
import Testing
import FlorShopCPE

/// Ejemplo ejecutable de una Comunicación de Baja mediante el flujo asíncrono
/// `sendSummary` / `getStatus`. Los comprobantes referenciados deben existir
/// previamente en el sistema del POS y en SUNAT. Solo se conecta cuando
/// `FLORSHOP_CPE_RUN_COMUNICACION_BAJA_EXAMPLE=true`.
@Test func completeComunicacionBajaLifecycleExample() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["FLORSHOP_CPE_RUN_COMUNICACION_BAJA_EXAMPLE"] == "true" else {
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
    let sequence = max(1, Int(now.timeIntervalSince1970) % 99_999)

    let supplier = Supplier(
        taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
        commercialName: "EMISOR",                         // Opcional
        legalName: "EMISOR S.A.C.",
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
    let comunicacion = try ComunicacionBaja(
        identifier: VoidedDocumentsIdentifier(
            date: issueDate,
            sequence: sequence
        ),
        issueDate: issueDate,
        referenceDate: issueDate,
        supplier: supplier,
        lines: [
            VoidedDocumentLine(
                lineID: 1,
                documentType: .factura,
                // Reemplazar por un comprobante existente que pueda darse de baja.
                documentIdentifier: DocumentIdentifier(
                    series: "F001",
                    number: "12345"
                ),
                reason: "DOCUMENTO NO OTORGADO"
            )
        ]
    )

    let signingConfiguration = SigningConfiguration(
        credentials: .pkcs12(
            path: URL(fileURLWithPath: "/Users/angel/Downloads/LLAMA-PE-CERTIFICADO-DEMO-1070825519.pfx"),
            passwordProvider: { "Foxangel2498." }
        )
    )
    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-ComunicacionBajaExample-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let signedCommunication = try XMLSecCPESigner().sign(
        comunicacion,
        configuration: signingConfiguration
    )
    #expect(try XMLSecSignatureVerifier().verify(signedCommunication.xml))
    let communicationDocument = try CPEDocumentWriter().write(
        signedCommunication,
        output: CPEOutputConfiguration(rootDirectory: temporaryDirectory)
    )
    let communicationXML = try Data(contentsOf: communicationDocument.signedXMLURL)
    let communicationZIP = try Data(contentsOf: communicationDocument.zipURL)
    print("""

    ===== COMUNICACIÓN DE BAJA FIRMADA Y EMPAQUETADA =====
    XML: \(communicationDocument.signedXMLURL.path)
    ZIP: \(communicationDocument.zipURL.path) (\(communicationZIP.count) bytes)
    \(String(decoding: communicationXML, as: UTF8.self))
    ===== FIN COMUNICACIÓN DE BAJA FIRMADA Y EMPAQUETADA =====

    """)

    let credentials = SunatCredentials.beta(emitterRUC: supplier.taxIdentifier.value)
    let client = SunatSummaryClient()
    let submission = try await client.submit(
        document: communicationDocument,
        credentials: credentials
    )
    print("SUNAT BETA recibió la comunicación. Ticket: \(submission.ticket)")
    #expect(!submission.ticket.isEmpty)

    // Consulta única de ejemplo. El POS conserva el ticket y programa los
    // reintentos cuando SUNAT responde `.processing` o existe indisponibilidad.
    do {
        let processingResult = try await client.status(
            ticket: submission.ticket,
            document: communicationDocument,
            credentials: credentials
        )
        switch processingResult {
        case .processing:
            print("SUNAT todavía está procesando la Comunicación de Baja.")
        case let .completed(result):
            let cdr = try #require(result.cdrArtifacts)
            let cdrXML = try Data(contentsOf: cdr.xmlURL)
            print("""

            BAJA COMPLETADA: \(result.status), código \(result.responseCode)
            Descripciones: \(result.descriptions)
            Observaciones: \(result.observations)
            \(String(decoding: cdrXML, as: UTF8.self))

            """)
        case let .failed(result):
            let cdrXML = result.cdrArtifacts.flatMap { try? Data(contentsOf: $0.xmlURL) }
            print("""

            BAJA RECHAZADA: código \(result.responseCode)
            Descripciones: \(result.descriptions)
            Observaciones: \(result.observations)
            \(cdrXML.map { String(decoding: $0, as: UTF8.self) } ?? "CDR no disponible")

            """)
            Issue.record("SUNAT rechazó la Comunicación de Baja: \(result.responseCode)")
        }
    } catch {
        // El beta público no siempre ofrece getStatus para documentos UBL 2.0.
        // En producción el POS debe conservar el ticket y reintentar después.
        print("No fue posible consultar el ticket en SUNAT beta: \(error)")
    }
}
