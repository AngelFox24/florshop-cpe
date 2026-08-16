import Foundation
import Testing
import FlorShopCPE

/// Ejemplo ejecutable del flujo completo de una Nota de Débito. El documento
/// afectado se referencia por su identificador y debe existir previamente en
/// el sistema del POS y en SUNAT. Solo se conecta cuando
/// `FLORSHOP_CPE_RUN_NOTA_DEBITO_EXAMPLE=true`.
@Test func completeNotaDebitoLifecycleExample() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["FLORSHOP_CPE_RUN_NOTA_DEBITO_EXAMPLE"] == "true" else {
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
    let issueTime = IssueTime(
        hour: try #require(components.hour),
        minute: try #require(components.minute),
        second: try #require(components.second)
    )
    let base = max(1, Int(now.timeIntervalSince1970) % 99_999_990)

    let notaDebito = NotaDebito(
        identifier: DocumentIdentifier(
            series: "FD01",
            number: String(base)
        ),
        issueDate: issueDate,
        issueTime: issueTime,                              // Opcional
        currency: .pen,
        supplier: Supplier(
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
        ),
        customer: Customer(
            identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
            legalName: "CLIENTE S.A.C.",
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
        // Reemplazar por el identificador de una factura ya emitida y aceptada.
        affectedDocument: AffectedDocumentIdentifier(
            series: "F001",
            number: "12345",
            type: .factura
        ),
        reasonCode: .aumentoEnElValor,
        lines: [
            DebitNoteLine(
                id: "1",
                quantity: .units(1), // Opcional
                pricing: .taxed(10.00, basis: .excludingTaxes),
                item: Item(
                    description: "AUMENTO EN EL VALOR DEL PRODUCTO",
                    sellerItemIdentifier: "P001",          // Opcional
                    commodityClassificationCode: "52141501" // Opcional
                )
            )
        ],
        additionalNotes: [                                 // Opcional
            DocumentNote("AJUSTE COORDINADO CON EL CLIENTE")
        ]
    )
    #expect(notaDebito.totalAmount == 11.80)

    let signingConfiguration = SigningConfiguration(
        credentials: .pkcs12(
            path: URL(fileURLWithPath: "/Users/angel/Downloads/LLAMA-PE-CERTIFICADO-DEMO-1070825519.pfx"),
            passwordProvider: { "Foxangel2498." }
        )
    )
    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-NotaDebitoExample-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let signedNote = try XMLSecCPESigner().sign(
        notaDebito,
        configuration: signingConfiguration
    )
    #expect(try XMLSecSignatureVerifier().verify(signedNote.xml))
    let noteDocument = try CPEDocumentWriter().write(
        signedNote,
        output: CPEOutputConfiguration(rootDirectory: temporaryDirectory)
    )
    let noteXML = try Data(contentsOf: noteDocument.signedXMLURL)
    let noteZIP = try Data(contentsOf: noteDocument.zipURL)
    print("""

    ===== NOTA DE DÉBITO FIRMADA Y EMPAQUETADA =====
    Documento afectado: \(notaDebito.affectedDocument.value)
    XML: \(noteDocument.signedXMLURL.path)
    ZIP: \(noteDocument.zipURL.path) (\(noteZIP.count) bytes)
    \(String(decoding: noteXML, as: UTF8.self))
    ===== FIN NOTA DE DÉBITO FIRMADA Y EMPAQUETADA =====

    """)
    let noteResult = try await SunatBillClient().submit(
        document: noteDocument,
        credentials: .beta(emitterRUC: notaDebito.supplier.taxIdentifier.value)
    )
    let noteCDR = try #require(noteResult.cdrArtifacts)
    let noteCDRXML = try Data(contentsOf: noteCDR.xmlURL)
    print("""

    NOTA DE DÉBITO: \(noteResult.status), código \(noteResult.responseCode)
    Descripciones: \(noteResult.descriptions)
    Observaciones: \(noteResult.observations)
    \(String(decoding: noteCDRXML, as: UTF8.self))

    """)
    #expect(noteResult.status == .accepted)
    #expect(noteResult.responseCode == "0")
    #expect(noteResult.observations.isEmpty)
    #expect(!noteResult.cdrArchive.isEmpty)
    #expect(!noteResult.cdrXML.isEmpty)
}
