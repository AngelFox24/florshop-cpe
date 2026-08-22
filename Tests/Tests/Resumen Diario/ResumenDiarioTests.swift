import Foundation
import Testing
import ZIPFoundation
@testable import FlorShopCPE

@Test func dailySummaryDocumentTypeCannotRepresentFactura() {
    #expect(DailySummaryDocumentType(rawValue: "01") == nil)
}

@Test func dailySummaryIsBuiltFromBoletasWithoutProductLines() throws {
    let summary = try makeDailySummary(boletas: [makeSummaryBoleta(number: "1"), makeSummaryBoleta(number: "2")])

    #expect(summary.identifier.value == "RC-20260802-00001")
    #expect(summary.referenceDate == IssueDate(year: 2026, month: 8, day: 2))
    #expect(summary.lines.count == 2)
    #expect(summary.lines[0].documentIdentifier.value == "B001-1")
    #expect(summary.lines[0].condition == .add)
    #expect(summary.lines[0].sales == [
        DailySummarySale(type: .taxable, amount: MonetaryAmount(value: 100)),
        DailySummarySale(type: .exempt, amount: MonetaryAmount(value: 0)),
        DailySummarySale(type: .unaffected, amount: MonetaryAmount(value: 0))
    ])
    #expect(summary.lines[0].taxes == [
        DailySummaryTax(amount: MonetaryAmount(value: 18), percent: 18, scheme: .igv)
    ])
}

@Test func dailySummaryDerivesDocumentDateWhenGeneratedLater() throws {
    let documentDate = IssueDate(year: 2026, month: 8, day: 2)
    let generationDate = IssueDate(year: 2026, month: 8, day: 5)
    let boleta = makeSummaryBoleta(number: "1", issueDate: documentDate)

    let summary = try ResumenDiarioBoletas(
        sequence: 7,
        issueDate: generationDate,
        entries: [.boleta(boleta)]
    )

    #expect(summary.identifier.date == documentDate)
    #expect(summary.identifier.value == "RC-20260802-00007")
    #expect(summary.referenceDate == documentDate)
    #expect(summary.issueDate == generationDate)
}

@Test func dailySummaryRejectsGenerationBeforeDocumentDate() {
    let boleta = makeSummaryBoleta(
        number: "1",
        issueDate: IssueDate(year: 2026, month: 8, day: 5)
    )

    #expect(throws: DailySummaryValidationError.generationDateBeforeReferenceDate) {
        _ = try ResumenDiarioBoletas(
            sequence: 1,
            issueDate: IssueDate(year: 2026, month: 8, day: 2),
            entries: [.boleta(boleta)]
        )
    }
}

@Test func dailySummaryRejectsBoletasFromDifferentDates() {
    let boletas = [
        makeSummaryBoleta(number: "1"),
        makeSummaryBoleta(number: "2", issueDate: IssueDate(year: 2026, month: 8, day: 1))
    ]

    #expect(throws: DailySummaryValidationError.inconsistentReferenceDate) {
        _ = try makeDailySummary(boletas: boletas)
    }
}

@Test func dailySummaryRejectsForeignCurrencySourceDocuments() {
    let boleta = makeSummaryBoleta(number: "200", currency: .usd)

    #expect(throws: DailySummaryValidationError.sourceDocumentMustUsePEN) {
        _ = try DailySummaryLine(lineID: 1, boleta: boleta)
    }
}

@Test func dailySummaryRejectsDuplicatedBoletas() {
    let boleta = makeSummaryBoleta(number: "1")

    #expect(throws: DailySummaryValidationError.duplicatedDocument("B001-1")) {
        _ = try makeDailySummary(boletas: [boleta, boleta])
    }
}

@Test func dailySummaryClassifiesFreeOperationsFromBoletaTaxData() throws {
    let base = makeSummaryBoleta(
        number: "3",
        pricing: .free(referenceValue: 4.80)
    )
    let freeLine = try DailySummaryLine(lineID: 1, boleta: base)
    let summary = try ResumenDiarioBoletas(
        identifier: DailySummaryIdentifier(date: base.issueDate, sequence: 1),
        issueDate: base.issueDate,
        referenceDate: base.issueDate,
        supplier: base.supplier,
        lines: [freeLine]
    )
    let xml = try DailySummaryXMLTransformer().transform(summary)

    #expect(xml.contains("<cbc:InstructionID>08</cbc:InstructionID>"))
    #expect(xml.contains("<cbc:ID>9996</cbc:ID>"))
    #expect(xml.contains("<cbc:Percent>18</cbc:Percent>"))
}

