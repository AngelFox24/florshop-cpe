import Foundation

public protocol VoidedDocumentsXMLTransforming: Sendable {
    func transform(_ communication: ComunicacionBaja) throws -> String
}

/// Genera el documento SUNAT `VoidedDocuments` UBL 2.0 sin realizar envíos.
public struct VoidedDocumentsXMLTransformer: VoidedDocumentsXMLTransforming, Sendable {
    private let validator: VoidedDocumentsValidator

    public init(validator: VoidedDocumentsValidator = VoidedDocumentsValidator()) {
        self.validator = validator
    }

    public func transform(_ communication: ComunicacionBaja) throws -> String {
        try validator.validate(communication)
        let signature = SignatureInformation(
            identifier: communication.identifier.value,
            supplier: communication.supplier
        )

        var writer = XMLWriter()
        writer.declaration()
        writer.open("VoidedDocuments", attributes: [
            "xmlns": "urn:sunat:names:specification:ubl:peru:schema:xsd:VoidedDocuments-1",
            "xmlns:cac": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
            "xmlns:cbc": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2",
            "xmlns:ds": "http://www.w3.org/2000/09/xmldsig#",
            "xmlns:ext": "urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2",
            "xmlns:sac": "urn:sunat:names:specification:ubl:peru:schema:xsd:SunatAggregateComponents-1"
        ])
        writeExtensions(to: &writer)
        writer.element("cbc:UBLVersionID", text: "2.0")
        writer.element("cbc:CustomizationID", text: "1.0")
        writer.element("cbc:ID", text: communication.identifier.value)
        writer.element("cbc:ReferenceDate", text: format(communication.referenceDate))
        writer.element("cbc:IssueDate", text: format(communication.issueDate))
        write(signature, to: &writer)
        write(communication.supplier, to: &writer)
        communication.lines.forEach { write($0, to: &writer) }
        writer.close("VoidedDocuments")
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

    private func write(_ line: VoidedDocumentLine, to writer: inout XMLWriter) {
        writer.open("sac:VoidedDocumentsLine")
        writer.element("cbc:LineID", text: String(line.lineID))
        writer.element("cbc:DocumentTypeCode", text: line.documentType.rawValue)
        writer.element("sac:DocumentSerialID", text: line.documentIdentifier.series)
        writer.element("sac:DocumentNumberID", text: line.documentIdentifier.number)
        writer.element("sac:VoidReasonDescription", text: line.reason)
        writer.close("sac:VoidedDocumentsLine")
    }

    private func format(_ date: IssueDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }
}
