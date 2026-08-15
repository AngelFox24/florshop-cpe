import Foundation

public enum DebitNoteValidationError: Error, Equatable, Sendable {
    case invalidSeries(expectedPrefix: String)
    case invalidAffectedDocumentSeries(expectedPrefix: String)
    case invalidNumber
    case emptyReasonDescription
    case invalidReasonDescriptionWhitespace
    case reasonDescriptionTooLong
    case supplierMustHaveRUC
    case facturaCustomerMustHaveRUC
    case invalidRUC
    case missingSupplierAddressTypeCode
    case invalidSupplierAddressTypeCode
    case emptyLines
    case invalidLineIdentifier(String)
    case duplicatedLineIdentifier(String)
    case nonPositiveQuantity(String)
    case nonPositiveLineExtensionAmount(String)
    case nonPositivePrice(String)
    case invalidTaxPercent(String)
    case nonPositiveChargeTotalAmount
    case nonPositivePayableAmount
    case invalidPayableRoundingAmount
}

/// Verifica las invariantes locales exigibles antes de serializar o firmar una
/// Nota de Débito. La existencia y estado del comprobante afectado corresponde
/// validarla a SUNAT u OSE porque requiere consultar sus registros.
public struct DebitNoteValidator: Sendable {
    public init() {}

    public func validate(_ note: NotaDebito) throws {
        let expectedPrefix = note.affectedDocument.type == .factura ? "F" : "B"
        try validateSeries(note.identifier.series, prefix: expectedPrefix, affected: false)
        try validateSeries(note.affectedDocument.series, prefix: expectedPrefix, affected: true)
        guard isValidNumber(note.identifier.number), isValidNumber(note.affectedDocument.number) else {
            throw DebitNoteValidationError.invalidNumber
        }

        let description = note.reasonDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { throw DebitNoteValidationError.emptyReasonDescription }
        guard note.reasonDescription.count <= 500 else {
            throw DebitNoteValidationError.reasonDescriptionTooLong
        }
        let forbiddenWhitespace = CharacterSet(charactersIn: "\t\r\n")
        guard note.reasonDescription.rangeOfCharacter(from: forbiddenWhitespace) == nil else {
            throw DebitNoteValidationError.invalidReasonDescriptionWhitespace
        }

        guard note.supplier.taxIdentifier.documentType == .ruc else {
            throw DebitNoteValidationError.supplierMustHaveRUC
        }
        guard isRUC(note.supplier.taxIdentifier.value) else {
            throw DebitNoteValidationError.invalidRUC
        }
        if note.affectedDocument.type == .factura {
            guard note.customer.identifier.documentType == .ruc else {
                throw DebitNoteValidationError.facturaCustomerMustHaveRUC
            }
            guard isRUC(note.customer.identifier.value) else {
                throw DebitNoteValidationError.invalidRUC
            }
        }
        guard let addressTypeCode = note.supplier.address?.addressTypeCode else {
            throw DebitNoteValidationError.missingSupplierAddressTypeCode
        }
        guard addressTypeCode.range(of: #"^\d{4}$"#, options: .regularExpression) != nil else {
            throw DebitNoteValidationError.invalidSupplierAddressTypeCode
        }

        guard !note.lines.isEmpty else { throw DebitNoteValidationError.emptyLines }
        var identifiers = Set<String>()
        for line in note.lines {
            guard line.id.range(of: #"^[1-9]\d{0,2}$"#, options: .regularExpression) != nil else {
                throw DebitNoteValidationError.invalidLineIdentifier(line.id)
            }
            guard identifiers.insert(line.id).inserted else {
                throw DebitNoteValidationError.duplicatedLineIdentifier(line.id)
            }
            if let quantity = line.quantity, CPEPrecision.unitValue(quantity.value) <= 0 {
                throw DebitNoteValidationError.nonPositiveQuantity(line.id)
            }
            guard CPEPrecision.monetary(line.lineExtensionAmount.value) > 0 else {
                throw DebitNoteValidationError.nonPositiveLineExtensionAmount(line.id)
            }
            if let price = line.price, CPEPrecision.unitValue(price.value) <= 0 {
                throw DebitNoteValidationError.nonPositivePrice(line.id)
            }
            if let percent = line.taxCategory.percent,
               percent < 0 || percent > 100 {
                throw DebitNoteValidationError.invalidTaxPercent(line.id)
            }
        }
        if let charge = note.monetaryTotal.chargeTotalAmount,
           CPEPrecision.monetary(charge.value) <= 0 {
            throw DebitNoteValidationError.nonPositiveChargeTotalAmount
        }
        guard CPEPrecision.monetary(note.monetaryTotal.payableAmount.value) > 0 else {
            throw DebitNoteValidationError.nonPositivePayableAmount
        }
        if let rounding = note.monetaryTotal.payableRoundingAmount,
           abs(CPEPrecision.monetary(rounding.value)) > 1 {
            throw DebitNoteValidationError.invalidPayableRoundingAmount
        }
    }

    private func validateSeries(_ series: String, prefix: String, affected: Bool) throws {
        let pattern = "^\(prefix)[A-Za-z0-9]{3}$"
        guard series.range(of: pattern, options: .regularExpression) != nil else {
            if affected {
                throw DebitNoteValidationError.invalidAffectedDocumentSeries(expectedPrefix: prefix)
            }
            throw DebitNoteValidationError.invalidSeries(expectedPrefix: prefix)
        }
    }

    private func isValidNumber(_ value: String) -> Bool {
        value.range(of: #"^[1-9]\d{0,7}$"#, options: .regularExpression) != nil
    }

    private func isRUC(_ value: String) -> Bool {
        value.range(of: #"^\d{11}$"#, options: .regularExpression) != nil
    }

}
