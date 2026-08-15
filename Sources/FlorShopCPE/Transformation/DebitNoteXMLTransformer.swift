import Foundation

public protocol DebitNoteXMLTransforming: Sendable {
    func transform(_ note: NotaDebito) throws -> String
}

/// Genera el documento SUNAT `DebitNote` UBL 2.1 sin realizar envíos de red.
public struct DebitNoteXMLTransformer: DebitNoteXMLTransforming, Sendable {
    private let validator: DebitNoteValidator

    public init(validator: DebitNoteValidator = DebitNoteValidator()) {
        self.validator = validator
    }

    public func transform(_ note: NotaDebito) throws -> String {
        try validator.validate(note)
        try CPEAmountConsistencyValidator().validate(note)
        let signature = SignatureInformation(
            identifier: note.identifier.value,
            supplier: note.supplier
        )

        var writer = XMLWriter(documentCurrency: note.currency)
        writer.declaration()
        writer.open("DebitNote", attributes: [
            "xmlns": "urn:oasis:names:specification:ubl:schema:xsd:DebitNote-2",
            "xmlns:cac": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
            "xmlns:cbc": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2",
            "xmlns:ds": "http://www.w3.org/2000/09/xmldsig#",
            "xmlns:ext": "urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2"
        ])
        writeExtensions(to: &writer)
        writer.element("cbc:UBLVersionID", text: "2.1")
        writer.element("cbc:CustomizationID", text: "2.0")
        writer.element("cbc:ID", text: note.identifier.value)
        writer.element("cbc:IssueDate", text: format(note.issueDate))
        if let issueTime = note.issueTime {
            writer.element("cbc:IssueTime", text: format(issueTime))
        }
        note.additionalNotes.forEach {
            writer.element("cbc:Note", text: $0.value, attributes: ["languageLocaleID": $0.languageLocaleID])
        }
        writer.element("cbc:DocumentCurrencyCode", text: note.currency.rawValue)
        writeDiscrepancy(note, to: &writer)
        writeBillingReference(note.affectedDocument, to: &writer)
        write(signature, to: &writer)
        write(note.supplier, to: &writer)
        write(note.customer, to: &writer)
        write(note.taxTotal, to: &writer)
        write(note.monetaryTotal, to: &writer)
        note.lines.forEach { write($0, to: &writer) }
        writer.close("DebitNote")
        return writer.result
    }

    private func writeExtensions(to writer: inout XMLWriter) {
        writer.open("ext:UBLExtensions")
        writer.open("ext:UBLExtension")
        writer.empty("ext:ExtensionContent")
        writer.close("ext:UBLExtension")
        writer.close("ext:UBLExtensions")
    }

    private func writeDiscrepancy(_ note: NotaDebito, to writer: inout XMLWriter) {
        writer.open("cac:DiscrepancyResponse")
        writer.element("cbc:ReferenceID", text: note.affectedDocument.value)
        writer.element(
            "cbc:ResponseCode",
            text: note.reasonCode.rawValue,
            attributes: [
                "listAgencyName": "PE:SUNAT",
                "listName": "Tipo de nota de debito",
                "listURI": "urn:pe:gob:sunat:cpe:see:gem:catalogos:catalogo10"
            ]
        )
        writer.element("cbc:Description", text: note.reasonDescription)
        writer.close("cac:DiscrepancyResponse")
    }

    private func writeBillingReference(_ affected: AffectedDocumentIdentifier, to writer: inout XMLWriter) {
        writer.open("cac:BillingReference")
        writer.open("cac:InvoiceDocumentReference")
        writer.element("cbc:ID", text: affected.value)
        writer.element(
            "cbc:DocumentTypeCode",
            text: affected.type.rawValue,
            attributes: [
                "listAgencyName": "PE:SUNAT",
                "listName": "Tipo de Documento",
                "listURI": "urn:pe:gob:sunat:cpe:see:gem:catalogos:catalogo01"
            ]
        )
        writer.close("cac:InvoiceDocumentReference")
        writer.close("cac:BillingReference")
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
        writer.element("cbc:URI", text: SignatureInformation.uri)
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
        if let address = supplier.address { write(address, to: &writer) }
        writer.close("cac:PartyLegalEntity")
        writer.close("cac:Party")
        writer.close("cac:AccountingSupplierParty")
    }

    private func write(_ customer: Customer, to writer: inout XMLWriter) {
        writer.open("cac:AccountingCustomerParty")
        writer.open("cac:Party")
        write(customer.identifier, to: &writer)
        writer.open("cac:PartyLegalEntity")
        writer.element("cbc:RegistrationName", text: customer.legalName)
        if let address = customer.address { write(address, to: &writer) }
        writer.close("cac:PartyLegalEntity")
        writer.close("cac:Party")
        writer.close("cac:AccountingCustomerParty")
    }

    private func write(_ identifier: PartyIdentifier, to writer: inout XMLWriter) {
        writer.open("cac:PartyIdentification")
        writer.element("cbc:ID", text: identifier.value, attributes: ["schemeID": identifier.documentType.rawValue])
        writer.close("cac:PartyIdentification")
    }

