import Foundation

/// Genera el XML UBL 2.1 de una factura o boleta sin enviarlo a SUNAT.
public struct UBLInvoiceXMLTransformer: UBLInvoiceXMLTransforming, Sendable {
    private let amountInWordsFormatter: any AmountInWordsFormatting
    private let validator: UBLInvoiceDocumentValidator

    public init(
        amountInWordsFormatter: any AmountInWordsFormatting = SpanishAmountInWordsFormatter(),
        validator: UBLInvoiceDocumentValidator = UBLInvoiceDocumentValidator()
    ) {
        self.amountInWordsFormatter = amountInWordsFormatter
        self.validator = validator
    }

    public func transform(_ document: any UBLInvoiceDocument) throws -> String {
        try validator.validate(document)
        try CPEAmountConsistencyValidator().validate(document)
        let signature = SignatureInformation(
            identifier: document.identifier.value,
            supplier: document.supplier
        )

        var writer = XMLWriter(documentCurrency: document.currency)
        writer.declaration()
        writer.open("Invoice", attributes: [
            "xmlns": "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2",
            "xmlns:cac": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
            "xmlns:cbc": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2",
            "xmlns:ds": "http://www.w3.org/2000/09/xmldsig#",
            "xmlns:ext": "urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2"
        ])

        writeExtensions(to: &writer)
        writer.element("cbc:UBLVersionID", text: "2.1")
        writer.element("cbc:CustomizationID", text: "2.0")
        writer.element(
            "cbc:ProfileID",
            text: "0101",
            attributes: [
                "schemeName": "SUNAT:Identificador de Tipo de Operación",
                "schemeAgencyName": "PE:SUNAT",
                "schemeURI": "urn:pe:gob:sunat:cpe:see:gem:catalogos:catalogo17"
            ]
        )
        writer.element("cbc:ID", text: document.identifier.value)
        writer.element("cbc:IssueDate", text: format(document.issueDate))
        if let issueTime = document.issueTime {
            writer.element("cbc:IssueTime", text: format(issueTime))
        }
        writer.element(
            "cbc:InvoiceTypeCode",
            text: document.documentType.rawValue,
            attributes: [
                "listAgencyName": "PE:SUNAT",
                "listID": "0101",
                "listName": "Tipo de Documento",
                "listSchemeURI": "urn:pe:gob:sunat:cpe:see:gem:catalogos:catalogo51",
                "listURI": "urn:pe:gob:sunat:cpe:see:gem:catalogos:catalogo01",
                "name": "Tipo de Operacion"
            ]
        )
        let note = try amountInWordsFormatter.format(
            CPEPrecision.monetary(document.monetaryTotal.payableAmount.value),
            currency: document.currency
        )
        writer.element("cbc:Note", text: note, attributes: ["languageLocaleID": "1000"])
        document.additionalNotes.forEach { note in
            writer.element(
                "cbc:Note",
                text: note.value,
                attributes: ["languageLocaleID": note.languageLocaleID]
            )
        }
        writer.element("cbc:DocumentCurrencyCode", text: document.currency.rawValue)

        if let factura = document as? Factura {
            writeReferences(factura, to: &writer)
        }
        write(signature, to: &writer)
        write(document.supplier, to: &writer)
        write(document.customer, to: &writer)
        if let factura = document as? Factura {
            writeCommercialTerms(factura, to: &writer)
        }
        write(document.taxTotal, to: &writer)
        write(document.monetaryTotal, to: &writer)
        document.lines.forEach { write($0, to: &writer) }

        writer.close("Invoice")
        return writer.result
    }

    private func writeReferences(_ factura: Factura, to writer: inout XMLWriter) {
        if let orderReference = factura.orderReference {
            writer.open("cac:OrderReference")
            writer.element("cbc:ID", text: orderReference)
            writer.close("cac:OrderReference")
        }
        factura.despatchDocumentReferences.forEach { reference in
            writer.open("cac:DespatchDocumentReference")
            writer.element("cbc:ID", text: reference.identifier)
            writer.element("cbc:DocumentTypeCode", text: reference.documentTypeCode)
            if let description = reference.documentTypeDescription {
                writer.element("cbc:DocumentType", text: description)
            }
            writer.close("cac:DespatchDocumentReference")
        }
    }

    private func writeCommercialTerms(_ factura: Factura, to writer: inout XMLWriter) {
        if let buyerAddress = factura.buyerAddress {
            writer.open("cac:BuyerCustomerParty")
            writer.open("cac:Party")
            writer.open("cac:PartyLegalEntity")
            write(buyerAddress, to: &writer)
            writer.close("cac:PartyLegalEntity")
            writer.close("cac:Party")
            writer.close("cac:BuyerCustomerParty")
        }
        write(factura.paymentCondition, to: &writer)
        factura.allowanceCharges.forEach { allowance in
            writer.open("cac:AllowanceCharge")
            writer.element("cbc:ChargeIndicator", text: allowance.isCharge ? "true" : "false")
            if let reasonCode = allowance.reasonCode {
                writer.element("cbc:AllowanceChargeReasonCode", text: reasonCode)
            }
            if let multiplierFactor = allowance.multiplierFactor {
                writer.element("cbc:MultiplierFactorNumeric", text: writer.formatRate(multiplierFactor))
            }
            write("cbc:Amount", amount: allowance.amount, to: &writer)
            if let baseAmount = allowance.baseAmount {
                write("cbc:BaseAmount", amount: baseAmount, to: &writer)
            }
            writer.close("cac:AllowanceCharge")
        }
    }

