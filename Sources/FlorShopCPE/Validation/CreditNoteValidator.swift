import Foundation

public enum CreditNoteValidationError: Error, Equatable, Sendable {
    case invalidSeries(expectedPrefix: String)
    case invalidAffectedDocumentSeries(expectedPrefix: String)
    case invalidNumber
    case emptyReasonDescription
    case reasonDescriptionTooLong
    case reasonNotAllowedForBoleta(CreditNoteReasonCode)
    case supplierMustHaveRUC
    case facturaCustomerMustHaveRUC
    case invalidRUC
    case invalidSupplierAddressTypeCode
    case emptyLines
    case duplicatedLineIdentifier(String)
    case invalidPayableRoundingAmount
}

/// Verifica las invariantes de una Nota de Crédito antes de serializarla o firmarla.
public struct CreditNoteValidator: Sendable {
    public init() {}

    public func validate(_ note: NotaCredito) throws {
        let expectedPrefix = note.affectedDocument.type == .factura ? "F" : "B"
        try validateSeries(note.identifier.series, prefix: expectedPrefix, affected: false)
        try validateSeries(note.affectedDocument.series, prefix: expectedPrefix, affected: true)
        guard isValidNumber(note.identifier.number), isValidNumber(note.affectedDocument.number) else {
            throw CreditNoteValidationError.invalidNumber
        }

        let description = note.reasonDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { throw CreditNoteValidationError.emptyReasonDescription }
        guard description.count <= 250 else { throw CreditNoteValidationError.reasonDescriptionTooLong }
        if note.affectedDocument.type == .boleta,
           [.descuentoGlobal, .descuentoPorItem, .bonificacion].contains(note.reasonCode) {
            throw CreditNoteValidationError.reasonNotAllowedForBoleta(note.reasonCode)
        }

        guard note.supplier.taxIdentifier.documentType == .ruc else {
            throw CreditNoteValidationError.supplierMustHaveRUC
        }
        guard isRUC(note.supplier.taxIdentifier.value) else {
            throw CreditNoteValidationError.invalidRUC
        }
        if note.affectedDocument.type == .factura {
            guard note.customer.identifier.documentType == .ruc else {
                throw CreditNoteValidationError.facturaCustomerMustHaveRUC
            }
            guard isRUC(note.customer.identifier.value) else {
                throw CreditNoteValidationError.invalidRUC
            }
        }
        if let code = note.supplier.address?.addressTypeCode,
           code.range(of: #"^\d{4}$"#, options: .regularExpression) == nil {
            throw CreditNoteValidationError.invalidSupplierAddressTypeCode
        }

        guard !note.lines.isEmpty else { throw CreditNoteValidationError.emptyLines }
        var identifiers = Set<String>()
        for line in note.lines where !identifiers.insert(line.id).inserted {
            throw CreditNoteValidationError.duplicatedLineIdentifier(line.id)
        }
        if let rounding = note.monetaryTotal.payableRoundingAmount,
           abs(CPEPrecision.monetary(rounding.value)) > 1 {
            throw CreditNoteValidationError.invalidPayableRoundingAmount
        }
    }

    private func validateSeries(_ series: String, prefix: String, affected: Bool) throws {
        let pattern = "^\(prefix)[A-Za-z0-9]{3}$"
        guard series.range(of: pattern, options: .regularExpression) != nil else {
            if affected {
                throw CreditNoteValidationError.invalidAffectedDocumentSeries(expectedPrefix: prefix)
            }
            throw CreditNoteValidationError.invalidSeries(expectedPrefix: prefix)
        }
    }

    private func isValidNumber(_ value: String) -> Bool {
        value.range(of: #"^[1-9]\d{0,7}$"#, options: .regularExpression) != nil
    }

    private func isRUC(_ value: String) -> Bool {
        value.range(of: #"^\d{11}$"#, options: .regularExpression) != nil
    }

}
