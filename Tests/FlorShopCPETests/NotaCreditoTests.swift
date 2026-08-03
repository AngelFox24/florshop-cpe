import Foundation
import Testing
import ZIPFoundation
@testable import FlorShopCPE

@Test func creditNoteModelAndTransformerGenerateUBL21() throws {
    let note = makeCreditNote()
    let xml = try CreditNoteXMLTransformer().transform(note)

    #expect(note.identifier.value == "FC01-200")
    #expect(note.documentType == .notaDeCredito)
    #expect(note.affectedDocument.value == "F001-100")
    #expect(xml.contains("<CreditNote"))
    #expect(xml.contains("xmlns=\"urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2\""))
    #expect(xml.contains("<cbc:UBLVersionID>2.1</cbc:UBLVersionID>"))
    #expect(xml.contains("<cbc:CustomizationID>2.0</cbc:CustomizationID>"))
    #expect(xml.contains("<cbc:ReferenceID>F001-100</cbc:ReferenceID>"))
    #expect(xml.contains(">06</cbc:ResponseCode>"))
    #expect(xml.contains("catalogo09"))
    #expect(xml.contains("<cac:InvoiceDocumentReference>"))
    #expect(xml.contains(">01</cbc:DocumentTypeCode>"))
    #expect(xml.contains("<cac:CreditNoteLine>"))
    #expect(xml.contains("<cbc:CreditedQuantity"))
    #expect(xml.contains(">1</cbc:CreditedQuantity>"))
    #expect(xml.contains("<cbc:PayableAmount currencyID=\"PEN\">118.00</cbc:PayableAmount>"))
    #expect(xml.hasSuffix("</CreditNote>"))
}

@Test func affectedDocumentTypeCannotRepresentAnotherNote() {
    #expect(AffectedInvoiceDocumentType(rawValue: "07") == nil)
    #expect(AffectedInvoiceDocumentType(rawValue: "08") == nil)
}

@Test func creditNoteValidatorRequiresSeriesMatchingAffectedDocument() {
    let note = makeCreditNote(
        identifier: DocumentIdentifier(series: "BC01", number: "200")
    )

    #expect(throws: CreditNoteValidationError.invalidSeries(expectedPrefix: "F")) {
        try CreditNoteValidator().validate(note)
    }
}

@Test func creditNoteValidatorRejectsInvoiceCustomerWithoutRUC() {
    let note = makeCreditNote(customer: Customer(
        identifier: PartyIdentifier(value: "46237547", documentType: .dni),
        legalName: "CLIENTE"
    ))

    #expect(throws: CreditNoteValidationError.facturaCustomerMustHaveRUC) {
        try CreditNoteValidator().validate(note)
    }
}

@Test func creditNoteValidatorRejectsDiscountReasonsForBoleta() {
    let note = makeCreditNoteForBoleta(reason: .descuentoGlobal)

    #expect(throws: CreditNoteValidationError.reasonNotAllowedForBoleta(.descuentoGlobal)) {
        try CreditNoteValidator().validate(note)
    }
}

@Test func creditNoteForBoletaBecomesDailySummaryLine() throws {
    let note = makeCreditNoteForBoleta()
    let line = try DailySummaryLine(lineID: 1, creditNote: note)
    let summary = try ResumenDiarioBoletas(
        identifier: DailySummaryIdentifier(date: note.issueDate, sequence: 1),
        issueDate: note.issueDate,
        referenceDate: note.issueDate,
        supplier: note.supplier,
        lines: [line]
    )
    let xml = try DailySummaryXMLTransformer().transform(summary)

    #expect(line.documentType == .notaDeCredito)
    #expect(line.documentIdentifier.value == "BC01-200")
    #expect(line.affectedDocument?.value == "B001-100")
    #expect(line.totalAmount.value == 118)
    #expect(xml.contains("<cbc:DocumentTypeCode>07</cbc:DocumentTypeCode>"))
    #expect(xml.contains("<cbc:ID>BC01-200</cbc:ID>"))
    #expect(xml.contains("<cbc:ID>B001-100</cbc:ID>"))
    #expect(xml.contains("<cbc:DocumentTypeCode>03</cbc:DocumentTypeCode>"))
}

@Test func invoiceCreditNoteCannotBecomeDailySummaryLine() {
    #expect(throws: DailySummaryValidationError.invalidAffectedDocument(1)) {
        _ = try DailySummaryLine(lineID: 1, creditNote: makeCreditNote())
    }
}