    private func write(_ condition: PaymentCondition, to writer: inout XMLWriter) {
        switch condition {
        case .cash:
            writer.open("cac:PaymentTerms")
            writer.element("cbc:ID", text: "FormaPago")
            writer.element("cbc:PaymentMeansID", text: "Contado")
            writer.close("cac:PaymentTerms")

        case let .credit(installments):
            writer.open("cac:PaymentTerms")
            writer.element("cbc:ID", text: "FormaPago")
            writer.element("cbc:PaymentMeansID", text: "Credito")
            if let pendingAmount = condition.pendingAmount {
                write("cbc:Amount", amount: pendingAmount, to: &writer)
            }
            writer.close("cac:PaymentTerms")

            for (index, installment) in installments.enumerated() {
                writer.open("cac:PaymentTerms")
                writer.element("cbc:ID", text: "FormaPago")
                writer.element(
                    "cbc:PaymentMeansID",
                    text: String(format: "Cuota%03d", index + 1)
                )
                write("cbc:Amount", amount: installment.amount, to: &writer)
                writer.element("cbc:PaymentDueDate", text: format(installment.dueDate))
                writer.close("cac:PaymentTerms")
            }
        }
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
        if let address = customer.address {
            write(address, to: &writer)
        }
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
            writeTaxCategoryIdentifier(for: subtotal.scheme, to: &writer)
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
            writeTaxCategoryIdentifier(for: subtotal.category.scheme, to: &writer)
            if let percent = subtotal.category.percent {
                writer.element("cbc:Percent", text: writer.formatRate(percent))
            }
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

    private func writeTaxCategoryIdentifier(
        for scheme: TaxScheme,
        to writer: inout XMLWriter
    ) {
        let identifier: String
        switch scheme.identifier {
        case TaxScheme.igv.identifier:
            identifier = "S"
        case TaxScheme.exportacion.identifier:
            identifier = "G"
        case TaxScheme.gratuito.identifier:
            identifier = "Z"
        case "9997":
            identifier = "E"
        case TaxScheme.inafecto.identifier:
            identifier = "O"
        default:
            identifier = "S"
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

    private func write(_ total: MonetaryTotal, to writer: inout XMLWriter) {
        writer.open("cac:LegalMonetaryTotal")
        write("cbc:LineExtensionAmount", amount: total.lineExtensionAmount, to: &writer)
        write("cbc:TaxInclusiveAmount", amount: total.taxInclusiveAmount, to: &writer)
        if let amount = total.allowanceTotalAmount {
            write("cbc:AllowanceTotalAmount", amount: amount, to: &writer)
        }
        if let amount = total.chargeTotalAmount {
            write("cbc:ChargeTotalAmount", amount: amount, to: &writer)
        }
        if let amount = total.prepaidAmount {
            write("cbc:PrepaidAmount", amount: amount, to: &writer)
        }
        if let amount = total.payableRoundingAmount {
            write("cbc:PayableRoundingAmount", amount: amount, to: &writer)
        }
        write("cbc:PayableAmount", amount: total.payableAmount, to: &writer)
        writer.close("cac:LegalMonetaryTotal")
    }

    private func write(_ line: InvoiceLine, to writer: inout XMLWriter) {
        writer.open("cac:InvoiceLine")
        writer.element("cbc:ID", text: line.id)
        writer.element(
            "cbc:InvoicedQuantity",
            text: writer.formatQuantity(line.quantity.value),
            attributes: ["unitCode": line.quantity.unitCode.rawValue]
        )
        write("cbc:LineExtensionAmount", amount: line.lineExtensionAmount, to: &writer)
        if let isFreeOfCharge = line.isFreeOfCharge {
            writer.element(
                "cbc:FreeOfChargeIndicator",
                text: isFreeOfCharge ? "true" : "false"
            )
        }
        if !line.alternativePrices.isEmpty {
            writer.open("cac:PricingReference")
            line.alternativePrices.forEach { alternativePrice in
                writer.open("cac:AlternativeConditionPrice")
                writer.unitPriceElement("cbc:PriceAmount", amount: alternativePrice.amount)
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
        if let classificationCode = line.item.commodityClassificationCode {
            writer.open("cac:CommodityClassification")
            writer.element(
                "cbc:ItemClassificationCode",
                text: classificationCode,
                attributes: [
                    "listAgencyName": "GS1 US",
                    "listID": "UNSPSC",
                    "listName": "Item Classification"
                ]
            )
            writer.close("cac:CommodityClassification")
        }
        writer.close("cac:Item")
        writer.open("cac:Price")
        writer.unitPriceElement("cbc:PriceAmount", amount: line.price)
        writer.close("cac:Price")
        writer.close("cac:InvoiceLine")
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
