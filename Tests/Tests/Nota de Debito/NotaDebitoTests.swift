import Foundation
import Testing
@testable import FlorShopCPE

@Test func debitNoteAssignsSequentialLineIdentifiers() {
    let lines = [
        DebitNoteLine(
            quantity: .units(1),
            pricing: .taxed(11.80),
            item: Item(description: "PRODUCTO")
        ),
        DebitNoteLine(
            pricing: .taxed(5.90),
            item: Item(description: "PENALIDAD")
        )
    ]

    let note = makeDebitNote(lines: lines)

    #expect(note.lines.map(\.id) == ["1", "2"])
}

@Test func debitNoteCatalog10ContainsCurrentSUNATReasons() {
    #expect(Set(DebitNoteReasonCode.allCases.map(\.rawValue)) == Set(["01", "02", "03", "12", "13"]))
}

@Test func debitNoteModelAndTransformerGenerateUBL21() throws {
    let note = makeDebitNote()
    let xml = try DebitNoteXMLTransformer().transform(note)

    #expect(note.identifier.value == "FD01-200")
    #expect(note.documentType == .notaDeDebito)
    #expect(note.affectedDocument.value == "F001-100")
    #expect(note.reasonDescription == "AUMENTO EN EL VALOR")
    #expect(xml.contains("<DebitNote"))
    #expect(xml.contains("xmlns=\"urn:oasis:names:specification:ubl:schema:xsd:DebitNote-2\""))
    #expect(xml.contains("<cbc:UBLVersionID>2.1</cbc:UBLVersionID>"))
    #expect(xml.contains("<cbc:CustomizationID>2.0</cbc:CustomizationID>"))
    #expect(xml.contains("<cbc:ReferenceID>F001-100</cbc:ReferenceID>"))
    #expect(xml.contains(">02</cbc:ResponseCode>"))
    #expect(xml.contains("catalogo10"))
    #expect(xml.contains("<cbc:Description>AUMENTO EN EL VALOR</cbc:Description>"))
    #expect(xml.contains("<cbc:Note languageLocaleID=\"1000\">SON ONCE CON 80/100 SOLES</cbc:Note>"))
    #expect(xml.contains("<cac:InvoiceDocumentReference>"))
    #expect(xml.contains(">01</cbc:DocumentTypeCode>"))
    #expect(xml.contains("<cac:RequestedMonetaryTotal>"))
    #expect(!xml.contains("<cac:LegalMonetaryTotal>"))
    #expect(xml.contains("<cac:DebitNoteLine>"))
    #expect(xml.contains("<cbc:DebitedQuantity"))
    #expect(xml.contains(">1</cbc:DebitedQuantity>"))
    #expect(xml.contains("<cbc:PayableAmount currencyID=\"PEN\">11.80</cbc:PayableAmount>"))
    #expect(xml.hasSuffix("</DebitNote>"))
}

@Test func debitNoteTransformerOmitsOptionalQuantityAndPrice() throws {
    let note = makeDebitNote(includeQuantityAndPrice: false)
    let xml = try DebitNoteXMLTransformer().transform(note)

    #expect(!xml.contains("<cbc:DebitedQuantity"))
    #expect(!xml.contains("<cac:Price>"))
    #expect(xml.contains("<cbc:LineExtensionAmount currencyID=\"PEN\">10.00</cbc:LineExtensionAmount>"))
}

@Test func debitNoteValidatorRequiresSeriesMatchingAffectedDocument() {
    let note = makeDebitNote(
        identifier: DocumentIdentifier(series: "BD01", number: "200")
    )

    #expect(throws: DebitNoteValidationError.invalidSeries(expectedPrefix: "F")) {
        try DebitNoteValidator().validate(note)
    }
}

@Test func debitNoteValidatorRejectsInvoiceCustomerWithoutRUC() {
    let note = makeDebitNote(customer: Customer(
        identifier: PartyIdentifier(value: "46237547", documentType: .dni),
        legalName: "CLIENTE"
    ))

    #expect(throws: DebitNoteValidationError.facturaCustomerMustHaveRUC) {
        try DebitNoteValidator().validate(note)
    }
}

@Test func debitNoteValidatorRejectsLineBreaksInReason() {
    let note = makeDebitNote(reasonDescription: "AUMENTO EN EL VALOR DEL PRODUCTO\n")

    #expect(throws: DebitNoteValidationError.invalidReasonDescriptionWhitespace) {
        try DebitNoteValidator().validate(note)
    }
}

