import Foundation

/// Genera el XML UBL 2.1 de una boleta sin firmarlo ni enviarlo a SUNAT.
public struct UBLInvoiceXMLTransformer: UBLInvoiceXMLTransforming, Sendable {
    private let amountInWordsFormatter: any AmountInWordsFormatting

    public init(amountInWordsFormatter: any AmountInWordsFormatting = SpanishAmountInWordsFormatter()) {
        self.amountInWordsFormatter = amountInWordsFormatter
    }

    public func transform(_ boleta: Boleta) throws -> String {
        var writer = XMLWriter()
        writer.declaration()
        writer.open("Invoice", attributes: [
            "xmlns": "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2",
            "xmlns:cac": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
            "xmlns:cbc": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2",
            "xmlns:ds": "http://www.w3.org/2000/09/xmldsig#",
            "xmlns:ext": "urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2"
        ])

        writeExtensions(to: &writer)
        writer.element("cbc:UBLVersionID", text: boleta.ublVersion)
        writer.element("cbc:CustomizationID", text: boleta.customizationID)
        writer.element("cbc:ID", text: boleta.identifier.value)
        writer.element("cbc:IssueDate", text: format(boleta.issueDate))
        if let issueTime = boleta.issueTime {
            writer.element("cbc:IssueTime", text: format(issueTime))
        }
        writer.element(
            "cbc:InvoiceTypeCode",
            text: boleta.identifier.type.rawValue,
            attributes: ["listID": "0101"]
        )
        let note = try amountInWordsFormatter.format(
            boleta.monetaryTotal.payableAmount.value,
            currency: boleta.monetaryTotal.payableAmount.currency
        )
        writer.element("cbc:Note", text: note, attributes: ["languageLocaleID": "1000"])
        writer.element("cbc:DocumentCurrencyCode", text: boleta.currency.rawValue)

        if let signature = boleta.signature {
            write(signature, to: &writer)
        }
        write(boleta.supplier, to: &writer)
        write(boleta.customer, to: &writer)
        write(boleta.taxTotal, to: &writer)
        write(boleta.monetaryTotal, to: &writer)
        boleta.lines.forEach { write($0, to: &writer) }

        writer.close("Invoice")
        return writer.result
    }

    private func writeExtensions(to writer: inout XMLWriter) {
        writer.open("ext:UBLExtensions")
        writer.open("ext:UBLExtension")
        writer.empty("ext:ExtensionContent")
        writer.close("ext:UBLExtension")
        writer.close("ext:UBLExtensions")
    }

    private func write(_ signature: SignatureInformation, to writer: inout XMLWriter) {
        writer.open("cac:Signature")
        writer.element("cbc:ID", text: signature.identifier)
        writer.open("cac:SignatoryParty")
        writer.open("cac:PartyIdentification")
        writer.element("cbc:ID", text: signature.signatoryIdentifier)
        writer.close("cac:PartyIdentification")
        writer.open("cac:PartyName")
        writer.element("cbc:Name", text: signature.signatoryName)
        writer.close("cac:PartyName")
        writer.close("cac:SignatoryParty")
        writer.open("cac:DigitalSignatureAttachment")
        writer.open("cac:ExternalReference")
        writer.element("cbc:URI", text: signature.uri)
        writer.close("cac:ExternalReference")
        writer.close("cac:DigitalSignatureAttachment")
        writer.close("cac:Signature")
    }

    private func write(_ supplier: Supplier, to writer: inout XMLWriter) {
        writer.open("cac:AccountingSupplierParty")
        writer.open("cac:Party")
        write(supplier.taxIdentifier, to: &writer)
        if let commercialName = supplier.commercialName {
            writer.open("cac:PartyName")
            writer.element("cbc:Name", text: commercialName)
            writer.close("cac:PartyName")
        }
        writer.open("cac:PartyLegalEntity")
        writer.element("cbc:RegistrationName", text: supplier.legalName)
        if let address = supplier.address {
            write(address, to: &writer)
        }
        writer.close("cac:PartyLegalEntity")
        if let contact = supplier.contact {
            write(contact, to: &writer)
        }
        writer.close("cac:Party")
        writer.close("cac:AccountingSupplierParty")
    }

    private func write(_ customer: Customer, to writer: inout XMLWriter) {
        writer.open("cac:AccountingCustomerParty")
        writer.open("cac:Party")
        write(customer.identifier, to: &writer)
        writer.open("cac:PartyLegalEntity")
        writer.element("cbc:RegistrationName", text: customer.legalName)
        writer.close("cac:PartyLegalEntity")
        writer.close("cac:Party")
        writer.close("cac:AccountingCustomerParty")
    }

    private func write(_ identifier: PartyIdentifier, to writer: inout XMLWriter) {
        writer.open("cac:PartyIdentification")
        writer.element(
            "cbc:ID",
            text: identifier.value,
            attributes: ["schemeID": identifier.documentType.rawValue]
        )
        writer.close("cac:PartyIdentification")
    }

    private func write(_ address: Address, to writer: inout XMLWriter) {
        writer.open("cac:RegistrationAddress")
        if let ubigeoCode = address.ubigeoCode { writer.element("cbc:ID", text: ubigeoCode) }
        if let addressTypeCode = address.addressTypeCode { writer.element("cbc:AddressTypeCode", text: addressTypeCode) }
        if let urbanization = address.urbanization { writer.element("cbc:CitySubdivisionName", text: urbanization) }
        if let city = address.city { writer.element("cbc:CityName", text: city) }
        if let department = address.department { writer.element("cbc:CountrySubentity", text: department) }
        if let district = address.district { writer.element("cbc:District", text: district) }
        writer.open("cac:AddressLine")
        writer.element("cbc:Line", text: address.line)
        writer.close("cac:AddressLine")
        writer.open("cac:Country")
        writer.element("cbc:IdentificationCode", text: address.countryCode)
        writer.close("cac:Country")
        writer.close("cac:RegistrationAddress")
    }