    private func write(_ address: Address, to writer: inout XMLWriter) {
        writer.open("cac:RegistrationAddress")
        if let value = address.ubigeoCode { writer.element("cbc:ID", text: value) }
        if let value = address.addressTypeCode { writer.element("cbc:AddressTypeCode", text: value) }
        if let value = address.urbanization { writer.element("cbc:CitySubdivisionName", text: value) }
        if let value = address.city { writer.element("cbc:CityName", text: value) }
        if let value = address.department { writer.element("cbc:CountrySubentity", text: value) }
        if let value = address.district { writer.element("cbc:District", text: value) }
        writer.open("cac:AddressLine")
        writer.element("cbc:Line", text: address.line)
        writer.close("cac:AddressLine")
        writer.open("cac:Country")
        writer.element("cbc:IdentificationCode", text: address.countryCode)
        writer.close("cac:Country")
        writer.close("cac:RegistrationAddress")
    }

    private func write(_ total: TaxTotal, to writer: inout XMLWriter) {
        writer.open("cac:TaxTotal")
        write("cbc:TaxAmount", amount: total.amount, to: &writer)
        total.subtotals.forEach { subtotal in
            writer.open("cac:TaxSubtotal")
            write("cbc:TaxableAmount", amount: subtotal.taxableAmount, to: &writer)
            write("cbc:TaxAmount", amount: subtotal.taxAmount, to: &writer)
            writer.open("cac:TaxCategory")
            writeTaxCategoryIdentifier(for: subtotal.scheme, to: &writer)
            write(subtotal.scheme, to: &writer)
            writer.close("cac:TaxCategory")
            writer.close("cac:TaxSubtotal")
        }
        writer.close("cac:TaxTotal")
    }

    private func write(_ total: LineTaxTotal, to writer: inout XMLWriter) {
        writer.open("cac:TaxTotal")
        write("cbc:TaxAmount", amount: total.amount, to: &writer)
        total.subtotals.forEach { subtotal in
            writer.open("cac:TaxSubtotal")
            write("cbc:TaxableAmount", amount: subtotal.taxableAmount, to: &writer)
            write("cbc:TaxAmount", amount: subtotal.taxAmount, to: &writer)
            writer.open("cac:TaxCategory")
            writeTaxCategoryIdentifier(for: subtotal.category.scheme, to: &writer)
            if let percent = subtotal.category.percent {
                writer.element("cbc:Percent", text: writer.formatRate(percent))
            }
            if let code = subtotal.category.exemptionReasonCode {
                writer.element("cbc:TaxExemptionReasonCode", text: code.rawValue)
            }
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

    private func writeTaxCategoryIdentifier(for scheme: TaxScheme, to writer: inout XMLWriter) {
        let identifier: String
        switch scheme.identifier {
        case TaxScheme.igv.identifier: identifier = "S"
        case "9995": identifier = "G"
        case TaxScheme.gratuito.identifier: identifier = "Z"
        case "9997": identifier = "E"
        case TaxScheme.inafecto.identifier: identifier = "O"
        default: identifier = "S"
        }
        writer.element(
            "cbc:ID",
            text: identifier,
            attributes: [
                "schemeAgencyName": "United Nations Economic Commission for Europe",
                "schemeID": "UN/ECE 5305",
                "schemeName": "Tax Category Identifier"
            ]
        )
    }

    private func write(_ total: DebitNoteMonetaryTotal, to writer: inout XMLWriter) {
        writer.open("cac:RequestedMonetaryTotal")
        if let amount = total.chargeTotalAmount {
            write("cbc:ChargeTotalAmount", amount: amount, to: &writer)
        }
        if let amount = total.payableRoundingAmount {
            write("cbc:PayableRoundingAmount", amount: amount, to: &writer)
        }
        write("cbc:PayableAmount", amount: total.payableAmount, to: &writer)
        writer.close("cac:RequestedMonetaryTotal")
    }

    private func write(_ line: DebitNoteLine, to writer: inout XMLWriter) {
        writer.open("cac:DebitNoteLine")
        writer.element("cbc:ID", text: line.id)
        if let quantity = line.quantity {
            writer.element(
                "cbc:DebitedQuantity",
                text: writer.formatQuantity(quantity.value),
                attributes: [
                    "unitCode": quantity.unitCode.rawValue,
                    "unitCodeListAgencyName": "United Nations Economic Commission for Europe",
                    "unitCodeListID": "UN/ECE rec 20"
                ]
            )
        }
        write("cbc:LineExtensionAmount", amount: line.lineExtensionAmount, to: &writer)
        if !line.alternativePrices.isEmpty {
            writer.open("cac:PricingReference")
            line.alternativePrices.forEach { alternative in
                writer.open("cac:AlternativeConditionPrice")
                writer.unitPriceElement("cbc:PriceAmount", amount: alternative.amount)
                writer.element("cbc:PriceTypeCode", text: alternative.type.rawValue)
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
        if let classification = line.item.commodityClassificationCode {
            writer.open("cac:CommodityClassification")
            writer.element(
                "cbc:ItemClassificationCode",
                text: classification,
                attributes: ["listAgencyName": "GS1 US", "listID": "UNSPSC", "listName": "Item Classification"]
            )
            writer.close("cac:CommodityClassification")
        }
        writer.close("cac:Item")
        if let price = line.price {
            writer.open("cac:Price")
            writer.unitPriceElement("cbc:PriceAmount", amount: price)
            writer.close("cac:Price")
        }
        writer.close("cac:DebitNoteLine")
    }

    private func write(_ name: String, amount: MonetaryAmount, to writer: inout XMLWriter) {
        writer.monetaryElement(name, amount: amount)
    }

    private func format(_ date: IssueDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }

    private func format(_ time: IssueTime) -> String {
        String(format: "%02d:%02d:%02d", time.hour, time.minute, time.second)
    }

}
