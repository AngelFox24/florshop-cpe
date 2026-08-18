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

/// Tipos de comprobante que pueden informarse en un Resumen Diario.
/// La restricción en el tipo evita construir líneas de facturas (`01`).
public enum DailySummaryDocumentType: String, Codable, Sendable {
    case boleta = "03"
    case notaDeCredito = "07"
    case notaDeDebito = "08"
}

/// Clasificación de importes de venta del catálogo 11 de SUNAT.
public enum DailySummarySaleType: String, Codable, Sendable {
    case taxable = "01"
    case exempt = "02"
    case unaffected = "03"
    case freeTaxable = "06"
    case freeExempt = "07"
    case freeUnaffected = "08"
}

/// Documento de entrada que la librería convertirá en una línea del Resumen
/// Diario. El identificador correlativo de línea se deriva de su posición en
/// el arreglo `entries` y no forma parte de la API de entrada.
public enum DailySummaryEntry: Equatable, Sendable {
    case boleta(Boleta, condition: DailySummaryCondition = .add)
    case creditNote(NotaCredito, condition: DailySummaryCondition = .add)
    case debitNote(NotaDebito, condition: DailySummaryCondition = .add)

    var issueDate: IssueDate {
        switch self {
        case let .boleta(document, _): document.issueDate
        case let .creditNote(document, _): document.issueDate
        case let .debitNote(document, _): document.issueDate
        }
    }

    var supplier: Supplier {
        switch self {
        case let .boleta(document, _): document.supplier
        case let .creditNote(document, _): document.supplier
        case let .debitNote(document, _): document.supplier
        }
    }

    func validateSource() throws {
        switch self {
        case let .boleta(document, _):
            try UBLInvoiceDocumentValidator().validate(document)
        case let .creditNote(document, _):
            try CreditNoteValidator().validate(document)
        case let .debitNote(document, _):
            try DebitNoteValidator().validate(document)
        }
    }

    fileprivate func makeLine(lineID: Int) throws -> DailySummaryLine {
        switch self {
        case let .boleta(boleta, condition):
            try DailySummaryLine(lineID: lineID, boleta: boleta, condition: condition)
        case let .creditNote(note, condition):
            try DailySummaryLine(lineID: lineID, creditNote: note, condition: condition)
        case let .debitNote(note, condition):
            try DailySummaryLine(lineID: lineID, debitNote: note, condition: condition)
        }
    }
}

/// Tributo agregado de una línea del Resumen Diario.
///
/// La tasa se conserva porque SUNAT la exige también para operaciones gratuitas.
public struct DailySummaryTax: Equatable, Sendable {
    public let amount: MonetaryAmount
    public let percent: Decimal?
    public let scheme: TaxScheme

    init(amount: MonetaryAmount, percent: Decimal? = nil, scheme: TaxScheme) {
        self.amount = amount
        self.percent = percent
        self.scheme = scheme
    }
}

public struct DailySummarySale: Equatable, Sendable {
    public let type: DailySummarySaleType
    public let amount: MonetaryAmount

    init(type: DailySummarySaleType, amount: MonetaryAmount) {
        self.type = type
        self.amount = amount
    }
}

/// Una línea agregada del Resumen Diario. No contiene el detalle de productos.
public struct DailySummaryLine: Equatable, Sendable {
    public let lineID: Int
    public let documentType: DailySummaryDocumentType
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