    private func write(_ contact: Contact, to writer: inout XMLWriter) {
        writer.open("cac:Contact")
        if let telephone = contact.telephone { writer.element("cbc:Telephone", text: telephone) }
        if let email = contact.email { writer.element("cbc:ElectronicMail", text: email) }
        writer.close("cac:Contact")
    }

    private func write(_ taxTotal: TaxTotal, to writer: inout XMLWriter) {
        writer.open("cac:TaxTotal")
        write("cbc:TaxAmount", amount: taxTotal.amount, to: &writer)
        taxTotal.subtotals.forEach { subtotal in
            writer.open("cac:TaxSubtotal")
            write("cbc:TaxableAmount", amount: subtotal.taxableAmount, to: &writer)
            write("cbc:TaxAmount", amount: subtotal.taxAmount, to: &writer)
            writer.open("cac:TaxCategory")
            write(subtotal.scheme, to: &writer)
            writer.close("cac:TaxCategory")
            writer.close("cac:TaxSubtotal")
        }
        writer.close("cac:TaxTotal")
    }

    private func write(_ taxTotal: LineTaxTotal, to writer: inout XMLWriter) {
        writer.open("cac:TaxTotal")
        write("cbc:TaxAmount", amount: taxTotal.amount, to: &writer)
        taxTotal.subtotals.forEach { subtotal in
            writer.open("cac:TaxSubtotal")
            write("cbc:TaxableAmount", amount: subtotal.taxableAmount, to: &writer)
            write("cbc:TaxAmount", amount: subtotal.taxAmount, to: &writer)
            writer.open("cac:TaxCategory")
            if let percent = subtotal.category.percent { writer.element("cbc:Percent", text: format(percent)) }
            if let code = subtotal.category.exemptionReasonCode { writer.element("cbc:TaxExemptionReasonCode", text: code.rawValue) }
            write(subtotal.category.scheme, to: &writer)
            writer.close("cac:TaxCategory")
            writer.close("cac:TaxSubtotal")
        }
        writer.close("cac:TaxTotal")
    }

    private func write(_ scheme: TaxScheme, to writer: inout XMLWriter) {
        writer.open("cac:TaxScheme")
        writer.element("cbc:ID", text: scheme.identifier)
        writer.element("cbc:Name", text: scheme.name)
        writer.element("cbc:TaxTypeCode", text: scheme.typeCode)
        writer.close("cac:TaxScheme")
    }

    private func write(_ total: MonetaryTotal, to writer: inout XMLWriter) {
        writer.open("cac:LegalMonetaryTotal")
        write("cbc:LineExtensionAmount", amount: total.lineExtensionAmount, to: &writer)
        write("cbc:TaxInclusiveAmount", amount: total.taxInclusiveAmount, to: &writer)
        write("cbc:PayableAmount", amount: total.payableAmount, to: &writer)
        writer.close("cac:LegalMonetaryTotal")
    }

    private func write(_ line: InvoiceLine, to writer: inout XMLWriter) {
        writer.open("cac:InvoiceLine")
        writer.element("cbc:ID", text: line.id)
        writer.element(
            "cbc:InvoicedQuantity",
            text: format(line.quantity.value),
            attributes: ["unitCode": line.quantity.unitCode.rawValue]
        )
        write("cbc:LineExtensionAmount", amount: line.lineExtensionAmount, to: &writer)
        if !line.alternativePrices.isEmpty {
            writer.open("cac:PricingReference")
            line.alternativePrices.forEach { alternativePrice in
                writer.open("cac:AlternativeConditionPrice")
                write("cbc:PriceAmount", amount: alternativePrice.amount, to: &writer)
                writer.element("cbc:PriceTypeCode", text: alternativePrice.type.rawValue)
                writer.close("cac:AlternativeConditionPrice")
            }
            writer.close("cac:PricingReference")
        }
        write(line.taxTotal, to: &writer)
        writer.open("cac:Item")
        writer.element("cbc:Description", text: line.item.description)
        if let identifier = line.item.sellerItemIdentifier {
            writer.open("cac:SellersItemIdentification")
            writer.element("cbc:ID", text: identifier)
            writer.close("cac:SellersItemIdentification")
        }
        writer.close("cac:Item")
        writer.open("cac:Price")
        write("cbc:PriceAmount", amount: line.price, to: &writer)
        writer.close("cac:Price")
        writer.close("cac:InvoiceLine")
    }

    private func write(_ name: String, amount: MonetaryAmount, to writer: inout XMLWriter) {
        writer.element(name, text: formatMoney(amount.value), attributes: ["currencyID": amount.currency.rawValue])
    }

    private func format(_ date: IssueDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }

    private func format(_ time: IssueTime) -> String {
        String(format: "%02d:%02d:%02d", time.hour, time.minute, time.second)
    }

    private func format(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        return formatter.string(from: value as NSDecimalNumber) ?? NSDecimalNumber(decimal: value).stringValue
    }

    private func formatMoney(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? NSDecimalNumber(decimal: value).stringValue
    }
}