@Test func debitNoteValidatorCountsTheCompleteReasonDescription() {
    let note = makeDebitNote(reasonDescription: String(repeating: "A", count: 501))

    #expect(throws: DebitNoteValidationError.reasonDescriptionTooLong) {
        try DebitNoteValidator().validate(note)
    }
}

@Test func debitNoteValidatorRequiresSupplierEstablishmentCode() {
    let supplier = Supplier(
        taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
        legalName: "EMISOR S.A.C.",
        address: Address(
            ubigeoCode: "150130",
            city: "LIMA",
            department: "LIMA",
            district: "SAN BORJA",
            line: "CAL. PABLO USANDIZAGA 670"
        )
    )
    let note = makeDebitNote(supplier: supplier)

    #expect(throws: DebitNoteValidationError.missingSupplierAddressTypeCode) {
        try DebitNoteValidator().validate(note)
    }
}

@Test func debitNoteForBoletaBecomesDailySummaryLine08() throws {
    let note = makeDebitNoteForBoleta()
    let summary = try ResumenDiarioBoletas(
        sequence: 1,
        issueDate: note.issueDate,
        entries: [.debitNote(note)]
    )
    let line = try #require(summary.lines.first)
    let xml = try DailySummaryXMLTransformer().transform(summary)

    #expect(line.documentType == .notaDeDebito)
    #expect(line.documentIdentifier.value == "BD01-200")
    #expect(line.affectedDocument?.value == "B001-100")
    #expect(line.totalAmount.value == 11.80)
    #expect(line.sales.first(where: { $0.type == .taxable })?.amount.value == 10)
    #expect(xml.contains("<cbc:DocumentTypeCode>08</cbc:DocumentTypeCode>"))
    #expect(xml.contains("<cbc:ID>BD01-200</cbc:ID>"))
    #expect(xml.contains("<cbc:ID>B001-100</cbc:ID>"))
    #expect(xml.contains("<cbc:DocumentTypeCode>03</cbc:DocumentTypeCode>"))
}

@Test func invoiceDebitNoteCannotBecomeDailySummaryLine() {
    #expect(throws: DailySummaryValidationError.invalidAffectedDocument(1)) {
        _ = try DailySummaryLine(lineID: 1, debitNote: makeDebitNote())
    }
}

@Test func debitNoteUsesSUNATFileIdentityAndSharedWriter() throws {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-DebitNote-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directory) }
    let note = makeDebitNote()
    let identity = CPEIdentity(debitNote: note)
    let document = try CPEDocumentWriter().write(
        SignedCPE(xml: Data("<DebitNote />".utf8), identity: identity),
        output: CPEOutputConfiguration(rootDirectory: directory)
    )

    #expect(identity.fileBaseName == "10708255195-08-FD01-200")
    #expect(document.signedXMLURL.lastPathComponent == "10708255195-08-FD01-200.xml")
    #expect(document.zipURL.lastPathComponent == "10708255195-08-FD01-200.zip")
    #expect(try SunatBillPackageValidator().validate(zipAt: document.zipURL).xmlEntryName == "10708255195-08-FD01-200.xml")
}

@Test func debitNoteTransformerInfersSignatureMetadata() throws {
    let xml = try DebitNoteXMLTransformer().transform(makeDebitNote())

    #expect(xml.contains("<cac:Signature>"))
    #expect(xml.contains("<cbc:URI>#SignSUNAT</cbc:URI>"))
    #expect(xml.contains("<cbc:ID>10708255195</cbc:ID>"))
}

@Test func debitNoteSignerSignsAndVerifiesWhenCertificateIsConfigured() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let path = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
          let password = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else { return }
    let note = makeDebitNote()
    let signed = try XMLSecCPESigner().sign(
        note,
        configuration: SigningConfiguration(
            credentials: .pkcs12(path: URL(fileURLWithPath: path), passwordProvider: { password })
        )
    )

    #expect(signed.identity.fileBaseName == "10708255195-08-FD01-200")
    #expect(try XMLSecSignatureVerifier().verify(signed.xml))
}

@Suite(.serialized)
struct SunatBetaDebitNoteIntegrationTests {
    /// Crea primero la factura afectada y luego envía su Nota de Débito.
    /// Solo se ejecuta con `FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION_NOTA_DEBITO=true`.
    @Test func sunatBetaAcceptsSignedInvoiceDebitNoteWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION_NOTA_DEBITO"] == "true" else { return }
        guard let pfxPath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
              let pfxPassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else {
            throw DebitNoteIntegrationError.missingSigningCredentials
        }

