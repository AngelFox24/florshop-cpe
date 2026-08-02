import Foundation
import Testing
import ZIPFoundation
@testable import FlorShopCPE

@Test func boletaModelRetainsItsDomainData() {
    let amount = MonetaryAmount(value: 118, currency: .pen)
    let supplier = Supplier(
        taxIdentifier: PartyIdentifier(value: "20123456789", documentType: .ruc),
        legalName: "GREENTER S.A.C."
    )
    let customer = Customer(
        identifier: PartyIdentifier(value: "20203030", documentType: .dni),
        legalName: "PERSON 1"
    )
    let taxCategory = TaxCategory(
        percent: 18,
        exemptionReasonCode: .gravadoOperacionOnerosa,
        scheme: .igv
    )
    let taxTotal = TaxTotal(
        amount: MonetaryAmount(value: 18, currency: .pen),
        subtotals: [TaxSubtotal(
            taxableAmount: MonetaryAmount(value: 100, currency: .pen),
            taxAmount: MonetaryAmount(value: 18, currency: .pen),
            scheme: .igv
        )]
    )
    let lineTaxTotal = LineTaxTotal(
        amount: MonetaryAmount(value: 18, currency: .pen),
        subtotals: [LineTaxSubtotal(
            taxableAmount: MonetaryAmount(value: 100, currency: .pen),
            taxAmount: MonetaryAmount(value: 18, currency: .pen),
            category: taxCategory
        )]
    )
    let line = InvoiceLine(
        id: "1",
        quantity: Quantity(value: 2, unitCode: .unit),
        lineExtensionAmount: MonetaryAmount(value: 100, currency: .pen),
        alternativePrices: [AlternativePrice(amount: amount, type: .unitPriceIncludingTaxes)],
        taxTotal: lineTaxTotal,
        item: Item(description: "PROD 1", sellerItemIdentifier: "C023"),
        price: MonetaryAmount(value: 50, currency: .pen)
    )
    let boleta = Boleta(
        identifier: DocumentIdentifier(series: "B001", number: "1", type: .boleta),
        issueDate: IssueDate(year: 2020, month: 8, day: 19),
        currency: .pen,
        supplier: supplier,
        customer: customer,
        taxTotal: taxTotal,
        monetaryTotal: MonetaryTotal(
            lineExtensionAmount: MonetaryAmount(value: 100, currency: .pen),
            taxInclusiveAmount: amount,
            payableAmount: amount
        ),
        lines: [line]
    )
    
    #expect(boleta.identifier.value == "B001-1")
    #expect(boleta.lines.count == 1)
    #expect(boleta.taxTotal.subtotals.first?.scheme == .igv)
}

@Test func transformerGeneratesUBLInvoiceXML() {
    let currency: CurrencyCode = .pen
    let taxCategory = TaxCategory(percent: 18, exemptionReasonCode: .gravadoOperacionOnerosa, scheme: .igv)
    let taxTotal = TaxTotal(
        amount: MonetaryAmount(value: 18, currency: currency),
        subtotals: [TaxSubtotal(
            taxableAmount: MonetaryAmount(value: 100, currency: currency),
            taxAmount: MonetaryAmount(value: 18, currency: currency),
            scheme: .igv
        )]
    )
    let lineTaxTotal = LineTaxTotal(
        amount: MonetaryAmount(value: 18, currency: currency),
        subtotals: [LineTaxSubtotal(
            taxableAmount: MonetaryAmount(value: 100, currency: currency),
            taxAmount: MonetaryAmount(value: 18, currency: currency),
            category: taxCategory
        )]
    )
    let boleta = Boleta(
        identifier: DocumentIdentifier(series: "B001", number: "1", type: .boleta),
        issueDate: IssueDate(year: 2020, month: 8, day: 19),
        issueTime: IssueTime(hour: 3, minute: 16, second: 38),
        currency: currency,
        supplier: Supplier(
            taxIdentifier: PartyIdentifier(value: "20123456789", documentType: .ruc),
            commercialName: "GREENTER",
            legalName: "GREENTER S.A.C.",
            address: Address(
                ubigeoCode: "150101",
                addressTypeCode: "0000",
                urbanization: "CASUARINAS",
                city: "LIMA",
                department: "LIMA",
                district: "LIMA",
                line: "AV NEW DEÁL 123"
            ),
            contact: Contact(telephone: "01-234455", email: "admin@greenter.com")
        ),
        customer: Customer(identifier: PartyIdentifier(value: "20203030", documentType: .dni), legalName: "PERSON 1"),
        taxTotal: taxTotal,
        monetaryTotal: MonetaryTotal(
            lineExtensionAmount: MonetaryAmount(value: 100, currency: currency),
            taxInclusiveAmount: MonetaryAmount(value: 118, currency: currency),
            payableAmount: MonetaryAmount(value: 118, currency: currency)
        ),
        lines: [InvoiceLine(
            id: "1",
            quantity: Quantity(value: 2, unitCode: .unit),
            lineExtensionAmount: MonetaryAmount(value: 100, currency: currency),
            alternativePrices: [AlternativePrice(amount: MonetaryAmount(value: 59, currency: currency), type: .unitPriceIncludingTaxes)],
            taxTotal: lineTaxTotal,
            item: Item(description: "PROD & SERVICIO", sellerItemIdentifier: "C023"),
            price: MonetaryAmount(value: 50, currency: currency)
        )]
    )
    
    let xml = try! UBLInvoiceXMLTransformer().transform(boleta)
    #expect(xml.contains("<Invoice xmlns=\"urn:oasis:names:specification:ubl:schema:xsd:Invoice-2\""))
    #expect(xml.contains("<cbc:ID>B001-1</cbc:ID>"))
    #expect(xml.contains("<cbc:ProfileID"))
    #expect(xml.contains(">0101</cbc:ProfileID>"))
    #expect(xml.contains("<cbc:InvoiceTypeCode"))
    #expect(xml.contains("listID=\"0101\""))
    #expect(xml.contains(">03</cbc:InvoiceTypeCode>"))
    #expect(xml.contains("<cbc:Note languageLocaleID=\"1000\">SON CIENTO DIECIOCHO CON 00/100 SOLES</cbc:Note>"))
    #expect(xml.contains("<cbc:TaxAmount currencyID=\"PEN\">18.00</cbc:TaxAmount>"))
    #expect(xml.contains(
        "<cbc:ID schemeAgencyName=\"United Nations Economic Commission for Europe\" schemeID=\"UN/ECE 5305\" schemeName=\"Tax Category Identifier\">S</cbc:ID>"
    ))
    #expect(xml.contains("<cac:RegistrationAddress>"))
    #expect(xml.contains("<cbc:AddressTypeCode>0000</cbc:AddressTypeCode>"))
    #expect(xml.contains("<cbc:Line>AV NEW DEÁL 123</cbc:Line>"))
    #expect(xml.contains("<cbc:Telephone>01-234455</cbc:Telephone>"))
    #expect(xml.contains("<cbc:ElectronicMail>admin@greenter.com</cbc:ElectronicMail>"))
    #expect(xml.contains("<cbc:PayableAmount currencyID=\"PEN\">118.00</cbc:PayableAmount>"))
    #expect(xml.contains("<cbc:Description>PROD &amp; SERVICIO</cbc:Description>"))
    #expect(xml.hasSuffix("</Invoice>"))
}