@Test func creditNoteUsesSUNATFileIdentityAndSharedWriter() throws {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-CreditNote-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directory) }
    let note = makeCreditNote()
    let identity = CPEIdentity(note: note)
    let document = try CPEDocumentWriter().write(
        SignedCPE(xml: Data("<CreditNote />".utf8), identity: identity),
        output: CPEOutputConfiguration(rootDirectory: directory)
    )

    #expect(identity.fileBaseName == "10708255195-07-FC01-200")
    #expect(document.signedXMLURL.lastPathComponent == "10708255195-07-FC01-200.xml")
    #expect(document.zipURL.lastPathComponent == "10708255195-07-FC01-200.zip")
    #expect(try SunatBillPackageValidator().validate(zipAt: document.zipURL).xmlEntryName == "10708255195-07-FC01-200.xml")
}

@Test func creditNoteTransformerInfersSignatureMetadata() throws {
    let xml = try CreditNoteXMLTransformer().transform(makeCreditNote())

    #expect(xml.contains("<cac:Signature>"))
    #expect(xml.contains("<cbc:URI>#SignSUNAT</cbc:URI>"))
    #expect(xml.contains("<cbc:ID>10708255195</cbc:ID>"))
}

@Test func creditNoteSignerSignsAndVerifiesWhenCertificateIsConfigured() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let path = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
          let password = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else { return }
    let note = makeCreditNote()
    let signed = try XMLSecCPESigner().sign(
        note,
        configuration: SigningConfiguration(
            credentials: .pkcs12(path: URL(fileURLWithPath: path), passwordProvider: { password })
        )
    )

    #expect(signed.identity.fileBaseName == "10708255195-07-FC01-200")
    #expect(try XMLSecSignatureVerifier().verify(signed.xml))
}

@Suite(.serialized)
struct SunatBetaCreditNoteIntegrationTests {
    /// Crea primero la factura afectada y luego envía su Nota de Crédito.
    /// Solo se ejecuta con `FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION_NOTA_CREDITO=true`.
    @Test func sunatBetaAcceptsSignedInvoiceCreditNoteWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION_NOTA_CREDITO"] == "true" else { return }
        guard let pfxPath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
              let pfxPassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else {
            throw CreditNoteIntegrationError.missingSigningCredentials
        }

        let issueDate = currentLimaCreditNoteDate()
        let base = max(1, Int(Date().timeIntervalSince1970) % 99_999_990)
        let invoice = makeCreditNotePrerequisiteInvoice(number: String(base), issueDate: issueDate)
        let invoiceResult = try await signWriteAndSubmit(
            invoice,
            pfxPath: pfxPath,
            pfxPassword: pfxPassword,
            label: "FACTURA AFECTADA"
        )
        #expect(invoiceResult.status == .accepted)
        guard invoiceResult.status == .accepted else {
            throw CreditNoteIntegrationError.prerequisiteInvoiceWasNotAccepted
        }

        // El beta público puede tardar brevemente en registrar la factura y
        // rechazar una segunda autenticación MODDATOS demasiado próxima.
        try await Task.sleep(for: .seconds(2))

        let note = makeCreditNote(
            identifier: DocumentIdentifier(series: "FC01", number: String(base + 1)),
            affectedDocument: AffectedDocumentIdentifier(factura: invoice),
            issueDate: issueDate
        )
        let noteResult = try await signWriteAndSubmit(
            note,
            pfxPath: pfxPath,
            pfxPassword: pfxPassword,
            label: "NOTA DE CRÉDITO"
        )

        #expect(noteResult.status == .accepted)
        #expect(noteResult.responseCode == "0")
        #expect(noteResult.observations.isEmpty)
        #expect(noteResult.cdrArtifacts != nil)
    }
}

@Suite(.serialized)
struct OSECreditNoteManualValidationTests {
    /// Firma e imprime una factura y su Nota de Crédito para copiarlas
    /// manualmente al OSE, en ese orden. No realiza llamadas de red ni escribe
    /// archivos XML o ZIP.
    @Test func printsSignedInvoiceAndCreditNoteXMLForOSE() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let pfxPath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
              let pfxPassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else { return }

        let issueDate = currentLimaCreditNoteDate()
        let base = max(1, Int(Date().timeIntervalSince1970) % 99_999_990)
        let invoice = makeCreditNotePrerequisiteInvoice(number: String(base), issueDate: issueDate)
        let note = makeCreditNote(
            identifier: DocumentIdentifier(series: "FC01", number: String(base + 1)),
            affectedDocument: AffectedDocumentIdentifier(factura: invoice),
            issueDate: issueDate
        )
        let signer = XMLSecCPESigner()

