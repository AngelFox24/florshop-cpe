import Foundation
import Testing
import ZIPFoundation
@testable import FlorShopCPE

@Test func facturaModelRetainsItsDomainData() {
    let factura = makeFactura()

    #expect(factura.identifier.value == "F001-1137")
    #expect(factura.identifier.type == .factura)
    #expect(factura.customer.identifier.documentType == .ruc)
    #expect(factura.customer.address?.district == "ATE")
    #expect(factura.lines.count == 1)
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
    #expect(xml.contains("<cbc:PayableAmount currencyID=\"PEN\">1328.74</cbc:PayableAmount>"))
    #expect(xml.contains("<cbc:Description>COLA ENTOMOLÓGICA K-GLUE X 1 LT</cbc:Description>"))
    #expect(xml.hasSuffix("</Invoice>"))
}

@Test func facturaValidatorRequiresFacturaDocumentType() {
    let factura = makeFactura(
        identifier: DocumentIdentifier(series: "F001", number: "1137", type: .boleta)
    )

    #expect(throws: UBLInvoiceDocumentValidationError.unexpectedDocumentType(
        expected: .factura,
        actual: .boleta
    )) {
        try UBLInvoiceDocumentValidator().validate(factura)
    }
}

@Test func facturaValidatorRequiresFSeries() {
    let factura = makeFactura(
        identifier: DocumentIdentifier(series: "B001", number: "1137", type: .factura)
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
}

@Test func genericSignerValidatesFacturaBeforeReadingCertificate() {
    let configuration = SigningConfiguration(
        signature: SignatureInformation(
            identifier: "F001-1137",
            signatoryIdentifier: "20566331030",
            signatoryName: "NKR PROFESSIONAL PRODUCTS S.A.C.",
            uri: "SignSUNAT"
        ),
        credentials: .pkcs12(
            path: URL(fileURLWithPath: "/not-used.pfx"),
            passwordProvider: { "" }
        )
    )

    #expect(throws: CPESigningError.invalidSignatureURI) {
        try XMLSecCPESigner().sign(makeFactura(), configuration: configuration)
    }
}

