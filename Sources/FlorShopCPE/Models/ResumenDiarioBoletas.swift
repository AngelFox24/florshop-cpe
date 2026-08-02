import Foundation

/// Identificador SUNAT de un Resumen Diario (`RC-YYYYMMDD-correlativo`).
public struct DailySummaryIdentifier: Codable, Equatable, Sendable {
    public let date: IssueDate
    public let sequence: Int

    public init(date: IssueDate, sequence: Int) {
        self.date = date
        self.sequence = sequence
    }

    public var value: String {
        String(format: "RC-%04d%02d%02d-%05d", date.year, date.month, date.day, sequence)
    }
}

public enum DailySummaryCondition: String, Codable, Sendable {
    case add = "1"
    case modify = "2"
    case void = "3"
}

/// Clasificación de importes de venta del catálogo 11 de SUNAT.
public enum DailySummarySaleType: String, Codable, Sendable {
    case taxable = "01"
    case exempt = "02"
    case unaffected = "03"
    case export = "04"
    case freeTaxable = "06"
    case freeExempt = "07"
    case freeUnaffected = "08"
    case freeExport = "09"
}

/// Tributo agregado de una línea del Resumen Diario.
///
/// La tasa se conserva porque SUNAT la exige también para operaciones gratuitas.
public struct DailySummaryTax: Codable, Equatable, Sendable {
    public let amount: MonetaryAmount
    public let percent: Decimal?
    public let scheme: TaxScheme

    public init(amount: MonetaryAmount, percent: Decimal? = nil, scheme: TaxScheme) {
        self.amount = amount
        self.percent = percent
        self.scheme = scheme
    }
}

public struct DailySummarySale: Codable, Equatable, Sendable {
    public let type: DailySummarySaleType
    public let amount: MonetaryAmount

    public init(type: DailySummarySaleType, amount: MonetaryAmount) {
        self.type = type
        self.amount = amount
    }
}

/// Una línea agregada del Resumen Diario. No contiene el detalle de productos.
public struct DailySummaryLine: Codable, Equatable, Sendable {
    public let lineID: Int
    public let documentType: ElectronicDocumentType
    public let documentIdentifier: DocumentIdentifier
    public let customerIdentifier: PartyIdentifier
    public let customerLegalName: String?
    /// Boleta modificada por una nota de crédito o débito.
    public let affectedDocument: DocumentIdentifier?
    public let condition: DailySummaryCondition
    public let totalAmount: MonetaryAmount
    public let sales: [DailySummarySale]
    public let chargeTotalAmount: MonetaryAmount?
    public let taxes: [DailySummaryTax]

    public init(
        lineID: Int,
        documentType: ElectronicDocumentType,
        documentIdentifier: DocumentIdentifier,
        customerIdentifier: PartyIdentifier,
        customerLegalName: String? = nil,
        affectedDocument: DocumentIdentifier? = nil,
        condition: DailySummaryCondition,
        totalAmount: MonetaryAmount,
        sales: [DailySummarySale],
        chargeTotalAmount: MonetaryAmount? = nil,
        taxes: [DailySummaryTax]
    ) {
        self.lineID = lineID
        self.documentType = documentType
        self.documentIdentifier = documentIdentifier
        self.customerIdentifier = customerIdentifier
        self.customerLegalName = customerLegalName
        self.affectedDocument = affectedDocument
        self.condition = condition
        self.totalAmount = totalAmount
        self.sales = sales
        self.chargeTotalAmount = chargeTotalAmount
        self.taxes = taxes
    }

    /// Deriva de una boleta los importes exigidos por `SummaryDocumentsLine`.
    public init(lineID: Int, boleta: Boleta, condition: DailySummaryCondition = .add) {
        self.init(
            lineID: lineID,
            documentType: .boleta,
            documentIdentifier: boleta.identifier,
            customerIdentifier: boleta.customer.identifier,
            customerLegalName: boleta.customer.legalName,
            affectedDocument: nil,
            condition: condition,
            totalAmount: boleta.monetaryTotal.taxInclusiveAmount,
            sales: Self.sales(from: boleta),
            chargeTotalAmount: boleta.monetaryTotal.chargeTotalAmount,
            taxes: Self.taxes(from: boleta)
        )
    }

    /// Deriva la línea `07` exigida por el Resumen Diario para una Nota de
    /// Crédito asociada a una boleta. Las notas de facturas se envían de forma
    /// individual mediante `sendBill` y no pueden convertirse con esta API.
    public init(
        lineID: Int,
        creditNote: NotaCredito,
        condition: DailySummaryCondition = .add
    ) throws {
        guard creditNote.affectedDocument.type == .boleta else {
            throw DailySummaryValidationError.invalidAffectedDocument(lineID)
        }
        try CreditNoteValidator().validate(creditNote)
        self.init(
            lineID: lineID,
            documentType: .notaDeCredito,
            documentIdentifier: creditNote.identifier,
            customerIdentifier: creditNote.customer.identifier,
            customerLegalName: creditNote.customer.legalName,
            affectedDocument: creditNote.affectedDocument,
            condition: condition,
            totalAmount: creditNote.monetaryTotal.payableAmount,
            sales: Self.sales(from: creditNote),
            chargeTotalAmount: creditNote.monetaryTotal.chargeTotalAmount,
            taxes: Self.taxes(from: creditNote)
        )
    }

