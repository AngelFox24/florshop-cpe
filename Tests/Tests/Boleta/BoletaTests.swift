import Foundation
import Testing
import ZIPFoundation
@testable import FlorShopCPE

@Test func boletaAssignsSequentialInvoiceLineIdentifiers() throws {
    let boleta = try BoletaLarge.getBoletaLargeExample(
        now: Date(timeIntervalSince1970: 1_786_899_600)
    )

    #expect(boleta.lines.map(\.id) == ["1", "2", "3", "4", "5", "6"])
}

@Test func boletaModelRetainsItsDomainData() {
    let supplier = Supplier(
        taxIdentifier: PartyIdentifier(value: "20123456789", documentType: .ruc),
        legalName: "GREENTER S.A.C."
    )
    let customer = Customer(
        identifier: PartyIdentifier(value: "20203030", documentType: .dni),
        legalName: "PERSON 1"
    )
    let line = InvoiceLine(
        id: "1",
        quantity: .units(2),
        pricing: .taxed(50, basis: .excludingTaxes),
        item: Item(description: "PROD 1", sellerItemIdentifier: "C023")
    )
    let boleta = Boleta(
        identifier: DocumentIdentifier(series: "B001", number: "1"),
        issueDate: IssueDate(year: 2020, month: 8, day: 19),
        currency: .pen,
        supplier: supplier,
        customer: customer,
        lines: [line]
    )
    
    #expect(boleta.identifier.value == "B001-1")
    #expect(boleta.documentType == .boleta)
    #expect(boleta.lines.count == 1)
    #expect(boleta.taxTotal.subtotals.first?.scheme == .igv)
    #expect(boleta.netAmount == 100)
    #expect(boleta.taxAmount == 18)
    #expect(boleta.totalAmount == 118)
}