@Test func invoiceTransformerAutomaticallyWritesTheFreeTransferLegend() throws {
    let boleta = makeSummaryBoleta(
        number: "4",
        pricing: .free(referenceValue: 4.80)
    )
    let xml = try UBLInvoiceXMLTransformer().transform(boleta)

    #expect(xml.contains(
        "<cbc:Note languageLocaleID=\"1002\">TRANSFERENCIA GRATUITA DE UN BIEN Y/O SERVICIO PRESTADO GRATUITAMENTE</cbc:Note>"
    ))
}

@Test func dailySummaryTransformerGeneratesSummaryDocumentsUBL20() throws {
    let xml = try DailySummaryXMLTransformer().transform(
        makeDailySummary(boletas: [makeSummaryBoleta(number: "1"), makeSummaryBoleta(number: "2")])
    )

    #expect(xml.contains("<SummaryDocuments"))
    #expect(xml.contains("xmlns=\"urn:sunat:names:specification:ubl:peru:schema:xsd:SummaryDocuments-1\""))
    #expect(xml.contains("xmlns:sac=\"urn:sunat:names:specification:ubl:peru:schema:xsd:SunatAggregateComponents-1\""))
    #expect(xml.contains("<cbc:UBLVersionID>2.0</cbc:UBLVersionID>"))
    #expect(xml.contains("<cbc:CustomizationID>1.1</cbc:CustomizationID>"))
    #expect(xml.contains("<cbc:ID>RC-20260802-00001</cbc:ID>"))
    #expect(xml.contains("<cbc:ReferenceDate>2026-08-02</cbc:ReferenceDate>"))
    #expect(xml.components(separatedBy: "<sac:SummaryDocumentsLine>").count - 1 == 2)
    #expect(xml.contains("<cbc:DocumentTypeCode>03</cbc:DocumentTypeCode>"))
    #expect(xml.contains("<cbc:ConditionCode>1</cbc:ConditionCode>"))
    #expect(xml.contains("<cac:Status>"))
    #expect(!xml.contains("<sac:Status>"))
    #expect(xml.contains("<cbc:PaidAmount currencyID=\"PEN\">100.00</cbc:PaidAmount>"))
    #expect(xml.contains("<cbc:InstructionID>01</cbc:InstructionID>"))
    #expect(xml.contains("<cbc:InstructionID>02</cbc:InstructionID>"))
    #expect(xml.contains("<cbc:InstructionID>03</cbc:InstructionID>"))
    #expect(xml.contains("<cbc:RegistrationName>CLIENTE</cbc:RegistrationName>"))
    #expect(xml.contains("<cbc:Percent>18</cbc:Percent>"))
    #expect(xml.contains("<cbc:ID>1000</cbc:ID>"))
    #expect(!xml.contains("<cac:InvoiceLine>"))
}

@Test func dailySummaryIncludesCreditNoteLinkedToBoleta() throws {
    let boleta = makeSummaryBoleta(number: "100")
    let creditNote = makeSummaryCreditNote(number: "101", affectedBoleta: boleta)
    let summary = try ResumenDiarioBoletas(
        sequence: 2,
        issueDate: boleta.issueDate,
        entries: [
            .boleta(boleta),
            .creditNote(creditNote)
        ]
    )
    let xml = try DailySummaryXMLTransformer().transform(summary)

    #expect(summary.lines.count == 2)
    #expect(summary.lines.map(\.lineID) == [1, 2])
    #expect(summary.lines[0].documentType == .boleta)
    #expect(summary.lines[1].documentType == .notaDeCredito)
    #expect(summary.lines[1].affectedDocument == boleta.identifier)
    #expect(xml.components(separatedBy: "<sac:SummaryDocumentsLine>").count - 1 == 2)
    #expect(xml.contains("<cbc:DocumentTypeCode>03</cbc:DocumentTypeCode>"))
    #expect(xml.contains("<cbc:DocumentTypeCode>07</cbc:DocumentTypeCode>"))
    #expect(xml.contains("<cbc:ID>BC01-101</cbc:ID>"))
    #expect(xml.contains("<cbc:ID>B001-100</cbc:ID>"))
}

