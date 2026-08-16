import Foundation
import Testing
import ZIPFoundation
@testable import FlorShopCPE

@Test func facturaModelRetainsItsDomainData() {
    let factura = makeFactura()

    #expect(factura.identifier.value == "F001-1137")
    #expect(factura.documentType == .factura)
    #expect(factura.customer.identifier.documentType == .ruc)
    #expect(factura.customer.address?.district == "ATE")
    #expect(factura.lines.count == 1)
    #expect(factura.lines[0].id == "1")
}

@Test func facturaTransformerGeneratesUBLInvoiceXML() throws {
    let xml = try UBLInvoiceXMLTransformer().transform(makeFactura())

    #expect(xml.contains("<cbc:ID>F001-1137</cbc:ID>"))
    #expect(xml.contains("<cbc:ProfileID"))
    #expect(xml.contains(">0101</cbc:ProfileID>"))
    #expect(xml.contains("<cbc:InvoiceTypeCode"))
    #expect(xml.contains("listID=\"0101\""))
    #expect(xml.contains("listSchemeURI=\"urn:pe:gob:sunat:cpe:see:gem:catalogos:catalogo51\""))
    #expect(xml.contains(">01</cbc:InvoiceTypeCode>"))
    #expect(xml.contains("<cbc:DocumentCurrencyCode>PEN</cbc:DocumentCurrencyCode>"))
    #expect(xml.contains("<cac:OrderReference>"))
    #expect(xml.contains("<cbc:ID>4301113494</cbc:ID>"))
    #expect(xml.contains("<cbc:DocumentTypeCode>09</cbc:DocumentTypeCode>"))
    #expect(xml.contains("<cbc:ID schemeID=\"6\">20109072177</cbc:ID>"))
    #expect(xml.contains("<cbc:RegistrationName>CENCOSUD RETAIL PERU S.A.</cbc:RegistrationName>"))
    #expect(xml.contains("<cbc:District>ATE</cbc:District>"))
    #expect(xml.contains("<cbc:PaymentMeansID>Credito</cbc:PaymentMeansID>"))
    #expect(xml.contains("<cbc:PaymentMeansID>Cuota001</cbc:PaymentMeansID>"))
    #expect(xml.contains("<cbc:PaymentDueDate>2026-08-10</cbc:PaymentDueDate>"))
    #expect(xml.contains("<cbc:AllowanceChargeReasonCode>62</cbc:AllowanceChargeReasonCode>"))
    #expect(xml.contains("<cbc:PayableAmount currencyID=\"PEN\">1288.88</cbc:PayableAmount>"))
    #expect(xml.contains("<cbc:Description>COLA ENTOMOLÓGICA K-GLUE X 1 LT</cbc:Description>"))
    #expect(xml.hasSuffix("</Invoice>"))
}

@Test func facturaPropagatesItsCurrencyToEveryMonetaryAmount() throws {
    let xml = try UBLInvoiceXMLTransformer().transform(makeFactura(currency: .usd))

    #expect(xml.contains("<cbc:DocumentCurrencyCode>USD</cbc:DocumentCurrencyCode>"))
    #expect(xml.contains("currencyID=\"USD\""))
    #expect(!xml.contains("currencyID=\"PEN\""))
    #expect(!xml.contains("currencyID=\"EUR\""))
}

@Test func facturaGeneratesSequentialSUNATInstallmentIdentifiers() throws {
    let condition = PaymentCondition.credit(
        installments: [
            PaymentInstallment(
                amount: MonetaryAmount(value: 600),
                dueDate: IssueDate(year: 2026, month: 8, day: 10)
            ),
            PaymentInstallment(
                amount: MonetaryAmount(value: 688.88),
                dueDate: IssueDate(year: 2026, month: 9, day: 10)
            )
        ]
    )

    let xml = try UBLInvoiceXMLTransformer().transform(
        makeFactura(paymentCondition: condition)
    )

    #expect(xml.contains("<cbc:PaymentMeansID>Credito</cbc:PaymentMeansID>"))
    #expect(xml.contains("<cbc:PaymentMeansID>Cuota001</cbc:PaymentMeansID>"))
    #expect(xml.contains("<cbc:PaymentMeansID>Cuota002</cbc:PaymentMeansID>"))
    #expect(!xml.contains("<cbc:PaymentMeansID>Cuota003</cbc:PaymentMeansID>"))
}

@Test func facturaRejectsInstallmentsThatDoNotMatchThePendingAmount() {
    let condition = PaymentCondition.credit(
        installments: [
            PaymentInstallment(
                amount: MonetaryAmount(value: 90),
                dueDate: IssueDate(year: 2026, month: 8, day: 10)
            )
        ]
    )

    #expect(throws: UBLInvoiceDocumentValidationError.paymentInstallmentsTotalMismatch) {
        try UBLInvoiceDocumentValidator().validate(
            makeFactura(paymentCondition: condition)
        )
    }
}