        let signedInvoice = try signer.sign(
            invoice,
            configuration: creditNoteSigningConfiguration(
                pfxPath: pfxPath,
                pfxPassword: pfxPassword
            )
        )

        let signedNote = try signer.sign(
            note,
            configuration: creditNoteSigningConfiguration(
                pfxPath: pfxPath,
                pfxPassword: pfxPassword
            )
        )

        print("""

        ===== XML FIRMADOS PARA VALIDACIÓN MANUAL EN OSE =====

        PASO 1 — Enviar y obtener aceptación de la factura:
        \(String(decoding: signedInvoice.xml, as: UTF8.self))

        PASO 2 — Solo después, enviar la Nota de Crédito:
        Documento afectado: \(note.affectedDocument.value)
        \(String(decoding: signedNote.xml, as: UTF8.self))
        ===== FIN XML FIRMADOS PARA VALIDACIÓN MANUAL EN OSE =====

        """)

        #expect(note.affectedDocument.identifier == invoice.identifier)
        #expect(signedInvoice.identity.fileBaseName == "10708255195-01-\(invoice.identifier.value)")
        #expect(signedNote.identity.fileBaseName == "10708255195-07-\(note.identifier.value)")
        #expect(try XMLSecSignatureVerifier().verify(signedInvoice.xml))
        #expect(try XMLSecSignatureVerifier().verify(signedNote.xml))
    }
}

private func makeCreditNote(
    identifier: DocumentIdentifier = DocumentIdentifier(series: "FC01", number: "200"),
    affectedDocument: AffectedDocumentIdentifier = AffectedDocumentIdentifier(
        series: "F001",
        number: "100",
        type: .factura
    ),
    customer: Customer = Customer(
        identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
        legalName: "CLIENTE S.A.C."
    ),
    reason: CreditNoteReasonCode = .devolucionTotal,
    issueDate: IssueDate = IssueDate(year: 2026, month: 8, day: 2)
) -> NotaCredito {
    let values = creditNoteValues()
    return NotaCredito(
        identifier: identifier,
        issueDate: issueDate,
        issueTime: IssueTime(hour: 12, minute: 0),
        currency: .pen,
        supplier: creditNoteSupplier(),
        customer: customer,
        affectedDocument: affectedDocument,
        reasonCode: reason,
        reasonDescription: "DEVOLUCIÓN DEL PRODUCTO",
        taxTotal: values.taxTotal,
        monetaryTotal: CreditNoteMonetaryTotal(payableAmount: values.payable),
        lines: [CreditNoteLine(invoiceLine: values.line)]
    )
}

private func makeCreditNoteForBoleta(reason: CreditNoteReasonCode = .devolucionTotal) -> NotaCredito {
    makeCreditNote(
        identifier: DocumentIdentifier(series: "BC01", number: "200"),
        affectedDocument: AffectedDocumentIdentifier(
            series: "B001",
            number: "100",
            type: .boleta
        ),
        customer: Customer(
            identifier: PartyIdentifier(value: "46237547", documentType: .dni),
            legalName: "CLIENTE"
        ),
        reason: reason
    )
}

private func creditNoteSupplier() -> Supplier {
    Supplier(
        taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
        commercialName: "EMISOR",
        legalName: "EMISOR S.A.C.",
        address: Address(
            ubigeoCode: "150130",
            addressTypeCode: "0000",
            city: "LIMA",
            department: "LIMA",
            district: "SAN BORJA",
            line: "CAL. PABLO USANDIZAGA 670"
        )
    )
}

private func creditNoteValues() -> (taxTotal: TaxTotal, payable: MonetaryAmount, line: InvoiceLine) {
    let taxable = MonetaryAmount(value: 100)
    let tax = MonetaryAmount(value: 18)
    let payable = MonetaryAmount(value: 118)
    let category = TaxCategory(percent: 18, exemptionReasonCode: .gravadoOperacionOnerosa, scheme: .igv)
    let taxTotal = TaxTotal(
        amount: tax,
        subtotals: [TaxSubtotal(taxableAmount: taxable, taxAmount: tax, scheme: .igv)]
    )
    let line = InvoiceLine(
        id: "1",
        quantity: Quantity(value: 1, unitCode: .unit),
        lineExtensionAmount: taxable,
        alternativePrices: [AlternativePrice(amount: payable, type: .unitPriceIncludingTaxes)],
        taxTotal: LineTaxTotal(
            amount: tax,
            subtotals: [LineTaxSubtotal(taxableAmount: taxable, taxAmount: tax, category: category)]
        ),
        item: Item(description: "PRODUCTO", sellerItemIdentifier: "P001"),
        price: taxable
    )
    return (taxTotal, payable, line)
}