    init(
        lineID: Int,
        documentType: DailySummaryDocumentType,
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
    init(
        lineID: Int,
        boleta: Boleta,
        condition: DailySummaryCondition = .add
    ) throws {
        guard boleta.currency == .pen else {
            throw DailySummaryValidationError.sourceDocumentMustUsePEN
        }
        self.init(
            lineID: lineID,
            documentType: .boleta,
            documentIdentifier: boleta.identifier,
            customerIdentifier: boleta.customer.identifier,
            customerLegalName: boleta.customer.legalName,
            affectedDocument: nil,
            condition: condition,
            totalAmount: boleta.monetaryTotal.taxInclusiveAmount.normalized,
            sales: Self.sales(from: boleta),
            chargeTotalAmount: boleta.monetaryTotal.chargeTotalAmount?.normalized,
            taxes: Self.taxes(from: boleta)
        )
    }

    /// Deriva la línea `07` exigida por el Resumen Diario para una Nota de
    /// Crédito asociada a una boleta. Las notas de facturas se envían de forma
    /// individual mediante `sendBill` y no pueden convertirse con esta API.
    init(
        lineID: Int,
        creditNote: NotaCredito,
        condition: DailySummaryCondition = .add
    ) throws {
        guard creditNote.affectedDocument.type == .boleta else {
            throw DailySummaryValidationError.invalidAffectedDocument(lineID)
        }
        guard creditNote.currency == .pen else {
            throw DailySummaryValidationError.sourceDocumentMustUsePEN
        }
        try CreditNoteValidator().validate(creditNote)
        self.init(
            lineID: lineID,
            documentType: .notaDeCredito,
            documentIdentifier: creditNote.identifier,
            customerIdentifier: creditNote.customer.identifier,
            customerLegalName: creditNote.customer.legalName,
            affectedDocument: creditNote.affectedDocument.identifier,
            condition: condition,
            totalAmount: creditNote.monetaryTotal.payableAmount.normalized,
            sales: Self.sales(from: creditNote),
            chargeTotalAmount: creditNote.monetaryTotal.chargeTotalAmount?.normalized,
            taxes: Self.taxes(from: creditNote)
        )
    }

    /// Deriva la línea `08` exigida por el Resumen Diario para una Nota de
    /// Débito asociada a una boleta. Las notas de facturas se envían de forma
    /// individual mediante `sendBill` y no pueden convertirse con esta API.
    init(
        lineID: Int,
        debitNote: NotaDebito,
        condition: DailySummaryCondition = .add
    ) throws {
        guard debitNote.affectedDocument.type == .boleta else {
            throw DailySummaryValidationError.invalidAffectedDocument(lineID)
        }
        guard debitNote.currency == .pen else {
            throw DailySummaryValidationError.sourceDocumentMustUsePEN
        }
        try DebitNoteValidator().validate(debitNote)
        self.init(
            lineID: lineID,
            documentType: .notaDeDebito,
            documentIdentifier: debitNote.identifier,
            customerIdentifier: debitNote.customer.identifier,
            customerLegalName: debitNote.customer.legalName,
            affectedDocument: debitNote.affectedDocument.identifier,
            condition: condition,
            totalAmount: debitNote.monetaryTotal.payableAmount.normalized,
            sales: Self.sales(from: debitNote),
            chargeTotalAmount: debitNote.monetaryTotal.chargeTotalAmount?.normalized,
            taxes: Self.taxes(from: debitNote)
        )
    }

    private static func sales(from boleta: Boleta) -> [DailySummarySale] {
        var totals: [DailySummarySaleType: Decimal] = [:]
        for line in boleta.lines {
            for subtotal in line.taxTotal.subtotals {
                let type = saleType(for: subtotal.category)
                totals[type, default: 0] += CPEPrecision.monetary(subtotal.taxableAmount.value)
            }
        }
        return DailySummarySaleType.sunatOrder.compactMap { type in
            let isMandatory = [.taxable, .exempt, .unaffected].contains(type)
            guard isMandatory || totals[type] != nil else { return nil }
            return DailySummarySale(
                type: type,
                amount: MonetaryAmount(value: CPEPrecision.monetary(totals[type, default: 0]))
            )
        }
    }

    private static func sales(from note: NotaCredito) -> [DailySummarySale] {
        var totals: [DailySummarySaleType: Decimal] = [:]
        for line in note.lines {
            for subtotal in line.taxTotal.subtotals {
                let type = saleType(for: subtotal.category)
                totals[type, default: 0] += CPEPrecision.monetary(subtotal.taxableAmount.value)
            }
        }
        return DailySummarySaleType.sunatOrder.compactMap { type in
            let isMandatory = [.taxable, .exempt, .unaffected].contains(type)
            guard isMandatory || totals[type] != nil else { return nil }
            return DailySummarySale(
                type: type,
                amount: MonetaryAmount(value: CPEPrecision.monetary(totals[type, default: 0]))
            )
        }
    }

    private static func sales(from note: NotaDebito) -> [DailySummarySale] {
        var totals: [DailySummarySaleType: Decimal] = [:]
        for line in note.lines {
            for subtotal in line.taxTotal.subtotals {
                let type = saleType(for: subtotal.category)
                totals[type, default: 0] += CPEPrecision.monetary(subtotal.taxableAmount.value)
            }
        }
        return DailySummarySaleType.sunatOrder.compactMap { type in
            let isMandatory = [.taxable, .exempt, .unaffected].contains(type)
            guard isMandatory || totals[type] != nil else { return nil }
            return DailySummarySale(
                type: type,
                amount: MonetaryAmount(value: CPEPrecision.monetary(totals[type, default: 0]))
            )
        }
    }

    private static func saleType(for category: TaxCategory) -> DailySummarySaleType {
        let isFree = category.scheme.identifier == TaxScheme.gratuito.identifier
        switch category.exemptionReasonCode {
        case .gravadoOperacionOnerosa: return isFree ? .freeTaxable : .taxable
        case .exonerado: return isFree ? .freeExempt : .exempt
        case .inafecto, .inafectoRetiroPorBonificacion: return isFree ? .freeUnaffected : .unaffected
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
                amount: subtotal.taxAmount.normalized,
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
            return DailySummaryTax(amount: subtotal.taxAmount.normalized, percent: percent, scheme: subtotal.scheme)
        }
    }

    private static func taxes(from note: NotaDebito) -> [DailySummaryTax] {
        note.taxTotal.subtotals.map { subtotal in
            let percent = note.lines
                .lazy
                .flatMap(\.taxTotal.subtotals)
                .first(where: { $0.category.scheme.identifier == subtotal.scheme.identifier })?
                .category.percent
            return DailySummaryTax(amount: subtotal.taxAmount.normalized, percent: percent, scheme: subtotal.scheme)
        }
    }
}

private extension DailySummarySaleType {
    static let sunatOrder: [Self] = [
        .taxable, .exempt, .unaffected,
        .freeTaxable, .freeExempt, .freeUnaffected
    ]
}

/// Resumen Diario representado por la raíz SUNAT `SummaryDocuments` (UBL 2.0).
public struct ResumenDiarioBoletas: Equatable, Sendable {
    public let identifier: DailySummaryIdentifier
    public let issueDate: IssueDate
    public let referenceDate: IssueDate
    public let supplier: Supplier
    public let lines: [DailySummaryLine]