        let issueDate = currentLimaDebitNoteDate()
        let base = timestampBasedNumber(modulo: 99_999_990)
        let invoice = makeDebitNotePrerequisiteInvoice(number: String(base), issueDate: issueDate)
        let invoiceResult = try await signWriteAndSubmitDebitScenario(
            invoice,
            pfxPath: pfxPath,
            pfxPassword: pfxPassword,
            label: "FACTURA AFECTADA"
        )
        #expect(invoiceResult.status == .accepted)
        guard invoiceResult.status == .accepted else {
            throw DebitNoteIntegrationError.prerequisiteInvoiceWasNotAccepted
        }

        // El beta público puede tardar brevemente en registrar la factura y
        // rechazar una segunda autenticación MODDATOS demasiado próxima.
        try await Task.sleep(for: .seconds(2))

        let note = makeDebitNote(
            identifier: DocumentIdentifier(series: "FD01", number: String(base + 1)),
            affectedDocument: AffectedDocumentIdentifier(factura: invoice),
            issueDate: issueDate
        )
        let noteResult = try await signWriteAndSubmitDebitScenario(
            note,
            pfxPath: pfxPath,
            pfxPassword: pfxPassword,
            label: "NOTA DE DÉBITO"
        )

        #expect(noteResult.status == .accepted)
        #expect(noteResult.responseCode == "0")
        #expect(noteResult.observations.isEmpty)
        #expect(noteResult.cdrArtifacts != nil)
    }
}

@Suite(.serialized)
struct OSEDebitNoteManualValidationTests {
    /// Firma e imprime una factura y su Nota de Débito para copiarlas
    /// manualmente al OSE, en ese orden. No realiza llamadas de red ni escribe
    /// archivos XML o ZIP.
    @Test func printsSignedInvoiceAndDebitNoteXMLForOSE() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let pfxPath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
              let pfxPassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else { return }

        let issueDate = currentLimaDebitNoteDate()
        let base = timestampBasedNumber(modulo: 99_999_990)
        let invoice = makeDebitNotePrerequisiteInvoice(number: String(base), issueDate: issueDate)
        let note = makeDebitNote(
            identifier: DocumentIdentifier(series: "FD01", number: String(base + 1)),
            affectedDocument: AffectedDocumentIdentifier(factura: invoice),
            issueDate: issueDate
        )
        let signer = XMLSecCPESigner()

        let signedInvoice = try signer.sign(
            invoice,
            configuration: debitNoteSigningConfiguration(
                pfxPath: pfxPath,
                pfxPassword: pfxPassword
            )
        )
        let signedNote = try signer.sign(
            note,
            configuration: debitNoteSigningConfiguration(
                pfxPath: pfxPath,
                pfxPassword: pfxPassword
            )
        )

        print("""

        ===== XML FIRMADOS PARA VALIDACIÓN MANUAL EN OSE =====

        PASO 1 — Enviar y obtener aceptación de la factura:
        \(String(decoding: signedInvoice.xml, as: UTF8.self))

        PASO 2 — Solo después, enviar la Nota de Débito:
        Documento afectado: \(note.affectedDocument.value)
        \(String(decoding: signedNote.xml, as: UTF8.self))
        ===== FIN XML FIRMADOS PARA VALIDACIÓN MANUAL EN OSE =====

        """)

        #expect(note.affectedDocument.identifier == invoice.identifier)
        #expect(signedInvoice.identity.fileBaseName == "10708255195-01-\(invoice.identifier.value)")
        #expect(signedNote.identity.fileBaseName == "10708255195-08-\(note.identifier.value)")
        #expect(try XMLSecSignatureVerifier().verify(signedInvoice.xml))
        #expect(try XMLSecSignatureVerifier().verify(signedNote.xml))
    }
}

private func makeDebitNote(
    identifier: DocumentIdentifier = DocumentIdentifier(series: "FD01", number: "200"),
    affectedDocument: AffectedDocumentIdentifier = AffectedDocumentIdentifier(
        series: "F001",
        number: "100",
        type: .factura
    ),
    supplier: Supplier = debitNoteSupplier(),
    customer: Customer = Customer(
        identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
        legalName: "CLIENTE S.A.C."
    ),
    reason: DebitNoteReasonCode = .aumentoEnElValor,
    reasonDescription: String? = nil,
    issueDate: IssueDate = IssueDate(year: 2026, month: 8, day: 2),
    includeQuantityAndPrice: Bool = true,
    lines: [DebitNoteLine]? = nil
) -> NotaDebito {
    let values = debitNoteValues(includeQuantityAndPrice: includeQuantityAndPrice)
    return NotaDebito(
        identifier: identifier,
        issueDate: issueDate,
        issueTime: IssueTime(hour: 12, minute: 0),
        currency: .pen,
        supplier: supplier,
        customer: customer,
        affectedDocument: affectedDocument,
        reasonCode: reason,
        reasonDescription: reasonDescription,
        lines: lines ?? [values.line]
    )
}

