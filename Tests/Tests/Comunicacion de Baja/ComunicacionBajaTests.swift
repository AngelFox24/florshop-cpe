import Foundation
import Testing
@testable import FlorShopCPE

@Test func voidedDocumentTypeCannotRepresentBoleta() {
    #expect(VoidedDocumentType(rawValue: "03") == nil)
}

@Test func voidedDocumentsModelAndTransformerGenerateSUNATUBL20() throws {
    let communication = try makeVoidedDocuments(lines: [
        VoidedDocumentLine(
            lineID: 1,
            documentType: .factura,
            documentIdentifier: DocumentIdentifier(series: "F001", number: "100"),
            reason: "ERROR EN LA NUMERACIÓN"
        ),
        VoidedDocumentLine(
            lineID: 2,
            documentType: .notaDeCredito,
            documentIdentifier: DocumentIdentifier(series: "FC01", number: "101"),
            reason: "DOCUMENTO NO OTORGADO"
        )
    ])
    let xml = try VoidedDocumentsXMLTransformer().transform(communication)

    #expect(communication.identifier.value == "RA-20260802-00001")
    #expect(xml.contains("<VoidedDocuments"))
    #expect(xml.contains("xmlns=\"urn:sunat:names:specification:ubl:peru:schema:xsd:VoidedDocuments-1\""))
    #expect(xml.contains("xmlns:sac=\"urn:sunat:names:specification:ubl:peru:schema:xsd:SunatAggregateComponents-1\""))
    #expect(xml.contains("<cbc:UBLVersionID>2.0</cbc:UBLVersionID>"))
    #expect(xml.contains("<cbc:CustomizationID>1.0</cbc:CustomizationID>"))
    #expect(xml.contains("<cbc:ID>RA-20260802-00001</cbc:ID>"))
    #expect(xml.contains("<cbc:ReferenceDate>2026-08-02</cbc:ReferenceDate>"))
    #expect(xml.contains("<cbc:IssueDate>2026-08-02</cbc:IssueDate>"))
    #expect(xml.components(separatedBy: "<sac:VoidedDocumentsLine>").count - 1 == 2)
    #expect(xml.contains("<cbc:DocumentTypeCode>01</cbc:DocumentTypeCode>"))
    #expect(xml.contains("<sac:DocumentSerialID>F001</sac:DocumentSerialID>"))
    #expect(xml.contains("<sac:DocumentNumberID>100</sac:DocumentNumberID>"))
    #expect(xml.contains("<sac:VoidReasonDescription>ERROR EN LA NUMERACIÓN</sac:VoidReasonDescription>"))
    #expect(xml.contains("<cbc:DocumentTypeCode>07</cbc:DocumentTypeCode>"))
    #expect(xml.hasSuffix("</VoidedDocuments>"))
}

@Test func voidedDocumentsValidatorRejectsBSeriesForNotes() {
    #expect(throws: VoidedDocumentsValidationError.invalidDocumentSeries("BC01")) {
        _ = try makeVoidedDocuments(lines: [VoidedDocumentLine(
            lineID: 1,
            documentType: .notaDeCredito,
            documentIdentifier: DocumentIdentifier(series: "BC01", number: "100"),
            reason: "DOCUMENTO NO OTORGADO"
        )])
    }
}

@Test func voidedDocumentsValidatorAcceptsLegacyNumericSeries() throws {
    let communication = try makeVoidedDocuments(lines: [VoidedDocumentLine(
        lineID: 1,
        documentType: .factura,
        documentIdentifier: DocumentIdentifier(series: "1234", number: "100"),
        reason: "DOCUMENTO NO OTORGADO"
    )])

    #expect(communication.lines.first?.documentIdentifier.series == "1234")
}

@Test func voidedDocumentsValidatorRequiresIdentifierDateToMatchIssueDate() {
    #expect(throws: VoidedDocumentsValidationError.invalidIdentifierDate) {
        _ = try ComunicacionBaja(
            identifier: VoidedDocumentsIdentifier(
                date: IssueDate(year: 2026, month: 8, day: 1),
                sequence: 1
            ),
            issueDate: IssueDate(year: 2026, month: 8, day: 2),
            referenceDate: IssueDate(year: 2026, month: 8, day: 2),
            supplier: voidedSupplier(),
            lines: [VoidedDocumentLine(
                lineID: 1,
                documentType: .factura,
                documentIdentifier: DocumentIdentifier(series: "F001", number: "100"),
                reason: "DOCUMENTO NO OTORGADO"
            )]
        )
    }
}