@Test func dailySummaryWriterAndPackageUseTheRCFileName() throws {
    let fileManager = FileManager.default
    let directory = try makeSummaryTemporaryDirectory()
    defer { try? fileManager.removeItem(at: directory) }
    let summary = try makeDailySummary()
    let document = try CPEDocumentWriter().write(
        SignedCPE(xml: Data("<SummaryDocuments />".utf8), identity: CPEIdentity(summary: summary)),
        output: CPEOutputConfiguration(rootDirectory: directory)
    )

    #expect(document.signedXMLURL.lastPathComponent == "20123456789-RC-20260802-00001.xml")
    #expect(document.zipURL.lastPathComponent == "20123456789-RC-20260802-00001.zip")
    let package = try SunatSummaryPackageValidator().validate(zipAt: document.zipURL)
    #expect(package.xmlEntryName == "20123456789-RC-20260802-00001.xml")
}

@Test func dailySummaryTransformerInfersSignatureMetadata() throws {
    let summary = try makeDailySummary()
    let xml = try DailySummaryXMLTransformer().transform(summary)

    #expect(xml.contains("<cac:Signature>"))
    #expect(xml.contains("<cbc:URI>#SignSUNAT</cbc:URI>"))
    #expect(xml.contains("<cbc:ID>20123456789</cbc:ID>"))
}

@Test func dailySummarySignerSignsAndVerifiesWhenCertificateIsConfigured() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let path = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
          let password = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else { return }
    let configuration = SigningConfiguration(
        credentials: .pkcs12(path: URL(fileURLWithPath: path), passwordProvider: { password })
    )

    let signed = try XMLSecCPESigner().sign(makeDailySummary(), configuration: configuration)

    #expect(signed.identity.fileBaseName == "20123456789-RC-20260802-00001")
    #expect(try XMLSecSignatureVerifier().verify(signed.xml))
}