private func makeDebitNoteForBoleta() -> NotaDebito {
    makeDebitNote(
        identifier: DocumentIdentifier(series: "BD01", number: "200"),
        affectedDocument: AffectedDocumentIdentifier(
            series: "B001",
            number: "100",
            type: .boleta
        ),
        customer: Customer(
            identifier: PartyIdentifier(value: "46237547", documentType: .dni),
            legalName: "CLIENTE"
        )
    )
}

private func debitNoteSupplier() -> Supplier {
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

private func debitNoteValues(
    includeQuantityAndPrice: Bool = true
) -> (payable: MonetaryAmount, line: DebitNoteLine) {
    let payable = MonetaryAmount(value: 11.80)
    let item = Item(description: "AUMENTO EN EL VALOR DEL PRODUCTO", sellerItemIdentifier: "P001")
    let line = includeQuantityAndPrice
        ? DebitNoteLine(
            quantity: .units(1),
            pricing: .taxed(10, basis: .excludingTaxes),
            item: item
        )
        : DebitNoteLine(pricing: .taxed(10, basis: .excludingTaxes), item: item)
    return (payable, line)
}

private func makeDebitNotePrerequisiteInvoice(number: String, issueDate: IssueDate) -> Factura {
    let line = InvoiceLine(
        id: "1",
        quantity: .units(1),
        pricing: .taxed(100, basis: .excludingTaxes),
        item: Item(description: "PRODUCTO", sellerItemIdentifier: "P001")
    )
    return Factura(
        identifier: DocumentIdentifier(series: "F001", number: number),
        issueDate: issueDate,
        issueTime: IssueTime(hour: 12, minute: 0),
        currency: .pen,
        supplier: debitNoteSupplier(),
        customer: Customer(
            identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
            legalName: "CLIENTE S.A.C."
        ),
        lines: [line],
        paymentCondition: .cash
    )
}

private func currentLimaDebitNoteDate() -> IssueDate {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Lima")!
    let values = calendar.dateComponents([.year, .month, .day], from: Date())
    return IssueDate(year: values.year!, month: values.month!, day: values.day!)
}

private func signWriteAndSubmitDebitScenario(
    _ invoice: Factura,
    pfxPath: String,
    pfxPassword: String,
    label: String
) async throws -> SunatBillSubmissionResult {
    let signed = try XMLSecCPESigner().sign(
        invoice,
        configuration: debitNoteSigningConfiguration(
            pfxPath: pfxPath,
            pfxPassword: pfxPassword
        )
    )
    return try await writePrintAndSubmitDebitScenario(
        signed,
        emitterRUC: invoice.supplier.taxIdentifier.value,
        label: label
    )
}

private func signWriteAndSubmitDebitScenario(
    _ note: NotaDebito,
    pfxPath: String,
    pfxPassword: String,
    label: String
) async throws -> SunatBillSubmissionResult {
    let signed = try XMLSecCPESigner().sign(
        note,
        configuration: debitNoteSigningConfiguration(
            pfxPath: pfxPath,
            pfxPassword: pfxPassword
        )
    )
    return try await writePrintAndSubmitDebitScenario(
        signed,
        emitterRUC: note.supplier.taxIdentifier.value,
        label: label
    )
}

private func debitNoteSigningConfiguration(
    pfxPath: String,
    pfxPassword: String
) -> SigningConfiguration {
    SigningConfiguration(
        credentials: .pkcs12(path: URL(fileURLWithPath: pfxPath), passwordProvider: { pfxPassword })
    )
}

private func writePrintAndSubmitDebitScenario(
    _ signed: SignedCPE,
    emitterRUC: String,
    label: String
) async throws -> SunatBillSubmissionResult {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-DebitNote-Beta-\(UUID().uuidString)", isDirectory: true)
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
    let result = try await submitDebitNoteScenarioToSunatBeta(
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
private func submitDebitNoteScenarioToSunatBeta(
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

private enum DebitNoteIntegrationError: Error {
    case missingSigningCredentials
    case prerequisiteInvoiceWasNotAccepted
}