@Test func voidedDocumentsValidatorRejectsGenerationBeforeDocumentDate() {
    #expect(throws: VoidedDocumentsValidationError.generationDateBeforeReferenceDate) {
        _ = try makeVoidedDocuments(referenceDate: IssueDate(year: 2026, month: 8, day: 3))
    }
}

@Test func voidedDocumentsValidatorRejectsDuplicatedDocuments() {
    let identifier = DocumentIdentifier(series: "F001", number: "100")
    #expect(throws: VoidedDocumentsValidationError.duplicatedDocument("F001-100")) {
        _ = try makeVoidedDocuments(lines: [
            VoidedDocumentLine(
                lineID: 1,
                documentType: .factura,
                documentIdentifier: identifier,
                reason: "DOCUMENTO NO OTORGADO"
            ),
            VoidedDocumentLine(
                lineID: 2,
                documentType: .factura,
                documentIdentifier: identifier,
                reason: "ERROR EN LA NUMERACIÓN"
            )
        ])
    }
}

@Test func voidedDocumentsValidatorRequiresObservationFreeReason() {
    #expect(throws: VoidedDocumentsValidationError.invalidReason(lineID: 1)) {
        _ = try makeVoidedDocuments(lines: [VoidedDocumentLine(
            lineID: 1,
            documentType: .factura,
            documentIdentifier: DocumentIdentifier(series: "F001", number: "100"),
            reason: "NO"
        )])
    }
    #expect(throws: VoidedDocumentsValidationError.invalidReason(lineID: 1)) {
        _ = try makeVoidedDocuments(lines: [VoidedDocumentLine(
            lineID: 1,
            documentType: .factura,
            documentIdentifier: DocumentIdentifier(series: "F001", number: "100"),
            reason: "DOCUMENTO\nNO OTORGADO"
        )])
    }
}

@Test func voidedDocumentsWriterAndPackageUseTheRAFileName() throws {
    let directory = try makeVoidedTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let communication = try makeVoidedDocuments()
    let document = try CPEDocumentWriter().write(
        SignedCPE(xml: Data("<VoidedDocuments />".utf8), identity: CPEIdentity(communication: communication)),
        output: CPEOutputConfiguration(rootDirectory: directory)
    )

    #expect(document.signedXMLURL.lastPathComponent == "20123456789-RA-20260802-00001.xml")
    #expect(document.zipURL.lastPathComponent == "20123456789-RA-20260802-00001.zip")
    let package = try SunatSummaryPackageValidator().validate(zipAt: document.zipURL)
    #expect(package.xmlEntryName == "20123456789-RA-20260802-00001.xml")
}

@Test func voidedDocumentsTransformerInfersSignatureMetadata() throws {
    let communication = try makeVoidedDocuments()
    let xml = try VoidedDocumentsXMLTransformer().transform(communication)

    #expect(xml.contains("<cac:Signature>"))
    #expect(xml.contains("<cbc:URI>#SignSUNAT</cbc:URI>"))
    #expect(xml.contains("<cbc:ID>20123456789</cbc:ID>"))
}

@Test func voidedDocumentsSignerSignsAndVerifiesWhenCertificateIsConfigured() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let path = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
          let password = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else { return }
    let communication = try makeVoidedDocuments()
    let signed = try XMLSecCPESigner().sign(
        communication,
        configuration: voidedSigningConfiguration(
            pfxPath: path,
            pfxPassword: password
        )
    )

    #expect(signed.identity.fileBaseName == "20123456789-RA-20260802-00001")
    #expect(try XMLSecSignatureVerifier().verify(signed.xml))
}