@Test func facturaValidatorRequiresFSeries() {
    let factura = makeFactura(
        identifier: DocumentIdentifier(series: "B001", number: "1137")
    )

    #expect(throws: UBLInvoiceDocumentValidationError.invalidSeries(expectedPrefix: "F")) {
        try UBLInvoiceDocumentValidator().validate(factura)
    }
}

@Test func facturaValidatorRequiresCustomerRUC() {
    let factura = makeFactura(
        customer: Customer(
            identifier: PartyIdentifier(value: "20203030", documentType: .dni),
            legalName: "PERSONA NATURAL"
        )
    )

    #expect(throws: UBLInvoiceDocumentValidationError.facturaCustomerMustHaveRUC) {
        try UBLInvoiceDocumentValidator().validate(factura)
    }
}

@Test func facturaUsesTheSUNATInvoiceFileIdentity() {
    let identity = CPEIdentity(document: makeFactura())

    #expect(identity.fileBaseName == "20566331030-01-F001-1137")
}

@Test func facturaCanUseTheSharedWriterAndPackager() throws {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-Factura-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directory) }

    let factura = makeFactura()
    let document = try CPEDocumentWriter().write(
        SignedCPE(
            xml: Data("<Invoice />".utf8),
            identity: CPEIdentity(document: factura)
        ),
        output: CPEOutputConfiguration(rootDirectory: directory)
    )

    #expect(document.signedXMLURL.lastPathComponent == "20566331030-01-F001-1137.xml")
    #expect(document.zipURL.lastPathComponent == "20566331030-01-F001-1137.zip")
    let archive = try Archive(url: document.zipURL, accessMode: .read)
    #expect(Array(archive).map(\.path) == ["20566331030-01-F001-1137.xml"])
}

@Test func sunatBetaFacturaFixtureIncludesCashPaymentTermsAndCertificateRUC() throws {
    let factura = makeFacturaForSunatBeta()
    let xml = try UBLInvoiceXMLTransformer().transform(factura)

    #expect(factura.supplier.taxIdentifier.value == "10708255195")
    #expect(xml.contains("<cbc:ID>FormaPago</cbc:ID>"))
    #expect(xml.contains("<cbc:PaymentMeansID>Contado</cbc:PaymentMeansID>"))
    #expect(xml.contains("<cbc:AddressTypeCode>0000</cbc:AddressTypeCode>"))
    #expect(!xml.contains("<cbc:AddressTypeCode>0</cbc:AddressTypeCode>"))
}

@Test func sunatBetaReferenceFacturaFixtureMatchesTheCommercialScenario() throws {
    let factura = makeReferenceFacturaForSunatBeta()
    let xml = try UBLInvoiceXMLTransformer().transform(factura)

    #expect(xml.contains("<cac:OrderReference>"))
    #expect(xml.contains("<cac:DespatchDocumentReference>"))
    #expect(xml.contains("<cac:BuyerCustomerParty>"))
    #expect(xml.contains("<cbc:PaymentMeansID>Credito</cbc:PaymentMeansID>"))
    #expect(xml.contains("<cbc:PaymentMeansID>Cuota001</cbc:PaymentMeansID>"))
    #expect(xml.contains("<cbc:Amount currencyID=\"PEN\">1328.74</cbc:Amount>"))
    #expect(!xml.contains("<cbc:AllowanceChargeReasonCode>62</cbc:AllowanceChargeReasonCode>"))
    #expect(xml.contains("<cbc:AddressTypeCode>0000</cbc:AddressTypeCode>"))
    #expect(!xml.contains("<cbc:AddressTypeCode>0</cbc:AddressTypeCode>"))
}

@Test func transformerInfersFacturaSignatureMetadata() throws {
    let xml = try UBLInvoiceXMLTransformer().transform(makeFactura())

    #expect(xml.contains("<cac:Signature>"))
    #expect(xml.contains("<cbc:URI>#SignSUNAT</cbc:URI>"))
    #expect(xml.contains("<cbc:ID>20566331030</cbc:ID>"))
}

/// Integración local opcional; no se comunica con SUNAT.
@Test func genericSignerSignsAndVerifiesFacturaWhenCertificateIsConfigured() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let certificatePath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
          let certificatePassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else {
        return
    }
    let configuration = SigningConfiguration(
        credentials: .pkcs12(
            path: URL(fileURLWithPath: certificatePath),
            passwordProvider: { certificatePassword }
        )
    )

    let signedFactura = try XMLSecCPESigner().sign(
        makeFactura(),
        configuration: configuration
    )

    #expect(signedFactura.identity.fileBaseName == "20566331030-01-F001-1137")
    #expect(try XMLSecSignatureVerifier().verify(signedFactura.xml))
}