@Test func amountInWordsFormatterGeneratesSpanishSUNATLegend() throws {
    let formatter = SpanishAmountInWordsFormatter()
    
    #expect(try formatter.format(Decimal(string: "0.00")!, currency: .pen) == "SON CERO CON 00/100 SOLES")
    #expect(try formatter.format(Decimal(string: "1.01")!, currency: .pen) == "SON UN CON 01/100 SOLES")
    #expect(try formatter.format(Decimal(string: "118.00")!, currency: .pen) == "SON CIENTO DIECIOCHO CON 00/100 SOLES")
    #expect(try formatter.format(Decimal(string: "1000000.50")!, currency: .usd) == "SON UN MILLÓN CON 50/100 DÓLARES AMERICANOS")
}

@Test func signerRejectsAnInvalidSignatureReferenceBeforeUsingTheCertificate() {
    let signer = XMLSecCPESigner()
    let configuration = SigningConfiguration(
        signature: SignatureInformation(
            identifier: "20123456789",
            signatoryIdentifier: "20123456789",
            signatoryName: "GREENTER S.A.C.",
            uri: "GREENTER-SIGN"
        ),
        credentials: .pkcs12(path: URL(fileURLWithPath: "/not-used.pfx"), passwordProvider: { "" })
    )
    
    #expect(throws: CPESigningError.invalidSignatureURI) {
        try signer.sign(makeBoleta(), configuration: configuration)
    }
}

/// Prueba de integración opcional. Para activarla, define ambas variables de entorno:
/// `FLORSHOP_CPE_TEST_PFX_PATH` y `FLORSHOP_CPE_TEST_PFX_PASSWORD`.
@Test func signerCreatesXMLDSIGWithConfiguredPKCS12Certificate() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let certificatePath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
          let certificatePassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else {
        return
    }
    
    let configuration = SigningConfiguration(
        signature: SignatureInformation(
            identifier: "20123456789",
            signatoryIdentifier: "20123456789",
            signatoryName: "GREENTER S.A.C.",
            uri: "#GREENTER-SIGN"
        ),
        credentials: .pkcs12(
            path: URL(fileURLWithPath: certificatePath),
            passwordProvider: { certificatePassword }
        )
    )
    
    let signedBoleta = try XMLSecCPESigner().sign(makeBoleta(), configuration: configuration)
    let signedXML = try #require(signedBoleta.xmlString)
    
    #expect(signedXML.contains("<cac:Signature>"))
    #expect(signedXML.contains("<ds:Signature"))
    #expect(signedXML.contains("Id=\"GREENTER-SIGN\""))
    #expect(signedXML.contains("<ds:SignatureValue>"))
    #expect(signedXML.contains("<ds:X509Certificate>"))
}

/// Prueba de integración opcional. Requiere las mismas variables de entorno que
/// `signerCreatesXMLDSIGWithConfiguredPKCS12Certificate`.
@Test func verifierAcceptsTheGeneratedXMLDSIG() throws {
    guard let configuration = integrationSigningConfiguration() else {
        return
    }
    
    let signedBoleta = try XMLSecCPESigner().sign(makeBoleta(), configuration: configuration)
    
    #expect(try XMLSecSignatureVerifier().verify(signedBoleta.xml))
}

/// Prueba de integración opcional. Requiere las mismas variables de entorno que
/// `signerCreatesXMLDSIGWithConfiguredPKCS12Certificate`.
@Test func verifierRejectsXMLModifiedAfterSigning() throws {
    guard let configuration = integrationSigningConfiguration() else {
        return
    }
    
    let signedBoleta = try XMLSecCPESigner().sign(makeBoleta(), configuration: configuration)
    let signedXML = try #require(signedBoleta.xmlString)
    let alteredXML = signedXML.replacingOccurrences(of: "PRODUCTO", with: "PRODUCTA")
    
    #expect(try !XMLSecSignatureVerifier().verify(Data(alteredXML.utf8)))
}