    init(
        identifier: DailySummaryIdentifier,
        issueDate: IssueDate,
        referenceDate: IssueDate,
        supplier: Supplier,
        lines: [DailySummaryLine]
    ) throws {
        self.identifier = identifier
        self.issueDate = issueDate
        self.referenceDate = referenceDate
        self.supplier = supplier
        self.lines = lines
        try DailySummaryValidator().validate(self)
    }

    /// Crea un resumen para documentos emitidos en un mismo día. La librería
    /// deriva la fecha de referencia, la fecha del identificador `RC` y el
    /// emisor desde `entries`. `issueDate` es la fecha de generación y puede
    /// ser posterior a la fecha de los documentos informados.
    public init(
        sequence: Int,
        issueDate: IssueDate,
        entries: [DailySummaryEntry]
    ) throws {
        guard let first = entries.first else { throw DailySummaryValidationError.emptyLines }
        for entry in entries {
            try entry.validateSource()
            guard entry.supplier.taxIdentifier == first.supplier.taxIdentifier else {
                throw DailySummaryValidationError.inconsistentSupplier
            }
            guard entry.issueDate == first.issueDate else {
                throw DailySummaryValidationError.inconsistentReferenceDate
            }
        }
        try self.init(
            identifier: DailySummaryIdentifier(date: first.issueDate, sequence: sequence),
            issueDate: issueDate,
            referenceDate: first.issueDate,
            supplier: first.supplier,
            lines: try entries.enumerated().map { offset, entry in
                try entry.makeLine(lineID: offset + 1)
            }
        )
    }

    /// API de conveniencia para el caso normal: informar únicamente boletas nuevas.
    public init(
        sequence: Int,
        issueDate: IssueDate,
        boletas: [Boleta]
    ) throws {
        try self.init(
            sequence: sequence,
            issueDate: issueDate,
            entries: boletas.map { .boleta($0) }
        )
    }
}
