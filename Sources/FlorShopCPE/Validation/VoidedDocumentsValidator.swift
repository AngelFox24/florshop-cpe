import Foundation

public enum VoidedDocumentsValidationError: Error, Equatable, Sendable {
    case invalidIdentifierDate
    case generationDateBeforeReferenceDate
    case invalidSequence
    case supplierMustHaveRUC
    case invalidRUC
    case invalidSupplierLegalName
    case emptyLines
    case invalidLineIdentifier(Int)
    case duplicatedLineIdentifier(Int)
    case unsupportedDocumentType(ElectronicDocumentType)
    case invalidDocumentSeries(String)
    case invalidDocumentNumber(String)
    case duplicatedDocument(String)
    case invalidReason(lineID: Int)
}

/// Valida las reglas que pueden comprobarse localmente antes de generar una
/// Comunicación de Baja. La existencia, aceptación previa y plazo medido
/// contra la fecha real de recepción corresponden a SUNAT u OSE.
public struct VoidedDocumentsValidator: Sendable {
    public init() {}

    public func validate(_ communication: ComunicacionBaja) throws {
        guard communication.identifier.date == communication.issueDate else {
            throw VoidedDocumentsValidationError.invalidIdentifierDate
        }
        guard dateKey(communication.issueDate) >= dateKey(communication.referenceDate) else {
            throw VoidedDocumentsValidationError.generationDateBeforeReferenceDate
        }
        guard (1 ... 99_999).contains(communication.identifier.sequence) else {
            throw VoidedDocumentsValidationError.invalidSequence
        }
        guard communication.supplier.taxIdentifier.documentType == .ruc else {
            throw VoidedDocumentsValidationError.supplierMustHaveRUC
        }
        guard communication.supplier.taxIdentifier.value.range(
            of: #"^\d{11}$"#,
            options: .regularExpression
        ) != nil else {
            throw VoidedDocumentsValidationError.invalidRUC
        }
        let legalName = communication.supplier.legalName
        let forbiddenWhitespace = CharacterSet(charactersIn: "\t\r\n")
        guard (3 ... 100).contains(legalName.count),
              !legalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              legalName.rangeOfCharacter(from: forbiddenWhitespace) == nil else {
            throw VoidedDocumentsValidationError.invalidSupplierLegalName
        }
        guard !communication.lines.isEmpty else {
            throw VoidedDocumentsValidationError.emptyLines
        }

        var lineIDs = Set<Int>()
        var documents = Set<String>()
        for line in communication.lines {
            guard (1 ... 99_999).contains(line.lineID) else {
                throw VoidedDocumentsValidationError.invalidLineIdentifier(line.lineID)
            }
            guard lineIDs.insert(line.lineID).inserted else {
                throw VoidedDocumentsValidationError.duplicatedLineIdentifier(line.lineID)
            }
            guard [.factura, .notaDeCredito, .notaDeDebito].contains(line.documentIdentifier.type) else {
                throw VoidedDocumentsValidationError.unsupportedDocumentType(line.documentIdentifier.type)
            }
            guard isValidSeries(line.documentIdentifier.series) else {
                throw VoidedDocumentsValidationError.invalidDocumentSeries(line.documentIdentifier.series)
            }
            guard line.documentIdentifier.number.range(
                of: #"^[1-9]\d{0,7}$"#,
                options: .regularExpression
            ) != nil else {
                throw VoidedDocumentsValidationError.invalidDocumentNumber(line.documentIdentifier.number)
            }
            let documentKey = "\(line.documentIdentifier.type.rawValue)-\(line.documentIdentifier.value)"
            guard documents.insert(documentKey).inserted else {
                throw VoidedDocumentsValidationError.duplicatedDocument(line.documentIdentifier.value)
            }
            guard (3 ... 100).contains(line.reason.count),
                  !line.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  line.reason.rangeOfCharacter(from: forbiddenWhitespace) == nil else {
                throw VoidedDocumentsValidationError.invalidReason(lineID: line.lineID)
            }
        }
    }

    private func isValidSeries(_ value: String) -> Bool {
        value.range(of: #"^F[A-Z0-9]{3}$"#, options: .regularExpression) != nil
            || value.range(of: #"^\d{1,4}$"#, options: .regularExpression) != nil
    }

    private func dateKey(_ date: IssueDate) -> Int {
        date.year * 10_000 + date.month * 100 + date.day
    }
}