@Test func sunatSummaryClientSubmitsCommunicationZIPAndReturnsTicket() async throws {
    let (document, directory) = try makePreparedVoidedDocument()
    defer { try? FileManager.default.removeItem(at: directory) }
    let response = SunatHTTPResponse(
        statusCode: 200,
        body: Data("<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"><soap:Body><sendSummaryResponse><ticket>RA123456789</ticket></sendSummaryResponse></soap:Body></soap:Envelope>".utf8),
        contentType: "text/xml"
    )
    let transport = VoidedCapturingTransport(responses: [response])

    let submission = try await SunatSummaryClient(transport: transport).submit(
        document: document,
        credentials: .beta(emitterRUC: "20123456789")
    )
    let request = try #require(await transport.requests.first)

    #expect(submission.ticket == "RA123456789")
    #expect(request.value(forHTTPHeaderField: "SOAPAction") == "urn:sendSummary")
    #expect(request.httpBody?.contains(Data("<fileName>20123456789-RA-20260802-00001.zip</fileName>".utf8)) == true)
}

@Test func sunatSummaryClientStoresCommunicationCDRUsingRAName() async throws {
    let (document, directory) = try makePreparedVoidedDocument()
    defer { try? FileManager.default.removeItem(at: directory) }
    let cdr = try makeVoidedCDRArchive(in: directory)
    let transport = VoidedCapturingTransport(responses: [voidedStatusResponse(code: "0", content: cdr)])

    let result = try await SunatSummaryClient(transport: transport).status(
        ticket: "RA123",
        document: document,
        credentials: .beta(emitterRUC: "20123456789")
    )

    guard case let .completed(cdrResult) = result else {
        Issue.record("Se esperaba una CDR completada")
        return
    }
    #expect(cdrResult.status == .accepted)
    #expect(cdrResult.cdrArtifacts?.archiveURL.lastPathComponent == "R-20123456789-RA-20260802-00001.zip")
    #expect(cdrResult.cdrArtifacts?.xmlURL.lastPathComponent == "R-20123456789-RA-20260802-00001.xml")
}

@Suite(.serialized)
struct SunatBetaVoidedDocumentsIntegrationTests {
    /// Crea y envía primero la factura afectada; después envía la Comunicación
    /// de Baja y comprueba que el beta devuelva un ticket. La consulta final
    /// del ticket queda cubierta por los tests con transporte controlado porque
    /// el beta público no procesa resúmenes de forma confiable.
    @Test func sunatBetaReceivesSignedCommunicationAndReturnsTicketWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION_COMUNICACION_BAJA"] == "true" else {
            return
        }
        guard let pfxPath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
              let pfxPassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else {
            throw VoidedDocumentsIntegrationError.missingSigningCredentials
        }

        let issueDate = currentLimaVoidedDate()
        let base = timestampBasedNumber(modulo: 99_999_990)
        let invoice = makeVoidedPrerequisiteInvoice(number: String(base), issueDate: issueDate)
        let invoiceResult = try await signWriteAndSubmitVoidedPrerequisite(
            invoice,
            pfxPath: pfxPath,
            pfxPassword: pfxPassword
        )
        #expect(invoiceResult.status == .accepted)
        guard invoiceResult.status == .accepted else {
            throw VoidedDocumentsIntegrationError.prerequisiteInvoiceWasNotAccepted
        }

        try await Task.sleep(for: .seconds(2))
        let communication = try makeVoidedDocuments(
            sequence: timestampBasedNumber(modulo: 99_999),
            issueDate: issueDate,
            referenceDate: issueDate,
            supplier: invoice.supplier,
            lines: [VoidedDocumentLine(
                lineID: 1,
                documentType: .factura,
                documentIdentifier: invoice.identifier,
                reason: "DOCUMENTO NO OTORGADO"
            )]
        )
        let signed = try XMLSecCPESigner().sign(
            communication,
            configuration: voidedSigningConfiguration(
                pfxPath: pfxPath,
                pfxPassword: pfxPassword
            )
        )
        let directory = try makeVoidedTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let document = try CPEDocumentWriter().write(
            signed,
            output: CPEOutputConfiguration(rootDirectory: directory)
        )
        printVoidedXML(signed, document: document, label: "COMUNICACIÓN DE BAJA")
        let submission = try await submitVoidedDocumentsToSunatBeta(
            document: document,
            emitterRUC: invoice.supplier.taxIdentifier.value
        )

        print("SUNAT BETA COMUNICACIÓN DE BAJA: ticket recibido = \(submission.ticket)")
        #expect(!submission.ticket.isEmpty)
    }
}

@Suite(.serialized)
struct OSEVoidedDocumentsManualValidationTests {
    /// Firma e imprime una factura y su Comunicación de Baja para enviarlas
    /// manualmente al OSE, en ese orden. No realiza red ni escribe XML/ZIP.
    @Test func printsSignedInvoiceAndCommunicationXMLForOSE() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let pfxPath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
              let pfxPassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else { return }

        let issueDate = currentLimaVoidedDate()
        let base = timestampBasedNumber(modulo: 99_999_990)
        let invoice = makeVoidedPrerequisiteInvoice(number: String(base), issueDate: issueDate)
        let communication = try makeVoidedDocuments(
            sequence: timestampBasedNumber(modulo: 99_999),
            issueDate: issueDate,
            referenceDate: issueDate,
            supplier: invoice.supplier,
            lines: [VoidedDocumentLine(
                lineID: 1,
                documentType: .factura,
                documentIdentifier: invoice.identifier,
                reason: "DOCUMENTO NO OTORGADO"
            )]
        )
        let signer = XMLSecCPESigner()
        let signedInvoice = try signer.sign(
            invoice,
            configuration: voidedSigningConfiguration(
                pfxPath: pfxPath,
                pfxPassword: pfxPassword
            )
        )
        let signedCommunication = try signer.sign(
            communication,
            configuration: voidedSigningConfiguration(
                pfxPath: pfxPath,
                pfxPassword: pfxPassword
            )
        )