private func makeCreditNotePrerequisiteInvoice(number: String, issueDate: IssueDate) -> Factura {
    let values = creditNoteValues()
    return Factura(
        identifier: DocumentIdentifier(series: "F001", number: number),
        issueDate: issueDate,
        issueTime: IssueTime(hour: 12, minute: 0),
        currency: .pen,
        supplier: creditNoteSupplier(),
        customer: Customer(
            identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
            legalName: "CLIENTE S.A.C."
        ),
        taxTotal: values.taxTotal,
        monetaryTotal: MonetaryTotal(
            lineExtensionAmount: MonetaryAmount(value: 100),
            taxInclusiveAmount: values.payable,
            payableAmount: values.payable
        ),
        lines: [values.line],
        paymentCondition: .cash
    )
}

private func currentLimaCreditNoteDate() -> IssueDate {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Lima")!
    let values = calendar.dateComponents([.year, .month, .day], from: Date())
    return IssueDate(year: values.year!, month: values.month!, day: values.day!)
}

private func signWriteAndSubmit(
    _ invoice: Factura,
    pfxPath: String,
    pfxPassword: String,
    label: String
) async throws -> SunatBillSubmissionResult {
    let signed = try XMLSecCPESigner().sign(
        invoice,
        configuration: creditNoteSigningConfiguration(
            pfxPath: pfxPath,
            pfxPassword: pfxPassword
        )
    )
    return try await writePrintAndSubmit(signed, emitterRUC: invoice.supplier.taxIdentifier.value, label: label)
}

private func signWriteAndSubmit(
    _ note: NotaCredito,
    pfxPath: String,
    pfxPassword: String,
    label: String
) async throws -> SunatBillSubmissionResult {
    let signed = try XMLSecCPESigner().sign(
        note,
        configuration: creditNoteSigningConfiguration(
            pfxPath: pfxPath,
            pfxPassword: pfxPassword
        )
    )
    return try await writePrintAndSubmit(signed, emitterRUC: note.supplier.taxIdentifier.value, label: label)
}

private func creditNoteSigningConfiguration(
    pfxPath: String,
    pfxPassword: String
) -> SigningConfiguration {
    SigningConfiguration(
        credentials: .pkcs12(path: URL(fileURLWithPath: pfxPath), passwordProvider: { pfxPassword })
    )
}

private func writePrintAndSubmit(
    _ signed: SignedCPE,
    emitterRUC: String,
    label: String
) async throws -> SunatBillSubmissionResult {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-CreditNote-Beta-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let document = try CPEDocumentWriter().write(
        signed,
        output: CPEOutputConfiguration(rootDirectory: directory)
    )
    print("""

    ===== SUNAT BETA \(label): XML FIRMADO =====
    Archivo XML: \(document.signedXMLURL.lastPathComponent)
    Archivo ZIP: \(document.zipURL.lastPathComponent)
    \(String(decoding: signed.xml, as: UTF8.self))
    ===== FIN SUNAT BETA \(label): XML FIRMADO =====

    """)
    let result = try await submitCreditNoteScenarioToSunatBeta(
        document: document,
        emitterRUC: emitterRUC,
        label: label
    )
    print("""

    ===== SUNAT BETA \(label): RESPUESTA =====
    Estado: \(result.status)
    Código: \(result.responseCode)
    Descripciones: \(result.descriptions)
    Observaciones: \(result.observations)
    ===== FIN SUNAT BETA \(label): RESPUESTA =====

    """)
    return result
}

/// SUNAT BETA puede devolver HTTP 401 cuando se realizan autenticaciones
/// MODDATOS consecutivas. Este reintento pertenece únicamente al test de
/// integración; la librería continúa entregando el error original al POS.
private func submitCreditNoteScenarioToSunatBeta(
    document: CPEDocument,
    emitterRUC: String,
    label: String
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
            print("SUNAT BETA \(label): HTTP 401, reintento \(attempt + 1)/\(maximumAttempts)")
            try await Task.sleep(for: .seconds(2))
        }
    }

    preconditionFailure("El bucle de reintentos debe devolver o lanzar un error.")
}

private enum CreditNoteIntegrationError: Error {
    case missingSigningCredentials
    case prerequisiteInvoiceWasNotAccepted
}