/// Integración local opcional; no se comunica con SUNAT.
@Test func genericSignerSignsAndVerifiesFacturaWhenCertificateIsConfigured() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let certificatePath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
          let certificatePassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else {
        return
    }
    let configuration = SigningConfiguration(
        signature: SignatureInformation(
            identifier: "F001-1137",
            signatoryIdentifier: "20566331030",
            signatoryName: "NKR PROFESSIONAL PRODUCTS S.A.C.",
            uri: "#SignSUNAT"
        ),
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
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION_FACTURA"] == "true" else {
            return
        }
        guard let certificatePath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
              let certificatePassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else {
            throw FacturaIntegrationConfigurationError.missingSigningCredentials
        }

        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("FlorShopCPE-Factura-Beta-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        // Se usa la factura mínima para aislar la integración de los bloques
        // opcionales de factoring, retención y referencias comerciales.
        let factura = makeFacturaForSunatBeta()
        let emitterRUC = factura.supplier.taxIdentifier.value
        let configuration = SigningConfiguration(
            signature: SignatureInformation(
                identifier: factura.identifier.value,
                signatoryIdentifier: emitterRUC,
                signatoryName: factura.supplier.legalName,
                uri: "#SignSUNAT"
            ),
            credentials: .pkcs12(
                path: URL(fileURLWithPath: certificatePath),
                passwordProvider: { certificatePassword }
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

        ===== SUNAT BETA FACTURA: XML FIRMADO =====
        Archivo XML: \(document.signedXMLURL.lastPathComponent)
        Archivo ZIP: \(document.zipURL.lastPathComponent)
        Tipo de operación esperado: \(factura.operationTypeCode)
        Tipo de documento esperado: \(factura.identifier.type.rawValue)
        \(signedXML)
        ===== FIN SUNAT BETA FACTURA: XML FIRMADO =====

        """)

        let result = try await submitFacturaToSunatBeta(
            document: document,
            emitterRUC: emitterRUC
        )

        #expect(result.status == .accepted)
        #expect(result.responseCode == "0")
        #expect(result.observations.isEmpty)
        #expect(!result.cdrArchive.isEmpty)
        #expect(!result.cdrXML.isEmpty)
        #expect(result.cdrArtifacts != nil)
    }
}

private func makeFactura(
    identifier: DocumentIdentifier = DocumentIdentifier(
        series: "F001",
        number: "1137",
        type: .factura
    ),
    customer: Customer = Customer(
        identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
        legalName: "CENCOSUD RETAIL PERU S.A.",
        address: Address(
            ubigeoCode: "150103",
            addressTypeCode: "0",
            city: "LIMA",
            department: "LIMA",
            district: "ATE",
            line: "AV. NICOLAS AYLLON 4297"
        )
    ),
    issueDate: IssueDate = IssueDate(year: 2026, month: 7, day: 21),
    includeCommercialTerms: Bool = true,
    emitterRUC: String = "20566331030",
    paymentTerms: [PaymentTerm]? = nil
) -> Factura {
    let currency = CurrencyCode.pen
    let taxableAmount = MonetaryAmount(value: Decimal(string: "1126.05")!, currency: currency)
    let taxAmount = MonetaryAmount(value: Decimal(string: "202.69")!, currency: currency)
    let payableAmount = MonetaryAmount(value: Decimal(string: "1328.74")!, currency: currency)
    let category = TaxCategory(
        percent: 18,
        exemptionReasonCode: .gravadoOperacionOnerosa,
        scheme: .igv
    )

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
                addressTypeCode: "0",
                city: "LIMA",
                department: "LIMA",
                district: "SAN BORJA",
                line: "CAL. PABLO USANDIZAGA 670"
            )
        ),
        customer: customer,
        taxTotal: TaxTotal(
            amount: taxAmount,
            subtotals: [
                TaxSubtotal(
                    taxableAmount: taxableAmount,
                    taxAmount: taxAmount,
                    scheme: .igv
                )
            ]
        ),
        monetaryTotal: MonetaryTotal(
            lineExtensionAmount: taxableAmount,
            taxInclusiveAmount: payableAmount,
            payableAmount: payableAmount
        ),
        lines: [
            InvoiceLine(
                id: "1",
                quantity: Quantity(value: 15, unitCode: .unit),
                lineExtensionAmount: taxableAmount,
                alternativePrices: [
                    AlternativePrice(
                        amount: MonetaryAmount(
                            value: Decimal(string: "88.5826")!,
                            currency: currency
                        ),
                        type: .unitPriceIncludingTaxes
                    )
                ],
                taxTotal: LineTaxTotal(
                    amount: taxAmount,
                    subtotals: [
                        LineTaxSubtotal(
                            taxableAmount: taxableAmount,
                            taxAmount: taxAmount,
                            category: category
                        )
                    ]
                ),
                item: Item(description: "COLA ENTOMOLÓGICA K-GLUE X 1 LT"),
                price: MonetaryAmount(value: Decimal(string: "75.07")!, currency: currency)
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
        paymentTerms: paymentTerms ?? (includeCommercialTerms ? [
            PaymentTerm(paymentMeansID: "Credito", amount: payableAmount),
            PaymentTerm(
                paymentMeansID: "Cuota001",
                amount: payableAmount,
                dueDate: IssueDate(year: 2026, month: 8, day: 10)
            )
        ] : []),
        allowanceCharges: includeCommercialTerms ? [
            AllowanceCharge(
                isCharge: false,
                reasonCode: "62",
                multiplierFactor: Decimal(string: "0.03")!,
                amount: MonetaryAmount(value: Decimal(string: "39.86")!, currency: currency),
                baseAmount: payableAmount
            )
        ] : []
    )
}

private func makeFacturaForSunatBeta() -> Factura {
    let now = Date()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Lima")!
    let components = calendar.dateComponents([.year, .month, .day], from: now)
    let issueDate = IssueDate(
        year: components.year!,
        month: components.month!,
        day: components.day!
    )
    let correlativo = max(1, Int(now.timeIntervalSince1970) % 100_000_000)

    return makeFactura(
        identifier: DocumentIdentifier(
            series: "F001",
            number: String(correlativo),
            type: .factura
        ),
        issueDate: issueDate,
        includeCommercialTerms: false,
        emitterRUC: "10708255195",
        paymentTerms: [
            PaymentTerm(paymentMeansID: "Contado")
        ]
    )
}

private enum FacturaIntegrationConfigurationError: Error {
    case missingSigningCredentials
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