        print("""

        ===== XML FIRMADOS PARA VALIDACIÓN MANUAL EN OSE =====

        PASO 1 — Enviar y obtener aceptación de la factura:
        \(String(decoding: signedInvoice.xml, as: UTF8.self))

        PASO 2 — Solo después, enviar la Comunicación de Baja:
        Documento: \(invoice.identifier.value)
        \(String(decoding: signedCommunication.xml, as: UTF8.self))
        ===== FIN XML FIRMADOS PARA VALIDACIÓN MANUAL EN OSE =====

        """)

        #expect(signedCommunication.identity.documentTypeCode == "RA")
        #expect(try XMLSecSignatureVerifier().verify(signedInvoice.xml))
        #expect(try XMLSecSignatureVerifier().verify(signedCommunication.xml))
    }
}

private func makeVoidedDocuments(
    sequence: Int = 1,
    issueDate: IssueDate = IssueDate(year: 2026, month: 8, day: 2),
    referenceDate: IssueDate = IssueDate(year: 2026, month: 8, day: 2),
    supplier: Supplier = voidedSupplier(),
    lines: [VoidedDocumentLine] = [VoidedDocumentLine(
        lineID: 1,
        documentType: .factura,
        documentIdentifier: DocumentIdentifier(series: "F001", number: "100"),
        reason: "DOCUMENTO NO OTORGADO"
    )]
) throws -> ComunicacionBaja {
    try ComunicacionBaja(
        sequence: sequence,
        issueDate: issueDate,
        referenceDate: referenceDate,
        supplier: supplier,
        lines: lines
    )
}

private func voidedSupplier(ruc: String = "20123456789") -> Supplier {
    Supplier(
        taxIdentifier: PartyIdentifier(value: ruc, documentType: .ruc),
        commercialName: "EMISOR",
        legalName: "EMISOR S.A.C.",
        address: Address(addressTypeCode: "0000", line: "AV. PRUEBA 123")
    )
}

private func makeVoidedPrerequisiteInvoice(number: String, issueDate: IssueDate) -> Factura {
    return Factura(
        identifier: DocumentIdentifier(series: "F001", number: number),
        issueDate: issueDate,
        issueTime: IssueTime(hour: 12, minute: 0),
        currency: .pen,
        supplier: voidedSupplier(ruc: "10708255195"),
        customer: Customer(
            identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
            legalName: "CLIENTE S.A.C."
        ),
        lines: [InvoiceLine(
            id: "1",
            quantity: .units(1),
            pricing: .taxed(100, basis: .excludingTaxes),
            item: Item(description: "PRODUCTO", sellerItemIdentifier: "P001")
        )],
        paymentCondition: .cash
    )
}

private func voidedSigningConfiguration(
    pfxPath: String,
    pfxPassword: String
) -> SigningConfiguration {
    SigningConfiguration(
        credentials: .pkcs12(
            path: URL(fileURLWithPath: pfxPath),
            passwordProvider: { pfxPassword }
        )
    )
}

private func signWriteAndSubmitVoidedPrerequisite(
    _ invoice: Factura,
    pfxPath: String,
    pfxPassword: String
) async throws -> SunatBillSubmissionResult {
    let signed = try XMLSecCPESigner().sign(
        invoice,
        configuration: voidedSigningConfiguration(
            pfxPath: pfxPath,
            pfxPassword: pfxPassword
        )
    )
    let directory = try makeVoidedTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let document = try CPEDocumentWriter().write(
        signed,
        output: CPEOutputConfiguration(rootDirectory: directory)
    )
    printVoidedXML(signed, document: document, label: "FACTURA AFECTADA")
    return try await submitVoidedPrerequisiteToSunatBeta(
        document: document,
        emitterRUC: invoice.supplier.taxIdentifier.value
    )
}

