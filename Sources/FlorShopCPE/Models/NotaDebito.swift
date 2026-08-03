import Foundation

/// Motivos de Nota de Débito del catálogo 10 de SUNAT.
public enum DebitNoteReasonCode: String, Codable, CaseIterable, Sendable {
    case interesesPorMora = "01"
    case aumentoEnElValor = "02"
    case penalidadesUOtrosConceptos = "03"
    case ajustesDeOperacionesDeExportacion = "11"
    case ajustesAfectosAlIVAP = "12"
    case penalidades = "13"
}

/// Totales monetarios admitidos por SUNAT en una Nota de Débito UBL 2.1.
public struct DebitNoteMonetaryTotal: Codable, Equatable, Sendable {
    public let chargeTotalAmount: MonetaryAmount?
    public let payableRoundingAmount: MonetaryAmount?
    public let payableAmount: MonetaryAmount

    public init(
        chargeTotalAmount: MonetaryAmount? = nil,
        payableRoundingAmount: MonetaryAmount? = nil,
        payableAmount: MonetaryAmount
    ) {
        self.chargeTotalAmount = chargeTotalAmount
        self.payableRoundingAmount = payableRoundingAmount
        self.payableAmount = payableAmount
    }
}

/// Línea de incremento informada por una Nota de Débito UBL 2.1.
public struct DebitNoteLine: Codable, Equatable, Sendable {
    public let id: String
    public let quantity: Quantity?
    public let lineExtensionAmount: MonetaryAmount
    public let alternativePrices: [AlternativePrice]
    public let taxTotal: LineTaxTotal
    public let item: Item
    public let price: MonetaryAmount?

    public init(
        id: String,
        quantity: Quantity? = nil,
        lineExtensionAmount: MonetaryAmount,
        alternativePrices: [AlternativePrice] = [],
        taxTotal: LineTaxTotal,
        item: Item,
        price: MonetaryAmount? = nil
    ) {
        self.id = id
        self.quantity = quantity
        self.lineExtensionAmount = lineExtensionAmount
        self.alternativePrices = alternativePrices
        self.taxTotal = taxTotal
        self.item = item
        self.price = price
    }

    /// Facilita reutilizar una línea ya calculada cuando el débito incrementa
    /// el valor de un bien o servicio del comprobante afectado.
    public init(invoiceLine: InvoiceLine) {
        self.init(
            id: invoiceLine.id,
            quantity: invoiceLine.quantity,
            lineExtensionAmount: invoiceLine.lineExtensionAmount,
            alternativePrices: invoiceLine.alternativePrices,
            taxTotal: invoiceLine.taxTotal,
            item: invoiceLine.item,
            price: invoiceLine.price
        )
    }
}

/// Nota de Débito electrónica UBL 2.1 vinculada a una factura o boleta.
///
/// Las notas cuya serie empieza con `F` se envían individualmente. Las que
/// empiezan con `B` se informan mediante un Resumen Diario como documento `08`.
public struct NotaDebito: Codable, Equatable, Sendable {
    public let identifier: DocumentIdentifier
    public let issueDate: IssueDate
    public let issueTime: IssueTime?
    public let currency: CurrencyCode
    public let supplier: Supplier
    public let customer: Customer
    public let affectedDocument: AffectedDocumentIdentifier
    public let reasonCode: DebitNoteReasonCode
    public let reasonDescription: String
    public let taxTotal: TaxTotal
    public let monetaryTotal: DebitNoteMonetaryTotal
    public let lines: [DebitNoteLine]
    public let additionalNotes: [DocumentNote]

    public init(
        identifier: DocumentIdentifier,
        issueDate: IssueDate,
        issueTime: IssueTime? = nil,
        currency: CurrencyCode,
        supplier: Supplier,
        customer: Customer,
        affectedDocument: AffectedDocumentIdentifier,
        reasonCode: DebitNoteReasonCode,
        reasonDescription: String,
        taxTotal: TaxTotal,
        monetaryTotal: DebitNoteMonetaryTotal,
        lines: [DebitNoteLine],
        additionalNotes: [DocumentNote] = []
    ) {
        self.identifier = identifier
        self.issueDate = issueDate
        self.issueTime = issueTime
        self.currency = currency
        self.supplier = supplier
        self.customer = customer
        self.affectedDocument = affectedDocument
        self.reasonCode = reasonCode
        self.reasonDescription = reasonDescription
        self.taxTotal = taxTotal
        self.monetaryTotal = monetaryTotal
        self.lines = lines
        self.additionalNotes = additionalNotes
    }

    public var documentType: ElectronicDocumentType { .notaDeDebito }
}