@Test func packagerCreatesZIPContainingOnlyTheSourceXML() throws {
    let fileManager = FileManager.default
    let directoryURL = fileManager.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-Packaging-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directoryURL) }
    
    let xmlURL = directoryURL.appendingPathComponent("20123456789-03-B001-1.xml")
    let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Invoice />"
    try Data(xml.utf8).write(to: xmlURL)
    
    let packaged = try XMLDocumentPackager().package(xmlAt: xmlURL)
    
    #expect(packaged.archiveURL.lastPathComponent == "20123456789-03-B001-1.zip")
    #expect(packaged.entryName == "20123456789-03-B001-1.xml")
    #expect(fileManager.fileExists(atPath: packaged.archiveURL.path))
    
    let archive = try Archive(url: packaged.archiveURL, accessMode: .read)
    let entry = try #require(archive[packaged.entryName])
    var extractedData = Data()
    _ = try archive.extract(entry) { extractedData.append($0) }
    
    #expect(String(data: extractedData, encoding: .utf8) == xml)
    #expect(Array(archive).count == 1)
}

@Test func documentWriterUsesTheSUNATNameAndConfiguredRootDirectory() throws {
    let fileManager = FileManager.default
    let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
    defer { try? fileManager.removeItem(at: directoryURL) }
    
    let output = CPEOutputConfiguration(
        rootDirectory: directoryURL.appendingPathComponent("cpe")
    )
    let boleta = makeBoleta()
    let document = try CPEDocumentWriter().write(
        SignedCPE(xml: Data("<Invoice />".utf8), identity: CPEIdentity(document: boleta)),
        output: output
    )
    
    #expect(document.signedXMLURL.lastPathComponent == "20123456789-03-B001-1.xml")
    #expect(document.zipURL.lastPathComponent == "20123456789-03-B001-1.zip")
    #expect(document.signedXMLURL.deletingLastPathComponent().lastPathComponent == "xml")
    #expect(document.zipURL.deletingLastPathComponent().lastPathComponent == "zip")
    #expect(document.cdrDirectory.lastPathComponent == "cdr")
    #expect(fileManager.fileExists(atPath: document.signedXMLURL.path))
    #expect(fileManager.fileExists(atPath: document.zipURL.path))
}

@Test func sunatBillPackageValidatorAcceptsTheExpectedZIPStructure() throws {
    let fileManager = FileManager.default
    let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
    defer { try? fileManager.removeItem(at: directoryURL) }
    
    let xmlURL = directoryURL.appendingPathComponent("20123456789-03-B001-1.xml")
    try Data("<Invoice />".utf8).write(to: xmlURL)
    let packagedXML = try XMLDocumentPackager().package(xmlAt: xmlURL)
    
    let package = try SunatBillPackageValidator().validate(zipAt: packagedXML.archiveURL)
    
    #expect(package.fileName == "20123456789-03-B001-1.zip")
    #expect(package.xmlEntryName == "20123456789-03-B001-1.xml")
}

@Test func transformerGeneratesUBLInvoiceXMLWithMultipleProducts() throws {
    let xml = try UBLInvoiceXMLTransformer().transform(makeBoletaWithMoreProducts())
    
    #expect(xml.components(separatedBy: "<cac:InvoiceLine>").count - 1 == 2)
    #expect(xml.contains("<cbc:ID>1</cbc:ID>"))
    #expect(xml.contains("<cbc:ID>2</cbc:ID>"))
    #expect(xml.contains("<cbc:Description>PRODUCTO 1</cbc:Description>"))
    #expect(xml.contains("<cbc:Description>PRODUCTO 2</cbc:Description>"))
    #expect(xml.contains("<cbc:TaxAmount currencyID=\"PEN\">27.00</cbc:TaxAmount>"))
    #expect(xml.contains("<cbc:PayableAmount currencyID=\"PEN\">177.00</cbc:PayableAmount>"))
}

@Test func referenceBoletaUsesTheFreeTaxSchemeForItsReferencePrice() throws {
    let xml = try UBLInvoiceXMLTransformer().transform(makeReferenceBoletaForSunatBeta())

    #expect(xml.contains("<cbc:PriceTypeCode>02</cbc:PriceTypeCode>"))
    #expect(xml.contains("<cbc:TaxExemptionReasonCode>31</cbc:TaxExemptionReasonCode>"))
    #expect(xml.contains("<cbc:TaxableAmount currencyID=\"PEN\">4.80</cbc:TaxableAmount>"))
    #expect(xml.contains(">Z</cbc:ID>"))
    #expect(xml.components(separatedBy: "<cbc:ID>9996</cbc:ID>").count - 1 == 2)
    #expect(xml.contains("<cbc:Name>GRA</cbc:Name>"))
    #expect(xml.contains("<cbc:TaxTypeCode>FRE</cbc:TaxTypeCode>"))
    #expect(xml.contains("<cbc:TaxAmount currencyID=\"PEN\">266.65</cbc:TaxAmount>"))
    #expect(xml.contains("<cbc:LineExtensionAmount currencyID=\"PEN\">1481.35</cbc:LineExtensionAmount>"))
    #expect(xml.contains("<cbc:LineExtensionAmount currencyID=\"PEN\">4.80</cbc:LineExtensionAmount>"))
    #expect(xml.contains("<cbc:PayableAmount currencyID=\"PEN\">1748.00</cbc:PayableAmount>"))
    #expect(xml.contains("<cbc:AddressTypeCode>0000</cbc:AddressTypeCode>"))
    #expect(!xml.contains("<cbc:AddressTypeCode>0014</cbc:AddressTypeCode>"))
    #expect(xml.contains("<cbc:Line>CAL. PABLO USANDIZAGA 670</cbc:Line>"))
}