/// Prueba manual de extremo a extremo contra SUNAT BETA para Factura.
///
/// Firma, escribe, comprime, envía mediante `sendBill` y valida el CDR. No
/// realiza ninguna llamada de red salvo que se configure explícitamente:
/// `FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION_FACTURA=true`.
@Suite(.serialized)
struct SunatBetaFacturaIntegrationTests {
    @Test func sunatBetaIntegrationAcceptsSignedFacturaWhenExplicitlyEnabled() async throws {
        guard let credentials = try facturaBetaCredentialsWhenEnabled() else {
            return
        }

        // Se usa la factura mínima para aislar la integración de los bloques
        // opcionales de factoring, retención y referencias comerciales.
        let factura = makeFacturaForSunatBeta()
        let result = try await signAndSubmitFacturaToSunatBeta(
            factura,
            scenario: "CONTADO MÍNIMO",
            credentials: credentials
        )

        #expect(result.status == .accepted)
        #expect(result.responseCode == "0")
        #expect(result.observations.isEmpty)
        #expect(!result.cdrArchive.isEmpty)
        #expect(!result.cdrXML.isEmpty)
        #expect(result.cdrArtifacts != nil)
    }

    /// Caso cercano al XML de referencia: orden de compra, guía, dirección
    /// para factoring, crédito y cuota. No incluye retención porque el RUC del
    /// certificado de pruebas figura como agente de retención.
    @Test func sunatBetaIntegrationAcceptsSignedReferenceFacturaWhenExplicitlyEnabled() async throws {
        guard let credentials = try facturaBetaCredentialsWhenEnabled() else {
            return
        }

        let factura = makeReferenceFacturaForSunatBeta()
        let result = try await signAndSubmitFacturaToSunatBeta(
            factura,
            scenario: "CRÉDITO COMPLETO COMO XML DE REFERENCIA",
            credentials: credentials
        )

        #expect(result.status == .accepted)
        #expect(result.responseCode == "0")
        #expect(!result.cdrArchive.isEmpty)
        #expect(!result.cdrXML.isEmpty)
        #expect(result.cdrArtifacts != nil)
    }
}

private func makeFactura(
    identifier: DocumentIdentifier = DocumentIdentifier(
        series: "F001",
        number: "1137"
    ),
    customer: Customer = Customer(
        identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
        legalName: "CENCOSUD RETAIL PERU S.A.",
        address: Address(
            ubigeoCode: "150103",
            city: "LIMA",
            department: "LIMA",
            district: "ATE",
            line: "AV. NICOLAS AYLLON 4297"
        )
    ),
    issueDate: IssueDate = IssueDate(year: 2026, month: 7, day: 21),
    currency: CurrencyCode = .pen,
    includeCommercialTerms: Bool = true,
    emitterRUC: String = "20566331030",
    paymentCondition: PaymentCondition? = nil,
    allowanceCharges: [AllowanceCharge]? = nil
) -> Factura {
    return Factura(
        identifier: identifier,
        issueDate: issueDate,
        issueTime: IssueTime(hour: 12, minute: 8, second: 4),
        currency: currency,
        supplier: Supplier(
            taxIdentifier: PartyIdentifier(value: emitterRUC, documentType: .ruc),
            commercialName: "NKR PRODUCTS",
            legalName: "NKR PROFESSIONAL PRODUCTS S.A.C.",
            address: Address(
                addressTypeCode: "0000",
                city: "LIMA",
                department: "LIMA",
                district: "SAN BORJA",
                line: "CAL. PABLO USANDIZAGA 670"
            )
        ),
        customer: customer,
        lines: [
            InvoiceLine(
                quantity: .units(15),
                pricing: .taxed(75.07, basis: .excludingTaxes),
                item: Item(description: "COLA ENTOMOLÓGICA K-GLUE X 1 LT")
            )
        ],
        orderReference: includeCommercialTerms ? "4301113494" : nil,
        despatchDocumentReferences: includeCommercialTerms ? [
            DocumentReference(
                identifier: "EG07-00000280",
                documentTypeCode: "09",
                documentTypeDescription: "GUIA DE REMISION REMITENTE"
            )
        ] : [],
        buyerAddress: includeCommercialTerms ? Address(
            ubigeoCode: "150122",
            city: "LIMA",
            department: "LIMA",
            district: "MIRAFLORES",
            line: "CAL. AUGUSTO ANGULO 130"
        ) : nil,
        paymentCondition: paymentCondition ?? (includeCommercialTerms ? .credit(
            installments: [
                PaymentInstallment(
                    amount: MonetaryAmount(value: 1288.88),
                    dueDate: IssueDate(year: 2026, month: 8, day: 10)
                )
            ]
        ) : .cash),
        allowanceCharges: allowanceCharges ?? (includeCommercialTerms ? [
            AllowanceCharge(
                isCharge: false,
                reasonCode: "62",
                multiplierFactor: 0.03,
                baseAmount: 1328.74
            )
        ] : [])
    )
}