@Test func sunatSummaryClientSubmitsZIPAndReturnsTicket() async throws {
    let (document, directory) = try makePreparedSummaryDocument()
    defer { try? FileManager.default.removeItem(at: directory) }
    let response = SunatHTTPResponse(
        statusCode: 200,
        body: Data("<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"><soap:Body><sendSummaryResponse><ticket>123456789</ticket></sendSummaryResponse></soap:Body></soap:Envelope>".utf8),
        contentType: "text/xml"
    )
    let transport = SummaryCapturingTransport(responses: [response])

    let submission = try await SunatSummaryClient(transport: transport).submit(
        document: document,
        credentials: .beta(emitterRUC: "20123456789")
    )
    let request = try #require(await transport.requests.first)
    let body = try #require(request.httpBody)

    #expect(submission.ticket == "123456789")
    #expect(request.value(forHTTPHeaderField: "SOAPAction") == "urn:sendSummary")
    #expect(body.contains(Data("<fileName>20123456789-RC-20260802-00001.zip</fileName>".utf8)))
    #expect(body.contains(Data("<wsse:Username>20123456789MODDATOS</wsse:Username>".utf8)))
}

@Test func sunatSummaryClientMapsStatus98ToProcessing() async throws {
    let (document, directory) = try makePreparedSummaryDocument()
    defer { try? FileManager.default.removeItem(at: directory) }
    let transport = SummaryCapturingTransport(responses: [summaryStatusResponse(code: "98")])

    let result = try await SunatSummaryClient(transport: transport).status(
        ticket: "123",
        document: document,
        credentials: .beta(emitterRUC: "20123456789")
    )

    if case .processing = result {} else { Issue.record("Se esperaba el estado processing") }
    let request = try #require(await transport.requests.first)
    #expect(request.value(forHTTPHeaderField: "SOAPAction") == "urn:getStatus")
    #expect(request.httpBody?.contains(Data("<ticket>123</ticket>".utf8)) == true)
}

@Test func sunatSummaryClientParsesAndStoresFinalCDR() async throws {
    let (document, directory) = try makePreparedSummaryDocument()
    defer { try? FileManager.default.removeItem(at: directory) }
    let cdr = try makeSummaryCDRArchive(in: directory, responseCode: "0")
    let transport = SummaryCapturingTransport(responses: [summaryStatusResponse(code: "0", content: cdr)])

    let result = try await SunatSummaryClient(transport: transport).status(
        ticket: "123",
        document: document,
        credentials: .beta(emitterRUC: "20123456789")
    )

    guard case let .completed(cdrResult) = result else {
        Issue.record("Se esperaba una CDR completada")
        return
    }
    #expect(cdrResult.status == .accepted)
    #expect(cdrResult.responseCode == "0")
    #expect(cdrResult.cdrArtifacts?.archiveURL.lastPathComponent == "R-20123456789-RC-20260802-00001.zip")
    #expect(cdrResult.cdrArtifacts?.xmlURL.lastPathComponent == "R-20123456789-RC-20260802-00001.xml")
}

@Test func sunatSummaryClientMapsStatus99ToFailedCDR() async throws {
    let (document, directory) = try makePreparedSummaryDocument()
    defer { try? FileManager.default.removeItem(at: directory) }
    let cdr = try makeSummaryCDRArchive(in: directory, responseCode: "2335")
    let transport = SummaryCapturingTransport(responses: [summaryStatusResponse(code: "99", content: cdr)])

    let result = try await SunatSummaryClient(transport: transport).status(
        ticket: "123",
        document: document,
        credentials: .beta(emitterRUC: "20123456789")
    )

    guard case let .failed(cdrResult) = result else {
        Issue.record("Se esperaba una CDR fallida")
        return
    }
    #expect(cdrResult.status == .rejected)
    #expect(cdrResult.responseCode == "2335")
}

@Suite(.serialized)
struct SunatBetaDailySummaryIntegrationTests {
    /// El servicio beta de SUNAT entrega un ticket para `sendSummary`, pero no
    /// ofrece de manera confiable el procesamiento posterior de resúmenes
    /// diarios mediante `getStatus`. SUNAT limita oficialmente este beta a la
    /// prueba de facturas, boletas y notas UBL 2.1. Por eso esta integración
    /// comprueba el transporte, autenticación y recepción del ticket; el flujo
    /// completo ticket/CDR se cubre con los tests del cliente usando transporte
    /// controlado y debe verificarse contra producción con credenciales SOL.
    @Test func sunatBetaReceivesSignedDailySummaryAndReturnsTicketWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION_RESUMEN_DIARIO"] == "true" else { return }
        guard let pfxPath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
              let pfxPassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else {
            throw DailySummaryIntegrationError.missingSigningCredentials
        }
        let date = currentLimaSummaryDate()
        let sequence = timestampBasedNumber(modulo: 99_999)
        let base = timestampBasedNumber(modulo: 99_999_990)
        let boleta = makeSummaryBoleta(
            number: String(base),
            issueDate: date,
            emitterRUC: "10708255195"
        )
        let creditNote = makeSummaryCreditNote(
            number: String(base + 1),
            affectedBoleta: boleta
        )
        let summary = try ResumenDiarioBoletas(
            sequence: sequence,
            issueDate: date,
            entries: [
                .boleta(boleta),
                .creditNote(creditNote)
            ]
        )
        let configuration = SigningConfiguration(
            credentials: .pkcs12(path: URL(fileURLWithPath: pfxPath), passwordProvider: { pfxPassword })
        )
        let signed = try XMLSecCPESigner().sign(summary, configuration: configuration)
        let directory = try makeSummaryTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let document = try CPEDocumentWriter().write(
            signed,
            output: CPEOutputConfiguration(rootDirectory: directory)
        )
        print("""

        ===== SUNAT BETA RESUMEN DIARIO CON NOTA DE CRÉDITO: XML FIRMADO =====
        Archivo XML: \(document.signedXMLURL.lastPathComponent)
        Archivo ZIP: \(document.zipURL.lastPathComponent)
        \(String(decoding: signed.xml, as: UTF8.self))
        ===== FIN SUNAT BETA RESUMEN DIARIO CON NOTA DE CRÉDITO: XML FIRMADO =====

        """)
        let client = SunatSummaryClient(transport: SummaryIntegrationDiagnosticTransport())
        let submission = try await client.submit(
            document: document,
            credentials: .beta(emitterRUC: "10708255195")
        )
        print("SUNAT BETA RESUMEN DIARIO: ticket recibido = \(submission.ticket)")
        #expect(!submission.ticket.isEmpty)
        print("""

        SUNAT BETA RESUMEN DIARIO: envío recibido correctamente.
        No se consulta getStatus porque el beta público no soporta de forma
        confiable el procesamiento completo de resúmenes diarios.

        """)
    }
}

private struct SummaryIntegrationDiagnosticTransport: SunatHTTPTransport {
    func send(_ request: URLRequest) async throws -> SunatHTTPResponse {
        print("""

        ===== SUNAT BETA RESUMEN DIARIO: SOLICITUD SOAP =====
        URL: \(request.url?.absoluteString ?? "-")
        SOAPAction: \(request.value(forHTTPHeaderField: "SOAPAction") ?? "-")
        Content-Type: \(request.value(forHTTPHeaderField: "Content-Type") ?? "-")
        ===== FIN SOLICITUD SOAP =====

        """)
        return try await URLSessionSunatHTTPTransport().send(request)
    }
}