@Test func sunatBetaBoletaFixturesUseCurrentDateAndCertificateRUC() {
    let expectedIssueDate = currentLimaIssueDateForBoleta()
    let fixtures = [
        makeBoletaForSunatBeta(),
        makeMultiProductBoletaForSunatBeta(),
        makeReferenceBoletaForSunatBeta()
    ]

    for boleta in fixtures {
        #expect(boleta.issueDate == expectedIssueDate)
        #expect(boleta.supplier.taxIdentifier.value == "10708255195")
        #expect(boleta.supplier.address?.addressTypeCode == "0000")
    }
    #expect(Set(fixtures.map(\.identifier.value)).count == fixtures.count)
}

@Test func boletaValidatorRejectsAnInvalidSupplierAddressTypeCode() {
    let boleta = makeBoleta(
        supplierAddress: Address(
            addressTypeCode: "0",
            line: "CAL. PABLO USANDIZAGA 670"
        )
    )

    #expect(throws: UBLInvoiceDocumentValidationError.invalidSupplierAddressTypeCode) {
        try UBLInvoiceDocumentValidator().validate(boleta)
    }
}

@Test func sunatBillClientSendsZIPAsSOAPBinaryContentAndReadsAcceptedCDR() async throws {
    let fileManager = FileManager.default
    let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
    defer { try? fileManager.removeItem(at: directoryURL) }
    
    let output = outputConfiguration(in: directoryURL)
    let boleta = makeBoleta(emitterRUC: "10708255195")
    let document = try CPEDocumentWriter().write(
        SignedCPE(xml: Data("<Invoice />".utf8), identity: CPEIdentity(document: boleta)),
        output: output
    )
    let transport = CapturingSunatHTTPTransport(response: try makeCDRResponse(
        directoryURL: directoryURL,
        responseCode: "0"
    ))
    
    let result = try await SunatBillClient(transport: transport).submit(
        document: document,
        credentials: .beta(emitterRUC: "10708255195")
    )
    let request = try #require(await transport.request)
    let body = try #require(request.httpBody)
    
    #expect(result.status == .accepted)
    #expect(result.responseCode == "0")
    #expect(request.url == SunatBillClient.betaEndpoint)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "text/xml; charset=UTF-8")
    #expect(request.value(forHTTPHeaderField: "SOAPAction") == "urn:sendBill")
    #expect(body.contains(Data("<wsse:Username>10708255195MODDATOS</wsse:Username>".utf8)))
    #expect(body.contains(Data("<fileName>10708255195-03-B001-1.zip</fileName>".utf8)))
    #expect(body.contains(Data("<contentFile>".utf8)))
    #expect(result.cdrArtifacts?.archiveURL.lastPathComponent == "R-10708255195-03-B001-1.zip")
    #expect(result.cdrArtifacts?.xmlURL.lastPathComponent == "R-10708255195-03-B001-1.xml")
    #expect(fileManager.fileExists(atPath: try #require(result.cdrArtifacts).archiveURL.path))
    #expect(fileManager.fileExists(atPath: try #require(result.cdrArtifacts).xmlURL.path))
}

@Test func sunatResponseParserClassifiesObservationsAndRejections() throws {
    let fileManager = FileManager.default
    let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
    defer { try? fileManager.removeItem(at: directoryURL) }
    
    let observed = try SunatBillResponseParser.parse(makeCDRResponse(
        directoryURL: directoryURL,
        responseCode: "0",
        observation: SunatObservation(code: "4000", description: "Observación de prueba")
    ))
    let rejected = try SunatBillResponseParser.parse(makeCDRResponse(
        directoryURL: directoryURL,
        responseCode: "2000"
    ))
    
    #expect(observed.status == .acceptedWithObservations)
    #expect(observed.observations == [SunatObservation(code: "4000", description: "Observación de prueba")])
    #expect(rejected.status == .rejected)
    #expect(rejected.responseCode == "2000")
}

@Test func sunatResponseParserIgnoresNonXMLFilesInsideCDRArchive() throws {
    let fileManager = FileManager.default
    let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
    defer { try? fileManager.removeItem(at: directoryURL) }
    
    let response = try makeCDRResponse(
        directoryURL: directoryURL,
        responseCode: "0",
        additionalEntry: "metadata.txt"
    )
    
    #expect(try SunatBillResponseParser.parse(response).status == .accepted)
}

@Test func sunatResponseParserSurfacesSOAPFault() throws {
    let fault = """
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
      <soapenv:Body><soapenv:Fault><faultcode>soapenv:Client</faultcode><faultstring>ZIP inválido</faultstring></soapenv:Fault></soapenv:Body>
    </soapenv:Envelope>
    """
    let response = SunatHTTPResponse(
        statusCode: 500,
        body: Data(fault.utf8),
        contentType: "text/xml; charset=UTF-8"
    )
    
    do {
        _ = try SunatBillResponseParser.parse(response)
        Issue.record("Se esperaba un SOAP Fault")
    } catch let error as SunatBillSubmissionError {
        #expect(error == .soapFault(code: "soapenv:Client", message: "ZIP inválido"))
    }
}

