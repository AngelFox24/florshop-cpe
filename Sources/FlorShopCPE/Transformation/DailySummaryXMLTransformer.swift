import Foundation

public protocol DailySummaryXMLTransforming: Sendable {
    func transform(_ summary: ResumenDiarioBoletas) throws -> String
}

/// Genera el `SummaryDocuments` UBL 2.0 exigido por SUNAT.
public struct DailySummaryXMLTransformer: DailySummaryXMLTransforming, Sendable {
    private let validator: DailySummaryValidator

    public init(validator: DailySummaryValidator = DailySummaryValidator()) {
        self.validator = validator
    }

    public func transform(_ summary: ResumenDiarioBoletas) throws -> String {
        try validator.validate(summary)
        let signature = SignatureInformation(
            identifier: summary.identifier.value,
            supplier: summary.supplier
        )

        var writer = XMLWriter(documentCurrency: .pen)
        writer.declaration()
        writer.open("SummaryDocuments", attributes: [
            "xmlns": "urn:sunat:names:specification:ubl:peru:schema:xsd:SummaryDocuments-1",
            "xmlns:cac": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
            "xmlns:cbc": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2",
            "xmlns:ds": "http://www.w3.org/2000/09/xmldsig#",
            "xmlns:ext": "urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2",
            "xmlns:sac": "urn:sunat:names:specification:ubl:peru:schema:xsd:SunatAggregateComponents-1"
        ])
        writeExtensions(to: &writer)
        writer.element("cbc:UBLVersionID", text: "2.0")
        writer.element("cbc:CustomizationID", text: "1.1")
        writer.element("cbc:ID", text: summary.identifier.value)
        writer.element("cbc:ReferenceDate", text: format(summary.referenceDate))
        writer.element("cbc:IssueDate", text: format(summary.issueDate))
        write(signature, to: &writer)
        write(summary.supplier, to: &writer)
        summary.lines.forEach { write($0, to: &writer) }
        writer.close("SummaryDocuments")
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
        writer.element("cbc:URI", text: SignatureInformation.uri)
        writer.close("cac:ExternalReference")
        writer.close("cac:DigitalSignatureAttachment")
        writer.close("cac:Signature")
    }

    private func write(_ supplier: Supplier, to writer: inout XMLWriter) {
        writer.open("cac:AccountingSupplierParty")
        writer.element("cbc:CustomerAssignedAccountID", text: supplier.taxIdentifier.value)
        writer.element("cbc:AdditionalAccountID", text: supplier.taxIdentifier.documentType.rawValue)
        writer.open("cac:Party")
        writer.open("cac:PartyLegalEntity")
        writer.element("cbc:RegistrationName", text: supplier.legalName)
        writer.close("cac:PartyLegalEntity")
        writer.close("cac:Party")
        writer.close("cac:AccountingSupplierParty")
    }

    private func write(_ line: DailySummaryLine, to writer: inout XMLWriter) {
        writer.open("sac:SummaryDocumentsLine")
        writer.element("cbc:LineID", text: String(line.lineID))
        writer.element("cbc:DocumentTypeCode", text: line.documentType.rawValue)
        writer.element("cbc:ID", text: line.documentIdentifier.value)
        writer.open("cac:AccountingCustomerParty")
        writer.element("cbc:CustomerAssignedAccountID", text: line.customerIdentifier.value)
        writer.element("cbc:AdditionalAccountID", text: line.customerIdentifier.documentType.rawValue)
        if let legalName = line.customerLegalName {
            writer.open("cac:Party")
            writer.open("cac:PartyLegalEntity")
            writer.element("cbc:RegistrationName", text: legalName)
            writer.close("cac:PartyLegalEntity")
            writer.close("cac:Party")
        }
        writer.close("cac:AccountingCustomerParty")
        if let affected = line.affectedDocument {
            writer.open("cac:BillingReference")
            writer.open("cac:InvoiceDocumentReference")
            writer.element("cbc:ID", text: affected.value)
            writer.element(
                "cbc:DocumentTypeCode",
                text: AffectedInvoiceDocumentType.boleta.rawValue
            )
            writer.close("cac:InvoiceDocumentReference")
            writer.close("cac:BillingReference")
        }
        writer.open("cac:Status")
        writer.element("cbc:ConditionCode", text: line.condition.rawValue)
        writer.close("cac:Status")
        write("sac:TotalAmount", amount: line.totalAmount, to: &writer)
        line.sales.forEach { sale in
            writer.open("sac:BillingPayment")
            write("cbc:PaidAmount", amount: sale.amount, to: &writer)
            writer.element("cbc:InstructionID", text: sale.type.rawValue)
            writer.close("sac:BillingPayment")
        }
        if let charge = line.chargeTotalAmount {
            writer.open("cac:AllowanceCharge")
            writer.element("cbc:ChargeIndicator", text: "true")
            write("cbc:Amount", amount: charge, to: &writer)
            writer.close("cac:AllowanceCharge")
        }
        line.taxes.forEach { write($0, to: &writer) }
        writer.close("sac:SummaryDocumentsLine")
    }

    private func write(_ tax: DailySummaryTax, to writer: inout XMLWriter) {
        writer.open("cac:TaxTotal")
        write("cbc:TaxAmount", amount: tax.amount, to: &writer)
        writer.open("cac:TaxSubtotal")
        write("cbc:TaxAmount", amount: tax.amount, to: &writer)
        writer.open("cac:TaxCategory")
        if let percent = tax.percent {
            writer.element("cbc:Percent", text: formatDecimal(percent))
        }
        writer.open("cac:TaxScheme")
        writer.element("cbc:ID", text: tax.scheme.identifier)
        writer.element("cbc:Name", text: tax.scheme.name)
        writer.element("cbc:TaxTypeCode", text: tax.scheme.typeCode)
        writer.close("cac:TaxScheme")
        writer.close("cac:TaxCategory")
        writer.close("cac:TaxSubtotal")
        writer.close("cac:TaxTotal")
    }

    private func write(_ name: String, amount: MonetaryAmount, to writer: inout XMLWriter) {
        writer.monetaryElement(name, amount: amount)
    }

    private func format(_ date: IssueDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }

    private func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