@Test func transformerGeneratesUBLInvoiceXML() {
    let currency: CurrencyCode = .pen
    let boleta = Boleta(
        identifier: DocumentIdentifier(series: "B001", number: "1"),
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
        lines: [InvoiceLine(
            id: "1",
            quantity: .units(2),
            pricing: .taxed(50, basis: .excludingTaxes),
            item: Item(description: "PROD & SERVICIO", sellerItemIdentifier: "C023")
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
    
    #expect(try formatter.format(0.00, currency: .pen) == "SON CERO CON 00/100 SOLES")
    #expect(try formatter.format(1.01, currency: .pen) == "SON UN CON 01/100 SOLES")
    #expect(try formatter.format(118.00, currency: .pen) == "SON CIENTO DIECIOCHO CON 00/100 SOLES")
    #expect(try formatter.format(1000000.50, currency: .usd) == "SON UN MILLÓN CON 50/100 DÓLARES AMERICANOS")
}

@Test func cpePrecisionPreservesInputsAndUsesPlainRounding() {
    let exactHalf = Decimal(1_005) / Decimal(1_000)
    let exactUnitValue = Decimal(1_212_345_678_905) / Decimal(100_000_000_000)
    let exactRate = Decimal(18_123_455) / Decimal(1_000_000)
    let amount = MonetaryAmount(value: exactHalf)

    #expect(amount.value == exactHalf)
    #expect(amount.normalized.value == Decimal(101) / Decimal(100))
    #expect(
        CPEPrecision.lineAmount(unitPrice: Decimal(335) / Decimal(1_000), quantity: 3)
            == Decimal(101) / Decimal(100)
    )
    #expect(CPEPrecision.monetarySum([exactHalf, exactHalf + 1]) == Decimal(302) / Decimal(100))
    #expect(CPEPrecision.unitValue(exactUnitValue) == Decimal(121_234_567_891) / Decimal(10_000_000_000))
    #expect(CPEPrecision.rate(exactRate) == Decimal(1_812_346) / Decimal(100_000))
}

@Test func xmlWriterUsesThePrecisionOfEachNumericField() {
    var writer = XMLWriter(documentCurrency: .pen)
    writer.monetaryElement(
        "cbc:Amount",
        amount: MonetaryAmount(value: Decimal(1_005) / Decimal(1_000))
    )
    writer.unitPriceElement("cbc:PriceAmount", amount: MonetaryAmount(value: 75.07891234567))
    let quantity = writer.formatQuantity(Decimal(312_345_678_905) / Decimal(100_000_000_000))
    let rate = writer.formatRate(Decimal(18_123_455) / Decimal(1_000_000))
    writer.element("cbc:Quantity", text: quantity)
    writer.element("cbc:Percent", text: rate)

    #expect(writer.result.contains(">1.01</cbc:Amount>"))
    #expect(writer.result.contains(">75.0789123457</cbc:PriceAmount>"))
    #expect(writer.result.contains(">3.1234567891</cbc:Quantity>"))
    #expect(writer.result.contains(">18.12346</cbc:Percent>"))
}

@Test func transformerNormalizesPayableRoundingAndAmountInWords() throws {
    let exactHalfCent = Decimal(5) / Decimal(1_000)
    let xml = try UBLInvoiceXMLTransformer().transform(
        makeBoleta(payableRoundingAmount: exactHalfCent)
    )

    #expect(xml.contains("<cbc:PayableRoundingAmount currencyID=\"PEN\">0.01</cbc:PayableRoundingAmount>"))
    #expect(xml.contains("<cbc:PayableAmount currencyID=\"PEN\">118.01</cbc:PayableAmount>"))
    #expect(xml.contains("SON CIENTO DIECIOCHO CON 01/100 SOLES"))
}

@Test func documentExposesCalculatedAmountsBeforeSigning() {
    let boleta = makeBoleta()

    #expect(boleta.netAmount == 100)
    #expect(boleta.taxAmount == 18)
    #expect(boleta.totalAmount == 118)
}

@Test func explicitPriceModesProduceTheSameCalculatedSale() {
    let quantity = Quantity.units(2)
    let item = Item(description: "PRODUCTO")
    let included = InvoiceLine(
        id: "1",
        quantity: quantity,
        pricing: .taxed(118),
        item: item
    )
    let excluded = InvoiceLine(
        id: "2",
        quantity: quantity,
        pricing: .taxed(100, basis: .excludingTaxes),
        item: item
    )

    #expect(included.pricing.amount == 118)
    #expect(included.pricing.taxedPriceBasis == .includingTaxes)
    #expect(included.taxTreatment == .taxed(rate: 18))
    #expect(excluded.pricing == .taxed(100, basis: .excludingTaxes))
    #expect(included.price.value == 100)
    #expect(included.lineExtensionAmount.value == 200)
    #expect(included.taxTotal.amount.value == 36)
    #expect(included.lineExtensionAmount == excluded.lineExtensionAmount)
    #expect(included.taxTotal == excluded.taxTotal)
}

@Test func quantityFactoriesPreserveDiscreteAndContinuousUnits() {
    let units = Quantity.units(2)
    let kilograms = Quantity.kilograms(1.06)
    let grams = Quantity.grams(250.5)
    let liters = Quantity.liters(0.75)
    let meters = Quantity.meters(2.75)
    let serviceUnits = Quantity.serviceUnits(1.5)

    #expect(units.value == 2)
    #expect(units.unitCode == .unit)
    #expect(kilograms.value == 1.06)
    #expect(kilograms.unitCode == .kilogram)
    #expect(grams.unitCode == .gram)
    #expect(liters.unitCode == .liter)
    #expect(meters.unitCode == .meter)
    #expect(serviceUnits.unitCode == .serviceUnit)
}

@Test func taxTreatmentsDeriveTheSUNATTaxCategory() {
    let quantity = Quantity.units(1)
    let item = Item(description: "PRODUCTO")
    let exempt = InvoiceLine(
        id: "1",
        quantity: quantity,
        pricing: .exempt(100),
        item: item
    )
    let unaffected = InvoiceLine(
        id: "2",
        quantity: quantity,
        pricing: .unaffected(100),
        item: item
    )
    let free = InvoiceLine(
        id: "3",
        quantity: quantity,
        pricing: .free(referenceValue: 100),
        item: item
    )
    let export = InvoiceLine(
        id: "4",
        quantity: quantity,
        pricing: .export(100),
        item: item
    )

    #expect(exempt.taxCategory.percent == 0)
    #expect(exempt.taxCategory.exemptionReasonCode == .exonerado)
    #expect(exempt.taxCategory.scheme == .exonerado)
    #expect(exempt.taxCategory.scheme.identifier == "9997")
    #expect(exempt.taxCategory.scheme.name == "EXO")
    #expect(exempt.taxCategory.scheme.typeCode == "VAT")
    #expect(unaffected.taxCategory.percent == 0)
    #expect(unaffected.taxCategory.exemptionReasonCode == .inafecto)
    #expect(unaffected.taxCategory.scheme == .inafecto)
    #expect(unaffected.taxCategory.scheme.identifier == "9998")
    #expect(unaffected.taxCategory.scheme.name == "INA")
    #expect(unaffected.taxCategory.scheme.typeCode == "FRE")
    #expect(free.taxCategory.percent == 18)
    #expect(free.taxCategory.exemptionReasonCode == .inafectoRetiroPorBonificacion)
    #expect(free.taxCategory.scheme == .gratuito)
    #expect(free.lineExtensionAmount.value == 100)
    #expect(free.price.value == 0)
    #expect(export.taxCategory.percent == 0)
    #expect(export.taxCategory.exemptionReasonCode == .exportacion)
    #expect(export.taxCategory.scheme == .exportacion)
    #expect(export.taxTotal.amount.value == 0)
}

@Test func transformerInfersBoletaSignatureMetadata() throws {
    let xml = try UBLInvoiceXMLTransformer().transform(makeBoleta())

    #expect(xml.contains("<cac:Signature>"))
    #expect(xml.contains("<cbc:URI>#SignSUNAT</cbc:URI>"))
    #expect(xml.contains("<cbc:ID>20123456789</cbc:ID>"))
    #expect(xml.contains("<cbc:Name>GREENTER S.A.C.</cbc:Name>"))
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
        credentials: .pkcs12(
            path: URL(fileURLWithPath: certificatePath),
            passwordProvider: { certificatePassword }
        )
    )
    
    let signedBoleta = try XMLSecCPESigner().sign(makeBoleta(), configuration: configuration)
    let signedXML = try #require(signedBoleta.xmlString)
    
    #expect(signedXML.contains("<cac:Signature>"))
    #expect(signedXML.contains("<ds:Signature"))
    #expect(signedXML.contains("Id=\"SignSUNAT\""))
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
    let boleta = makeReferenceBoletaForSunatBeta()
    let freeLine = boleta.lines[2]
    let xml = try UBLInvoiceXMLTransformer().transform(boleta)

    #expect(freeLine.lineExtensionAmount.value == 4.80)
    #expect(freeLine.taxTotal.subtotals[0].taxableAmount.value == 4.80)
    #expect(freeLine.price.value == 0)
    #expect(boleta.netAmount == 1481.35)
    #expect(boleta.totalAmount == 1748.00)

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
    #expect(xml.contains("<cbc:TaxableAmount currencyID=\"PEN\">4.80</cbc:TaxableAmount>"))
    #expect(xml.contains("<cbc:PayableAmount currencyID=\"PEN\">1748.00</cbc:PayableAmount>"))
    #expect(!xml.contains("languageLocaleID=\"1002\""))
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
        guard let signingConfiguration = integrationSigningConfiguration() else {
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
        guard let signingConfiguration = integrationSigningConfiguration() else {
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
        guard let signingConfiguration = integrationSigningConfiguration() else {
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
    Tipo de operación esperado: 0101
    Tipo de documento esperado: \(boleta.documentType.rawValue)
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
        credentials: .pkcs12(
            path: URL(fileURLWithPath: certificatePath),
            passwordProvider: { certificatePassword }
        )
    )
}

private func makeBoleta(
    identifier: DocumentIdentifier = DocumentIdentifier(
        series: "B001",
        number: "1"
    ),
    issueDate: IssueDate = IssueDate(year: 2020, month: 8, day: 19),
    emitterRUC: String = "20123456789",
    supplierAddress: Address? = nil,
    payableRoundingAmount: Decimal? = nil
) -> Boleta {
    let currency: CurrencyCode = .pen
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
        lines: [InvoiceLine(
            id: "1",
            quantity: .units(2),
            pricing: .taxed(50, basis: .excludingTaxes),
            item: Item(description: "PRODUCTO")
        )],
        payableRoundingAmount: payableRoundingAmount
    )
}

private func makeBoletaForSunatBeta() -> Boleta {
    makeBoleta(
        identifier: DocumentIdentifier(
            series: "B001",
            number: referenceBoletaCorrelative(offset: 0)
        ),
        issueDate: currentLimaIssueDateForBoleta(),
        emitterRUC: "10708255195",
        supplierAddress: sunatBetaSupplierAddress()
    )
}

private func makeReferenceBoletaForSunatBeta() -> Boleta {
    let currency = CurrencyCode.pen
    return Boleta(
        identifier: DocumentIdentifier(
            series: "BC01",
            number: referenceBoletaCorrelative()
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
        lines: [
            InvoiceLine(
                id: "1",
                quantity: .units(1),
                pricing: .taxed(998.00),
                item: Item(
                    description: "Refrigeradora marca “AXM” no frost de 200 ltrs.",
                    sellerItemIdentifier: "REF564",
                    commodityClassificationCode: "52141501"
                )
            ),
            InvoiceLine(
                id: "2",
                quantity: .units(1),
                pricing: .taxed(750.00),
                item: Item(
                    description: "Cocina a gas GLP, marca “AXM” de 5 hornillas",
                    sellerItemIdentifier: "COC124",
                    commodityClassificationCode: "95141606"
                )
            ),
            InvoiceLine(
                id: "3",
                quantity: .units(1),
                pricing: .free(referenceValue: 4.80),
                item: Item(
                    description: "Sixpack de gaseosa “Guerené” de 400 ml",
                    sellerItemIdentifier: "NOB012",
                    commodityClassificationCode: "24121803"
                )
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
        number: "2"
    ),
    issueDate: IssueDate = IssueDate(year: 2020, month: 8, day: 19),
    emitterRUC: String = "20123456789",
    supplierAddress: Address? = nil
) -> Boleta {
    let currency: CurrencyCode = .pen
    
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
        lines: [
            InvoiceLine(
                id: "1",
                quantity: .units(2),
                pricing: .taxed(50, basis: .excludingTaxes),
                item: Item(description: "PRODUCTO 1")
            ),
            InvoiceLine(
                id: "2",
                quantity: .units(1),
                pricing: .taxed(50, basis: .excludingTaxes),
                item: Item(description: "PRODUCTO 2")
            )
        ]
    )
}

private func makeMultiProductBoletaForSunatBeta() -> Boleta {
    makeBoletaWithMoreProducts(
        identifier: DocumentIdentifier(
            series: "B001",
            number: referenceBoletaCorrelative(offset: 1)
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