    private static func sales(from boleta: Boleta) -> [DailySummarySale] {
        var totals: [DailySummarySaleType: Decimal] = [:]
        for line in boleta.lines {
            for subtotal in line.taxTotal.subtotals {
                let type = saleType(for: subtotal.category)
                totals[type, default: 0] += subtotal.taxableAmount.value
            }
        }
        return DailySummarySaleType.sunatOrder.compactMap { type in
            let isMandatory = [.taxable, .exempt, .unaffected].contains(type)
            guard isMandatory || totals[type] != nil else { return nil }
            return DailySummarySale(
                type: type,
                amount: MonetaryAmount(value: totals[type, default: 0], currency: boleta.currency)
            )
        }
    }

    private static func sales(from note: NotaCredito) -> [DailySummarySale] {
        var totals: [DailySummarySaleType: Decimal] = [:]
        for line in note.lines {
            for subtotal in line.taxTotal.subtotals {
                let type = saleType(for: subtotal.category)
                totals[type, default: 0] += subtotal.taxableAmount.value
            }
        }
        return DailySummarySaleType.sunatOrder.compactMap { type in
            let isMandatory = [.taxable, .exempt, .unaffected].contains(type)
            guard isMandatory || totals[type] != nil else { return nil }
            return DailySummarySale(
                type: type,
                amount: MonetaryAmount(value: totals[type, default: 0], currency: note.currency)
            )
        }
    }

    private static func saleType(for category: TaxCategory) -> DailySummarySaleType {
        let isFree = category.scheme.identifier == TaxScheme.gratuito.identifier
        switch category.exemptionReasonCode {
        case .gravadoOperacionOnerosa: return isFree ? .freeTaxable : .taxable
        case .exonerado: return isFree ? .freeExempt : .exempt
        case .inafecto, .inafectoRetiroPorBonificacion: return isFree ? .freeUnaffected : .unaffected
        case .exportacion: return isFree ? .freeExport : .export
        case nil:
            if isFree { return .freeUnaffected }
            return category.scheme.identifier == TaxScheme.igv.identifier ? .taxable : .unaffected
        }
    }

    private static func taxes(from boleta: Boleta) -> [DailySummaryTax] {
        boleta.taxTotal.subtotals.map { subtotal in
            let percent = boleta.lines
                .lazy
                .flatMap(\.taxTotal.subtotals)
                .first(where: { $0.category.scheme.identifier == subtotal.scheme.identifier })?
                .category.percent
            return DailySummaryTax(
                amount: subtotal.taxAmount,
                percent: percent,
                scheme: subtotal.scheme
            )
        }
    }

    private static func taxes(from note: NotaCredito) -> [DailySummaryTax] {
        note.taxTotal.subtotals.map { subtotal in
            let percent = note.lines
                .lazy
                .flatMap(\.taxTotal.subtotals)
                .first(where: { $0.category.scheme.identifier == subtotal.scheme.identifier })?
                .category.percent
            return DailySummaryTax(amount: subtotal.taxAmount, percent: percent, scheme: subtotal.scheme)
        }
    }
}

private extension DailySummarySaleType {
    static let sunatOrder: [Self] = [
        .taxable, .exempt, .unaffected, .export,
        .freeTaxable, .freeExempt, .freeUnaffected, .freeExport
    ]
}

/// Resumen Diario representado por la raíz SUNAT `SummaryDocuments` (UBL 2.0).
public struct ResumenDiarioBoletas: Codable, Equatable, Sendable {
    public let identifier: DailySummaryIdentifier
    public let issueDate: IssueDate
    public let referenceDate: IssueDate
    public let supplier: Supplier
    public let lines: [DailySummaryLine]
    public let signature: SignatureInformation?
    public let ublVersion: String
    public let customizationID: String

    public init(
        identifier: DailySummaryIdentifier,
        issueDate: IssueDate,
        referenceDate: IssueDate,
        supplier: Supplier,
        lines: [DailySummaryLine],
        signature: SignatureInformation? = nil,
        ublVersion: String = "2.0",
        customizationID: String = "1.1"
    ) throws {
        self.identifier = identifier
        self.issueDate = issueDate
        self.referenceDate = referenceDate
        self.supplier = supplier
        self.lines = lines
        self.signature = signature
        self.ublVersion = ublVersion
        self.customizationID = customizationID
        try DailySummaryValidator().validate(self)
    }

    /// API de conveniencia para el caso normal: informar boletas nuevas.
    public init(
        identifier: DailySummaryIdentifier,
        issueDate: IssueDate,
        boletas: [Boleta],
        signature: SignatureInformation? = nil
    ) throws {
        guard let first = boletas.first else { throw DailySummaryValidationError.emptyLines }
        try DailySummaryValidator().validateSourceBoletas(boletas)
        try self.init(
            identifier: identifier,
            issueDate: issueDate,
            referenceDate: first.issueDate,
            supplier: first.supplier,
            lines: boletas.enumerated().map {
                DailySummaryLine(lineID: $0.offset + 1, boleta: $0.element)
            },
            signature: signature
        )
    }
}
