import Foundation

public enum DailySummaryValidationError: Error, Equatable, Sendable {
    case invalidIdentifierDate
    case generationDateBeforeReferenceDate
    case invalidSequence
    case supplierMustHaveRUC
    case invalidRUC
    case emptyLines
    case invalidLineIdentifier(Int)
    case duplicatedLineIdentifier(Int)
    case duplicatedDocument(String)
    case invalidBoletaSeries
    case invalidDocumentNumber
    case missingAffectedBoleta(Int)
    case invalidAffectedDocument(Int)
    case inconsistentSupplier
    case inconsistentReferenceDate
    case sourceDocumentMustUsePEN
    case emptySales(Int)
    case emptyTaxes(Int)
    case duplicatedSaleType(lineID: Int, type: DailySummarySaleType)
    case missingMandatorySaleType(lineID: Int, type: DailySummarySaleType)
}

public struct DailySummaryValidator: Sendable {
    public init() {}

    public func validate(_ summary: ResumenDiarioBoletas) throws {
        guard summary.identifier.date == summary.issueDate else { throw DailySummaryValidationError.invalidIdentifierDate }
        guard dateKey(summary.issueDate) >= dateKey(summary.referenceDate) else {
            throw DailySummaryValidationError.generationDateBeforeReferenceDate
        }
        guard (1 ... 99_999).contains(summary.identifier.sequence) else { throw DailySummaryValidationError.invalidSequence }
        guard summary.supplier.taxIdentifier.documentType == .ruc else { throw DailySummaryValidationError.supplierMustHaveRUC }
        guard summary.supplier.taxIdentifier.value.range(of: #"^\d{11}$"#, options: .regularExpression) != nil else {
            throw DailySummaryValidationError.invalidRUC
        }
        guard !summary.lines.isEmpty else { throw DailySummaryValidationError.emptyLines }

        var lineIDs = Set<Int>()
        var documents = Set<String>()
        for line in summary.lines {
            guard line.lineID > 0 else { throw DailySummaryValidationError.invalidLineIdentifier(line.lineID) }
            guard lineIDs.insert(line.lineID).inserted else { throw DailySummaryValidationError.duplicatedLineIdentifier(line.lineID) }
            guard documents.insert(line.documentIdentifier.value).inserted else {
                throw DailySummaryValidationError.duplicatedDocument(line.documentIdentifier.value)
            }
            guard line.documentIdentifier.series.range(of: #"^B[A-Za-z0-9]{3}$"#, options: .regularExpression) != nil else {
                throw DailySummaryValidationError.invalidBoletaSeries
            }
            guard line.documentIdentifier.number.range(of: #"^[1-9]\d{0,7}$"#, options: .regularExpression) != nil else {
                throw DailySummaryValidationError.invalidDocumentNumber
            }
            if line.documentType == .notaDeCredito || line.documentType == .notaDeDebito {
                guard let affected = line.affectedDocument else {
                    throw DailySummaryValidationError.missingAffectedBoleta(line.lineID)
                }
                guard affected.series.range(of: #"^B[A-Za-z0-9]{3}$"#, options: .regularExpression) != nil,
                      affected.number.range(of: #"^[1-9]\d{0,7}$"#, options: .regularExpression) != nil else {
                    throw DailySummaryValidationError.invalidAffectedDocument(line.lineID)
                }
            } else if line.affectedDocument != nil {
                throw DailySummaryValidationError.invalidAffectedDocument(line.lineID)
            }
            guard !line.sales.isEmpty else { throw DailySummaryValidationError.emptySales(line.lineID) }
            guard !line.taxes.isEmpty else { throw DailySummaryValidationError.emptyTaxes(line.lineID) }
            var saleTypes = Set<DailySummarySaleType>()
            for sale in line.sales where !saleTypes.insert(sale.type).inserted {
                throw DailySummaryValidationError.duplicatedSaleType(lineID: line.lineID, type: sale.type)
            }
            for mandatoryType in [DailySummarySaleType.taxable, .exempt, .unaffected]
                where !saleTypes.contains(mandatoryType) {
                throw DailySummaryValidationError.missingMandatorySaleType(
                    lineID: line.lineID,
                    type: mandatoryType
                )
            }
        }
    }

    public func validateSourceBoletas(_ boletas: [Boleta]) throws {
        guard let first = boletas.first else { throw DailySummaryValidationError.emptyLines }
        for boleta in boletas {
            try UBLInvoiceDocumentValidator().validate(boleta)
            guard boleta.currency == .pen else {
                throw DailySummaryValidationError.sourceDocumentMustUsePEN
            }
            guard boleta.supplier == first.supplier else { throw DailySummaryValidationError.inconsistentSupplier }
            guard boleta.issueDate == first.issueDate else { throw DailySummaryValidationError.inconsistentReferenceDate }
        }
    }

    private func dateKey(_ date: IssueDate) -> Int {
        date.year * 10_000 + date.month * 100 + date.day
    }
}
