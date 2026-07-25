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
        identifier: DocumentIdentifier(series: "B001", number: "1"),
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
    #expect(xml.contains("<cbc:InvoiceTypeCode listID=\"0101\">03</cbc:InvoiceTypeCode>"))
    #expect(xml.contains("<cbc:Note languageLocaleID=\"1000\">SON CIENTO DIECIOCHO CON 00/100 SOLES</cbc:Note>"))
    #expect(xml.contains("<cbc:TaxAmount currencyID=\"PEN\">18.00</cbc:TaxAmount>"))
    #expect(xml.contains("<cac:TaxCategory>\n            <cac:TaxScheme>"))
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
    let signer = XMLSecBoletaSigner()
    let configuration = SigningConfiguration(
        signature: SignatureInformation(
            identifier: "20123456789",
            signatoryIdentifier: "20123456789",
            signatoryName: "GREENTER S.A.C.",
            uri: "GREENTER-SIGN"
        ),
        credentials: .pkcs12(path: URL(fileURLWithPath: "/not-used.pfx"), passwordProvider: { "" })
    )

    #expect(throws: BoletaSigningError.invalidSignatureURI) {
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

    let signedBoleta = try XMLSecBoletaSigner().sign(makeBoleta(), configuration: configuration)
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

    let signedBoleta = try XMLSecBoletaSigner().sign(makeBoleta(), configuration: configuration)

    #expect(try XMLSecSignatureVerifier().verify(signedBoleta.xml))
}

/// Prueba de integración opcional. Requiere las mismas variables de entorno que
/// `signerCreatesXMLDSIGWithConfiguredPKCS12Certificate`.
@Test func verifierRejectsXMLModifiedAfterSigning() throws {
    guard let configuration = integrationSigningConfiguration() else {
        return
    }

    let signedBoleta = try XMLSecBoletaSigner().sign(makeBoleta(), configuration: configuration)
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

private func makeBoleta() -> Boleta {
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
        identifier: DocumentIdentifier(series: "B001", number: "1"),
        issueDate: IssueDate(year: 2020, month: 8, day: 19),
        currency: currency,
        supplier: Supplier(taxIdentifier: PartyIdentifier(value: "20123456789", documentType: .ruc), legalName: "GREENTER S.A.C."),
        customer: Customer(identifier: PartyIdentifier(value: "20203030", documentType: .dni), legalName: "PERSON 1"),
        taxTotal: TaxTotal(
            amount: MonetaryAmount(value: 18, currency: currency),
            subtotals: [TaxSubtotal(taxableAmount: MonetaryAmount(value: 100, currency: currency), taxAmount: MonetaryAmount(value: 18, currency: currency), scheme: scheme)]
        ),
        monetaryTotal: MonetaryTotal(lineExtensionAmount: MonetaryAmount(value: 100, currency: currency), taxInclusiveAmount: MonetaryAmount(value: 118, currency: currency), payableAmount: MonetaryAmount(value: 118, currency: currency)),
        lines: [InvoiceLine(id: "1", quantity: Quantity(value: 2, unitCode: .unit), lineExtensionAmount: MonetaryAmount(value: 100, currency: currency), alternativePrices: [], taxTotal: lineTaxTotal, item: Item(description: "PRODUCTO"), price: MonetaryAmount(value: 50, currency: currency))]
    )
}