@Test func sunatBillClientSurfacesSOAPFaultEvenWhenHTTPFails() async throws {
    let fileManager = FileManager.default
    let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
    defer { try? fileManager.removeItem(at: directoryURL) }
    
    let boleta = makeBoleta()
    let document = try CPEDocumentWriter().write(
        SignedCPE(xml: Data("<Invoice />".utf8), identity: CPEIdentity(document: boleta)),
        output: outputConfiguration(in: directoryURL)
    )
    let fault = """
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
      <soapenv:Body><soapenv:Fault><faultcode>soapenv:Client</faultcode><faultstring>ZIP inválido</faultstring></soapenv:Fault></soapenv:Body>
    </soapenv:Envelope>
    """
    let transport = CapturingSunatHTTPTransport(response: SunatHTTPResponse(
        statusCode: 500,
        body: Data(fault.utf8),
        contentType: "text/xml; charset=UTF-8"
    ))
    
    do {
        _ = try await SunatBillClient(transport: transport).submit(
            document: document,
            credentials: .beta(emitterRUC: "20123456789")
        )
        Issue.record("Se esperaba un SOAP Fault")
    } catch let error as SunatBillSubmissionError {
        #expect(error == .soapFault(code: "soapenv:Client", message: "ZIP inválido"))
    }
}

/// Las pruebas que impactan SUNAT BETA comparten las credenciales MODDATOS.
/// SUNAT puede rechazar solicitudes concurrentes con HTTP 401, por lo que esta
/// suite se ejecuta en serie aunque el resto de pruebas continúe en paralelo.
@Suite(.serialized)
struct SunatBetaIntegrationTests {
    