private enum DailySummaryIntegrationError: Error {
    case missingSigningCredentials
}

private func makeDailySummary(boletas: [Boleta]? = nil) throws -> ResumenDiarioBoletas {
    try ResumenDiarioBoletas(
        sequence: 1,
        issueDate: IssueDate(year: 2026, month: 8, day: 2),
        boletas: boletas ?? [makeSummaryBoleta(number: "1")]
    )
}

private func makeSummaryBoleta(
    number: String,
    issueDate: IssueDate = IssueDate(year: 2026, month: 8, day: 2),
    emitterRUC: String = "20123456789",
    currency: CurrencyCode = .pen,
    pricing: LinePricing = .taxed(100, basis: .excludingTaxes)
) -> Boleta {
    return Boleta(
        identifier: DocumentIdentifier(series: "B001", number: number),
        issueDate: issueDate,
        currency: currency,
        supplier: Supplier(
            taxIdentifier: PartyIdentifier(value: emitterRUC, documentType: .ruc),
            legalName: "EMISOR S.A.C.",
            address: Address(addressTypeCode: "0000", line: "AV. PRUEBA 123")
        ),
        customer: Customer(
            identifier: PartyIdentifier(value: "20203030", documentType: .dni),
            legalName: "CLIENTE"
        ),
        lines: [InvoiceLine(
            id: "1",
            quantity: .units(1),
            pricing: pricing,
            item: Item(description: "PRODUCTO")
        )]
    )
}

private func makeSummaryCreditNote(number: String, affectedBoleta: Boleta) -> NotaCredito {
    NotaCredito(
        identifier: DocumentIdentifier(series: "BC01", number: number),
        issueDate: affectedBoleta.issueDate,
        currency: affectedBoleta.currency,
        supplier: affectedBoleta.supplier,
        customer: affectedBoleta.customer,
        affectedDocument: AffectedDocumentIdentifier(boleta: affectedBoleta),
        reasonCode: .devolucionTotal,
        reasonDescription: "DEVOLUCIÓN TOTAL DE LA VENTA",
        lines: affectedBoleta.lines.map(CreditNoteLine.init(invoiceLine:))
    )
}

private func makePreparedSummaryDocument() throws -> (CPEDocument, URL) {
    let directory = try makeSummaryTemporaryDirectory()
    let summary = try makeDailySummary()
    let document = try CPEDocumentWriter().write(
        SignedCPE(xml: Data("<SummaryDocuments />".utf8), identity: CPEIdentity(summary: summary)),
        output: CPEOutputConfiguration(rootDirectory: directory)
    )
    return (document, directory)
}

private func makeSummaryTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("FlorShopCPE-Summary-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func summaryStatusResponse(code: String, content: Data? = nil) -> SunatHTTPResponse {
    let encoded = content?.base64EncodedString() ?? ""
    let body = "<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"><soap:Body><getStatusResponse><status><statusCode>\(code)</statusCode><content>\(encoded)</content></status></getStatusResponse></soap:Body></soap:Envelope>"
    return SunatHTTPResponse(statusCode: 200, body: Data(body.utf8), contentType: "text/xml")
}

private func makeSummaryCDRArchive(in directory: URL, responseCode: String) throws -> Data {
    let xml = "<ApplicationResponse xmlns:cbc=\"urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2\" xmlns:cac=\"urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2\"><cac:DocumentResponse><cac:Response><cbc:ResponseCode>\(responseCode)</cbc:ResponseCode><cbc:Description>Respuesta SUNAT</cbc:Description></cac:Response></cac:DocumentResponse></ApplicationResponse>"
    let url = directory.appendingPathComponent("R-20123456789-RC-20260802-00001.xml")
    try Data(xml.utf8).write(to: url)
    return try Data(contentsOf: XMLDocumentPackager().package(xmlAt: url).archiveURL)
}

private actor SummaryCapturingTransport: SunatHTTPTransport {
    private(set) var requests: [URLRequest] = []
    private var responses: [SunatHTTPResponse]

    init(responses: [SunatHTTPResponse]) { self.responses = responses }

    func send(_ request: URLRequest) async throws -> SunatHTTPResponse {
        requests.append(request)
        return responses.removeFirst()
    }
}

private func currentLimaSummaryDate() -> IssueDate {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Lima")!
    let components = calendar.dateComponents([.year, .month, .day], from: Date())
    return IssueDate(year: components.year!, month: components.month!, day: components.day!)
}