/// SUNAT beta puede devolver HTTP 401 entre autenticaciones MODDATOS
/// consecutivas. Estos reintentos pertenecen solo al test de integración; la
/// librería entrega el error original para que el POS decida su política.
private func submitVoidedPrerequisiteToSunatBeta(
    document: CPEDocument,
    emitterRUC: String
) async throws -> SunatBillSubmissionResult {
    let maximumAttempts = 3

    for attempt in 1 ... maximumAttempts {
        do {
            return try await SunatBillClient().submit(
                document: document,
                credentials: .beta(emitterRUC: emitterRUC)
            )
        } catch let error as SunatBillSubmissionError {
            guard case .unexpectedHTTPStatus(statusCode: 401, details: _) = error,
                  attempt < maximumAttempts else {
                throw error
            }
            print("SUNAT BETA FACTURA AFECTADA: HTTP 401, reintento \(attempt + 1)/\(maximumAttempts)")
            try await Task.sleep(for: .seconds(2))
        }
    }

    preconditionFailure("El bucle de reintentos debe devolver o lanzar un error.")
}

private func submitVoidedDocumentsToSunatBeta(
    document: CPEDocument,
    emitterRUC: String
) async throws -> SunatSummarySubmission {
    let maximumAttempts = 3

    for attempt in 1 ... maximumAttempts {
        do {
            return try await SunatSummaryClient().submit(
                document: document,
                credentials: .beta(emitterRUC: emitterRUC)
            )
        } catch let error as SunatSummaryError {
            guard case .unexpectedHTTPStatus(statusCode: 401, details: _) = error,
                  attempt < maximumAttempts else {
                throw error
            }
            print("SUNAT BETA COMUNICACIÓN DE BAJA: HTTP 401, reintento \(attempt + 1)/\(maximumAttempts)")
            try await Task.sleep(for: .seconds(2))
        }
    }

    preconditionFailure("El bucle de reintentos debe devolver o lanzar un error.")
}

private func printVoidedXML(_ signed: SignedCPE, document: CPEDocument, label: String) {
    print("""

    ===== SUNAT BETA \(label): XML FIRMADO =====
    Archivo XML: \(document.signedXMLURL.lastPathComponent)
    Archivo ZIP: \(document.zipURL.lastPathComponent)
    \(String(decoding: signed.xml, as: UTF8.self))
    ===== FIN SUNAT BETA \(label): XML FIRMADO =====

    """)
}

private func makePreparedVoidedDocument() throws -> (CPEDocument, URL) {
    let directory = try makeVoidedTemporaryDirectory()
    let communication = try makeVoidedDocuments()
    let document = try CPEDocumentWriter().write(
        SignedCPE(
            xml: Data("<VoidedDocuments />".utf8),
            identity: CPEIdentity(communication: communication)
        ),
        output: CPEOutputConfiguration(rootDirectory: directory)
    )
    return (document, directory)
}

private func makeVoidedTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-Voided-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func voidedStatusResponse(code: String, content: Data? = nil) -> SunatHTTPResponse {
    let encoded = content?.base64EncodedString() ?? ""
    let body = "<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"><soap:Body><getStatusResponse><status><statusCode>\(code)</statusCode><content>\(encoded)</content></status></getStatusResponse></soap:Body></soap:Envelope>"
    return SunatHTTPResponse(statusCode: 200, body: Data(body.utf8), contentType: "text/xml")
}

private func makeVoidedCDRArchive(in directory: URL) throws -> Data {
    let xml = "<ApplicationResponse xmlns:cbc=\"urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2\" xmlns:cac=\"urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2\"><cac:DocumentResponse><cac:Response><cbc:ResponseCode>0</cbc:ResponseCode><cbc:Description>La Comunicación de Baja ha sido aceptada</cbc:Description></cac:Response></cac:DocumentResponse></ApplicationResponse>"
    let url = directory.appendingPathComponent("R-20123456789-RA-20260802-00001.xml")
    try Data(xml.utf8).write(to: url)
    return try Data(contentsOf: XMLDocumentPackager().package(xmlAt: url).archiveURL)
}

private actor VoidedCapturingTransport: SunatHTTPTransport {
    private(set) var requests: [URLRequest] = []
    private var responses: [SunatHTTPResponse]

    init(responses: [SunatHTTPResponse]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> SunatHTTPResponse {
        requests.append(request)
        return responses.removeFirst()
    }
}

private func currentLimaVoidedDate() -> IssueDate {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Lima")!
    let values = calendar.dateComponents([.year, .month, .day], from: Date())
    return IssueDate(year: values.year!, month: values.month!, day: values.day!)
}

private enum VoidedDocumentsIntegrationError: Error {
    case missingSigningCredentials
    case prerequisiteInvoiceWasNotAccepted
}