    /// Prueba de integración manual contra SUNAT BETA.
    ///
    /// No realiza ninguna llamada de red salvo que se configure explícitamente:
    /// - `FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION=true`
    @Test func sunatBetaIntegrationAcceptsSignedBoletaWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION"] == "true" else {
            return
        }
        
        let fileManager = FileManager.default
        let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
        defer { try? fileManager.removeItem(at: directoryURL) }
        
        let boleta = makeBoletaForSunatBeta()
        guard let signingConfiguration = integrationSigningConfiguration(for: boleta) else {
            throw IntegrationConfigurationError.missingSigningCredentials
        }
        let signedCPE = try XMLSecCPESigner().sign(boleta, configuration: signingConfiguration)
        let emitterRUC = boleta.supplier.taxIdentifier.value
        let output = outputConfiguration(in: directoryURL)
        let document = try CPEDocumentWriter().write(
            signedCPE,
            output: output
        )

        printSignedBoletaBetaXML(
            scenario: "BOLETA MÍNIMA",
            boleta: boleta,
            signedCPE: signedCPE,
            document: document
        )
        
        let result = try await submitToSunatBeta(
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
    
    /// Prueba de integración manual BETA para una boleta con más de un producto.
    /// Solo realiza la llamada si `FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION=true`.
    @Test func sunatBetaIntegrationAcceptsSignedMultiProductBoletaWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION"] == "true" else {
            return
        }
        
        let fileManager = FileManager.default
        let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
        defer { try? fileManager.removeItem(at: directoryURL) }
        
        let boleta = makeMultiProductBoletaForSunatBeta()
        guard let signingConfiguration = integrationSigningConfiguration(for: boleta) else {
            throw IntegrationConfigurationError.missingSigningCredentials
        }
        let signedCPE = try XMLSecCPESigner().sign(boleta, configuration: signingConfiguration)
        let emitterRUC = boleta.supplier.taxIdentifier.value
        let output = outputConfiguration(in: directoryURL)
        let document = try CPEDocumentWriter().write(
            signedCPE,
            output: output
        )

        printSignedBoletaBetaXML(
            scenario: "BOLETA MULTIPRODUCTO",
            boleta: boleta,
            signedCPE: signedCPE,
            document: document
        )
        
        let result = try await submitToSunatBeta(
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

    /// Caso de tres líneas basado en el XML de referencia BC01-3652:
    /// dos productos gravados y una bonificación gratuita.
    @Test func sunatBetaIntegrationAcceptsSignedReferenceBoletaWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_SUNAT_BETA_INTEGRATION"] == "true" else {
            return
        }

        let fileManager = FileManager.default
        let directoryURL = try makeTemporaryDirectory(fileManager: fileManager)
        defer { try? fileManager.removeItem(at: directoryURL) }

        let boleta = makeReferenceBoletaForSunatBeta()
        guard let signingConfiguration = integrationSigningConfiguration(for: boleta) else {
            throw IntegrationConfigurationError.missingSigningCredentials
        }
        let signedCPE = try XMLSecCPESigner().sign(
            boleta,
            configuration: signingConfiguration
        )
        let emitterRUC = boleta.supplier.taxIdentifier.value
        let document = try CPEDocumentWriter().write(
            signedCPE,
            output: outputConfiguration(in: directoryURL)
        )

        printSignedBoletaBetaXML(
            scenario: "BOLETA COMO XML DE REFERENCIA",
            boleta: boleta,
            signedCPE: signedCPE,
            document: document
        )

        let result = try await submitToSunatBeta(
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

private func makeTemporaryDirectory(fileManager: FileManager) throws -> URL {
    let directoryURL = fileManager.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-Tests-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    return directoryURL
}

private func outputConfiguration(in directoryURL: URL) -> CPEOutputConfiguration {
    CPEOutputConfiguration(
        rootDirectory: directoryURL.appendingPathComponent("cpe")
    )
}

/// BETA puede devolver 401 si se realizan dos autenticaciones MODDATOS con muy
/// poca separación. Solo esta prueba de integración reintenta ese caso; la
/// librería conserva la respuesta HTTP original para sus consumidores.
private func submitToSunatBeta(
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

private enum IntegrationConfigurationError: Error {
    case missingSigningCredentials
}

private func makeCDRResponse(
    directoryURL: URL,
    responseCode: String,
    observation: SunatObservation? = nil,
    additionalEntry: String? = nil
) throws -> SunatHTTPResponse {
    let observationXML = observation.map {
        "<cac:Status><cbc:StatusReasonCode>\($0.code ?? "")</cbc:StatusReasonCode><cbc:StatusReason>\($0.description ?? "")</cbc:StatusReason></cac:Status>"
    } ?? ""
    let cdrXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ApplicationResponse xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2" xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2">
      <cac:DocumentResponse><cac:Response><cbc:ResponseCode>\(responseCode)</cbc:ResponseCode><cbc:Description>Respuesta SUNAT</cbc:Description>\(observationXML)</cac:Response></cac:DocumentResponse>
    </ApplicationResponse>
    """
    let cdrXMLURL = directoryURL.appendingPathComponent("R-20123456789-03-B001-\(UUID().uuidString).xml")
    try Data(cdrXML.utf8).write(to: cdrXMLURL)
    let cdrArchiveURL = try XMLDocumentPackager().package(xmlAt: cdrXMLURL).archiveURL
    if let additionalEntry {
        let archive = try Archive(url: cdrArchiveURL, accessMode: .update)
        try archive.addEntry(
            with: additionalEntry,
            type: .file,
            uncompressedSize: Int64(0),
            compressionMethod: .none,
            provider: { (_: Int64, _: Int) in Data() }
        )
    }
    let cdrArchive = try Data(contentsOf: cdrArchiveURL)
    let body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ser="http://service.sunat.gob.pe">
      <soapenv:Body><ser:sendBillResponse><applicationResponse>\(cdrArchive.base64EncodedString())</applicationResponse></ser:sendBillResponse></soapenv:Body>
    </soapenv:Envelope>
    """
    
    return SunatHTTPResponse(
        statusCode: 200,
        body: Data(body.utf8),
        contentType: "text/xml; charset=UTF-8"
    )
}

private actor CapturingSunatHTTPTransport: SunatHTTPTransport {
    private(set) var request: URLRequest?
    private let response: SunatHTTPResponse
    
    init(response: SunatHTTPResponse) {
        self.response = response
    }
    
    func send(_ request: URLRequest) async throws -> SunatHTTPResponse {
        self.request = request
        return response
    }
}

private func printSignedBoletaBetaXML(
    scenario: String,
    boleta: Boleta,
    signedCPE: SignedCPE,
    document: CPEDocument
) {
    print("""

    ===== SUNAT BETA \(scenario): XML FIRMADO =====
    Archivo XML: \(document.signedXMLURL.lastPathComponent)
    Archivo ZIP: \(document.zipURL.lastPathComponent)
    Tipo de operación esperado: \(boleta.operationTypeCode)
    Tipo de documento esperado: \(boleta.identifier.type.rawValue)
    \(String(decoding: signedCPE.xml, as: UTF8.self))
    ===== FIN SUNAT BETA \(scenario): XML FIRMADO =====

    """)
}

private func integrationSigningConfiguration() -> SigningConfiguration? {
    let environment = ProcessInfo.processInfo.environment
    guard let certificatePath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
          let certificatePassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else {
        return nil
    }
    
    return SigningConfiguration(
        signature: SignatureInformation(
            identifier: "20123456789",
            signatoryIdentifier: "20123456789",
            signatoryName: "GREENTER S.A.C.",
            uri: "#GREENTER-SIGN"
        ),
        credentials: .pkcs12(
            path: URL(fileURLWithPath: certificatePath),
            passwordProvider: { certificatePassword }
        )
    )
}

private func integrationSigningConfiguration(
    for document: any UBLInvoiceDocument
) -> SigningConfiguration? {
    let environment = ProcessInfo.processInfo.environment
    guard let certificatePath = environment["FLORSHOP_CPE_TEST_PFX_PATH"],
          let certificatePassword = environment["FLORSHOP_CPE_TEST_PFX_PASSWORD"] else {
        return nil
    }

    return SigningConfiguration(
        signature: SignatureInformation(
            identifier: document.identifier.value,
            signatoryIdentifier: document.supplier.taxIdentifier.value,
            signatoryName: document.supplier.legalName,
            uri: "#SignSUNAT"
        ),
        credentials: .pkcs12(
            path: URL(fileURLWithPath: certificatePath),
            passwordProvider: { certificatePassword }
        )
    )
}

private func makeBoleta(
    identifier: DocumentIdentifier = DocumentIdentifier(
        series: "B001",
        number: "1",
        type: .boleta
    ),
    issueDate: IssueDate = IssueDate(year: 2020, month: 8, day: 19),
    emitterRUC: String = "20123456789",
    supplierAddress: Address? = nil
) -> Boleta {
    let currency: CurrencyCode = .pen
    let scheme = TaxScheme.igv
    let lineTaxTotal = LineTaxTotal(
        amount: MonetaryAmount(value: 18, currency: currency),
        subtotals: [LineTaxSubtotal(
            taxableAmount: MonetaryAmount(value: 100, currency: currency),
            taxAmount: MonetaryAmount(value: 18, currency: currency),
            category: TaxCategory(percent: 18, exemptionReasonCode: .gravadoOperacionOnerosa, scheme: scheme)
        )]
    )
    return Boleta(
        identifier: identifier,
        issueDate: issueDate,
        currency: currency,
        supplier: Supplier(
            taxIdentifier: PartyIdentifier(value: emitterRUC, documentType: .ruc),
            legalName: "GREENTER S.A.C.",
            address: supplierAddress
        ),
        customer: Customer(identifier: PartyIdentifier(value: "20203030", documentType: .dni), legalName: "PERSON 1"),
        taxTotal: TaxTotal(
            amount: MonetaryAmount(value: 18, currency: currency),
            subtotals: [TaxSubtotal(taxableAmount: MonetaryAmount(value: 100, currency: currency), taxAmount: MonetaryAmount(value: 18, currency: currency), scheme: scheme)]
        ),
        monetaryTotal: MonetaryTotal(lineExtensionAmount: MonetaryAmount(value: 100, currency: currency), taxInclusiveAmount: MonetaryAmount(value: 118, currency: currency), payableAmount: MonetaryAmount(value: 118, currency: currency)),
        lines: [InvoiceLine(
            id: "1",
            quantity: Quantity(value: 2, unitCode: .unit),
            lineExtensionAmount: MonetaryAmount(value: 100, currency: currency),
            alternativePrices: [AlternativePrice(
                amount: MonetaryAmount(value: 59, currency: currency),
                type: .unitPriceIncludingTaxes
            )],
            taxTotal: lineTaxTotal,
            item: Item(description: "PRODUCTO"),
            price: MonetaryAmount(value: 50, currency: currency)
        )]
    )
}

private func makeBoletaForSunatBeta() -> Boleta {
    makeBoleta(
        identifier: DocumentIdentifier(
            series: "B001",
            number: referenceBoletaCorrelative(offset: 0),
            type: .boleta
        ),
        issueDate: currentLimaIssueDateForBoleta(),
        emitterRUC: "10708255195",
        supplierAddress: sunatBetaSupplierAddress()
    )
}

private func makeReferenceBoletaForSunatBeta() -> Boleta {
    let currency = CurrencyCode.pen
    let igvCategory = TaxCategory(
        percent: 18,
        exemptionReasonCode: .gravadoOperacionOnerosa,
        scheme: .igv
    )
    let freeCategory = TaxCategory(
        percent: 18,
        exemptionReasonCode: .inafectoRetiroPorBonificacion,
        scheme: .gratuito
    )

    func amount(_ value: String) -> MonetaryAmount {
        MonetaryAmount(value: Decimal(string: value)!, currency: currency)
    }

    return Boleta(
        identifier: DocumentIdentifier(
            series: "BC01",
            number: referenceBoletaCorrelative(),
            type: .boleta
        ),
        issueDate: currentLimaIssueDateForBoleta(),
        issueTime: IssueTime(hour: 18, minute: 1, second: 29),
        currency: currency,
        supplier: Supplier(
            taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
            commercialName: "Electrodomésticos Cruz de Motupe",
            legalName: "Vega Poblete Carlos Enrique",
            address: Address(
                ubigeoCode: "150130",
                addressTypeCode: "0000",
                city: "LIMA",
                department: "LIMA",
                district: "SAN BORJA",
                line: "CAL. PABLO USANDIZAGA 670"
            )
        ),
        customer: Customer(
            identifier: PartyIdentifier(value: "46237547", documentType: .dni),
            legalName: "Pazos Atoche Luana Karina"
        ),
        taxTotal: TaxTotal(
            amount: amount("266.65"),
            subtotals: [
                TaxSubtotal(
                    taxableAmount: amount("1481.35"),
                    taxAmount: amount("266.65"),
                    scheme: .igv
                ),
                TaxSubtotal(
                    taxableAmount: amount("4.80"),
                    taxAmount: amount("0.00"),
                    scheme: .gratuito
                )
            ]
        ),
        monetaryTotal: MonetaryTotal(
            lineExtensionAmount: amount("1481.35"),
            taxInclusiveAmount: amount("1748.00"),
            allowanceTotalAmount: amount("0.00"),
            payableAmount: amount("1748.00")
        ),
        lines: [
            InvoiceLine(
                id: "1",
                quantity: Quantity(value: 1, unitCode: .unit),
                lineExtensionAmount: amount("845.76"),
                alternativePrices: [
                    AlternativePrice(
                        amount: amount("998.00"),
                        type: .unitPriceIncludingTaxes
                    )
                ],
                taxTotal: LineTaxTotal(
                    amount: amount("152.24"),
                    subtotals: [
                        LineTaxSubtotal(
                            taxableAmount: amount("845.76"),
                            taxAmount: amount("152.24"),
                            category: igvCategory
                        )
                    ]
                ),
                item: Item(
                    description: "Refrigeradora marca “AXM” no frost de 200 ltrs.",
                    sellerItemIdentifier: "REF564",
                    commodityClassificationCode: "52141501"
                ),
                price: amount("845.76")
            ),
            InvoiceLine(
                id: "2",
                quantity: Quantity(value: 1, unitCode: .unit),
                lineExtensionAmount: amount("635.59"),
                alternativePrices: [
                    AlternativePrice(
                        amount: amount("750.00"),
                        type: .unitPriceIncludingTaxes
                    )
                ],
                taxTotal: LineTaxTotal(
                    amount: amount("114.41"),
                    subtotals: [
                        LineTaxSubtotal(
                            taxableAmount: amount("635.59"),
                            taxAmount: amount("114.41"),
                            category: igvCategory
                        )
                    ]
                ),
                item: Item(
                    description: "Cocina a gas GLP, marca “AXM” de 5 hornillas",
                    sellerItemIdentifier: "COC124",
                    commodityClassificationCode: "95141606"
                ),
                price: amount("635.59")
            ),
            InvoiceLine(
                id: "3",
                quantity: Quantity(value: 1, unitCode: .unit),
                lineExtensionAmount: amount("4.80"),
                alternativePrices: [
                    AlternativePrice(
                        amount: amount("4.80"),
                        type: .referenceValue
                    )
                ],
                taxTotal: LineTaxTotal(
                    amount: amount("0.00"),
                    subtotals: [
                        LineTaxSubtotal(
                            taxableAmount: amount("4.80"),
                            taxAmount: amount("0.00"),
                            category: freeCategory
                        )
                    ]
                ),
                item: Item(
                    description: "Sixpack de gaseosa “Guerené” de 400 ml",
                    sellerItemIdentifier: "NOB012",
                    commodityClassificationCode: "24121803"
                ),
                price: amount("0.00"),
                isFreeOfCharge: true
            )
        ]
    )
}

private func currentLimaIssueDateForBoleta() -> IssueDate {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Lima")!
    let components = calendar.dateComponents([.year, .month, .day], from: Date())
    return IssueDate(
        year: components.year!,
        month: components.month!,
        day: components.day!
    )
}

private func referenceBoletaCorrelative() -> String {
    referenceBoletaCorrelative(offset: 0)
}

private func referenceBoletaCorrelative(offset: Int) -> String {
    let maximumCorrelative = 99_999_999
    let timestamp = Int(Date().timeIntervalSince1970) % maximumCorrelative
    return String(max(1, (timestamp + offset) % maximumCorrelative))
}

private func makeBoletaWithMoreProducts(
    identifier: DocumentIdentifier = DocumentIdentifier(
        series: "B001",
        number: "2",
        type: .boleta
    ),
    issueDate: IssueDate = IssueDate(year: 2020, month: 8, day: 19),
    emitterRUC: String = "20123456789",
    supplierAddress: Address? = nil
) -> Boleta {
    let currency: CurrencyCode = .pen
    let scheme = TaxScheme.igv
    let firstLineTaxTotal = LineTaxTotal(
        amount: MonetaryAmount(value: 18, currency: currency),
        subtotals: [LineTaxSubtotal(
            taxableAmount: MonetaryAmount(value: 100, currency: currency),
            taxAmount: MonetaryAmount(value: 18, currency: currency),
            category: TaxCategory(percent: 18, exemptionReasonCode: .gravadoOperacionOnerosa, scheme: scheme)
        )]
    )
    let secondLineTaxTotal = LineTaxTotal(
        amount: MonetaryAmount(value: 9, currency: currency),
        subtotals: [LineTaxSubtotal(
            taxableAmount: MonetaryAmount(value: 50, currency: currency),
            taxAmount: MonetaryAmount(value: 9, currency: currency),
            category: TaxCategory(percent: 18, exemptionReasonCode: .gravadoOperacionOnerosa, scheme: scheme)
        )]
    )
    let priceIncludingTaxes = AlternativePrice(
        amount: MonetaryAmount(value: 59, currency: currency),
        type: .unitPriceIncludingTaxes
    )
    
    return Boleta(
        identifier: identifier,
        issueDate: issueDate,
        currency: currency,
        supplier: Supplier(
            taxIdentifier: PartyIdentifier(value: emitterRUC, documentType: .ruc),
            legalName: "GREENTER S.A.C.",
            address: supplierAddress
        ),
        customer: Customer(identifier: PartyIdentifier(value: "20203030", documentType: .dni), legalName: "PERSON 1"),
        taxTotal: TaxTotal(
            amount: MonetaryAmount(value: 27, currency: currency),
            subtotals: [TaxSubtotal(
                taxableAmount: MonetaryAmount(value: 150, currency: currency),
                taxAmount: MonetaryAmount(value: 27, currency: currency),
                scheme: scheme
            )]
        ),
        monetaryTotal: MonetaryTotal(
            lineExtensionAmount: MonetaryAmount(value: 150, currency: currency),
            taxInclusiveAmount: MonetaryAmount(value: 177, currency: currency),
            payableAmount: MonetaryAmount(value: 177, currency: currency)
        ),
        lines: [
            InvoiceLine(
                id: "1",
                quantity: Quantity(value: 2, unitCode: .unit),
                lineExtensionAmount: MonetaryAmount(value: 100, currency: currency),
                alternativePrices: [priceIncludingTaxes],
                taxTotal: firstLineTaxTotal,
                item: Item(description: "PRODUCTO 1"),
                price: MonetaryAmount(value: 50, currency: currency)
            ),
            InvoiceLine(
                id: "2",
                quantity: Quantity(value: 1, unitCode: .unit),
                lineExtensionAmount: MonetaryAmount(value: 50, currency: currency),
                alternativePrices: [priceIncludingTaxes],
                taxTotal: secondLineTaxTotal,
                item: Item(description: "PRODUCTO 2"),
                price: MonetaryAmount(value: 50, currency: currency)
            )
        ]
    )
}

private func makeMultiProductBoletaForSunatBeta() -> Boleta {
    makeBoletaWithMoreProducts(
        identifier: DocumentIdentifier(
            series: "B001",
            number: referenceBoletaCorrelative(offset: 1),
            type: .boleta
        ),
        issueDate: currentLimaIssueDateForBoleta(),
        emitterRUC: "10708255195",
        supplierAddress: sunatBetaSupplierAddress()
    )
}

private func sunatBetaSupplierAddress() -> Address {
    Address(
        ubigeoCode: "150130",
        addressTypeCode: "0000",
        city: "LIMA",
        department: "LIMA",
        district: "SAN BORJA",
        line: "CAL. PABLO USANDIZAGA 670"
    )
}