private func makeFacturaForSunatBeta() -> Factura {
    return makeFactura(
        identifier: DocumentIdentifier(
            series: "F001",
            number: facturaBetaCorrelative(offset: 0)
        ),
        issueDate: limaIssueDate(),
        includeCommercialTerms: false,
        emitterRUC: "10708255195",
        paymentCondition: .cash
    )
}

private func makeReferenceFacturaForSunatBeta() -> Factura {
    return makeFactura(
        identifier: DocumentIdentifier(
            series: "F001",
            number: facturaBetaCorrelative(offset: 1)
        ),
        issueDate: limaIssueDate(),
        includeCommercialTerms: true,
        emitterRUC: "10708255195",
        paymentCondition: .credit(
            installments: [
                PaymentInstallment(
                    amount: MonetaryAmount(value: 1328.74),
                    dueDate: limaIssueDate(daysFromToday: 16)
                )
            ]
        ),
        allowanceCharges: []
    )
}

private func limaIssueDate(daysFromToday: Int = 0) -> IssueDate {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Lima")!
    let date = calendar.date(byAdding: .day, value: daysFromToday, to: Date())!
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return IssueDate(
        year: components.year!,
        month: components.month!,
        day: components.day!
    )
}

private func facturaBetaCorrelative(offset: Int) -> String {
    let maximumCorrelative = 99_999_999
    let timestamp = Int(Date().timeIntervalSince1970) % maximumCorrelative
    return String(max(1, (timestamp + offset) % maximumCorrelative))
}

private enum FacturaIntegrationConfigurationError: Error {
    case missingSigningCredentials
}

private struct FacturaBetaCredentials: Sendable {
    let certificatePath: String
    let certificatePassword: String
}

private func facturaBetaCredentialsWhenEnabled() throws -> FacturaBetaCredentials? {
    let environment = ProcessInfo.processInfo.environment
    guard environment["FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION_FACTURA"] == "true" else {
        return nil
    }
    guard let certificatePath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
          let certificatePassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else {
        throw FacturaIntegrationConfigurationError.missingSigningCredentials
    }
    return FacturaBetaCredentials(
        certificatePath: certificatePath,
        certificatePassword: certificatePassword
    )
}

private func signAndSubmitFacturaToSunatBeta(
    _ factura: Factura,
    scenario: String,
    credentials: FacturaBetaCredentials
) async throws -> SunatBillSubmissionResult {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-Factura-Beta-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directory) }

    let emitterRUC = factura.supplier.taxIdentifier.value
    let configuration = SigningConfiguration(
        credentials: .pkcs12(
            path: URL(fileURLWithPath: credentials.certificatePath),
            passwordProvider: { credentials.certificatePassword }
        )
    )
    let signedCPE = try XMLSecCPESigner().sign(
        factura,
        configuration: configuration
    )
    let document = try CPEDocumentWriter().write(
        signedCPE,
        output: CPEOutputConfiguration(
            rootDirectory: directory.appendingPathComponent("cpe")
        )
    )

    let signedXML = String(decoding: signedCPE.xml, as: UTF8.self)
    print("""

    ===== SUNAT BETA FACTURA \(scenario): XML FIRMADO =====
    Archivo XML: \(document.signedXMLURL.lastPathComponent)
    Archivo ZIP: \(document.zipURL.lastPathComponent)
    Tipo de operación esperado: 0101
    Tipo de documento esperado: \(factura.documentType.rawValue)
    \(signedXML)
    ===== FIN SUNAT BETA FACTURA \(scenario): XML FIRMADO =====

    """)

    let result = try await submitFacturaToSunatBeta(
        document: document,
        emitterRUC: emitterRUC
    )
    print("""

    ===== SUNAT BETA FACTURA \(scenario): RESPUESTA =====
    Estado: \(result.status)
    Código: \(result.responseCode)
    Descripciones: \(result.descriptions)
    Observaciones: \(result.observations)
    ===== FIN SUNAT BETA FACTURA \(scenario): RESPUESTA =====

    """)
    return result
}

/// SUNAT BETA puede responder 401 cuando MODDATOS recibe autenticaciones muy
/// próximas. Se reintenta solamente ese caso, igual que en la suite de Boleta.
private func submitFacturaToSunatBeta(
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
            try await Task.sleep(for: .seconds(2))
        }
    }

    preconditionFailure("El bucle de reintentos debe devolver o lanzar un error.")
}
