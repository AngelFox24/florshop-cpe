import Foundation

/// Motivos de Nota de Crédito del catálogo 09 de SUNAT.
public enum CreditNoteReasonCode: String, Codable, CaseIterable, Sendable {
    case anulacionDeOperacion = "01"
    case anulacionPorErrorEnRUC = "02"
    case correccionPorErrorEnDescripcion = "03"
    case descuentoGlobal = "04"
    case descuentoPorItem = "05"
    case devolucionTotal = "06"
    case devolucionPorItem = "07"
    case bonificacion = "08"
    case disminucionEnElValor = "09"
    case otrosConceptos = "10"
    case ajustesDeOperacionesDeExportacion = "11"
    case ajustesAfectosAlIVAP = "12"
    case correccionMontoNetoPendienteOFechasDePago = "13"
}

/// Totales monetarios permitidos por SUNAT dentro de una Nota de Crédito.
public struct CreditNoteMonetaryTotal: Codable, Equatable, Sendable {
    public let allowanceTotalAmount: MonetaryAmount?
    public let chargeTotalAmount: MonetaryAmount?
    public let prepaidAmount: MonetaryAmount?
    public let payableAmount: MonetaryAmount

    public init(
        allowanceTotalAmount: MonetaryAmount? = nil,
        chargeTotalAmount: MonetaryAmount? = nil,
        prepaidAmount: MonetaryAmount? = nil,
        payableAmount: MonetaryAmount
    ) {
        self.allowanceTotalAmount = allowanceTotalAmount
        self.chargeTotalAmount = chargeTotalAmount
        self.prepaidAmount = prepaidAmount
        self.payableAmount = payableAmount
    }
}

/// Línea afectada por una Nota de Crédito UBL 2.1.
public struct CreditNoteLine: Codable, Equatable, Sendable {
    public let id: String
    public let quantity: Quantity
    public let lineExtensionAmount: MonetaryAmount
    public let alternativePrices: [AlternativePrice]
    public let taxTotal: LineTaxTotal
    public let item: Item
    public let price: MonetaryAmount

    public init(
        id: String,
        quantity: Quantity,
        lineExtensionAmount: MonetaryAmount,
        alternativePrices: [AlternativePrice],
        taxTotal: LineTaxTotal,
        item: Item,
        price: MonetaryAmount
    ) {
        self.id = id
        self.quantity = quantity
        self.lineExtensionAmount = lineExtensionAmount
        self.alternativePrices = alternativePrices
        self.taxTotal = taxTotal
        self.item = item
        self.price = price
    }

    /// Facilita reutilizar el detalle calculado del comprobante afectado.
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

/// Nota de Crédito electrónica UBL 2.1 vinculada a una factura o boleta.
///
/// El modelo no realiza persistencia, reintentos ni comunicación de red. Esos
/// aspectos corresponden al sistema consumidor de la librería.
public struct NotaCredito: Codable, Equatable, Sendable {
    public let identifier: DocumentIdentifier
    public let issueDate: IssueDate
    public let issueTime: IssueTime?
    public let currency: CurrencyCode
    public let supplier: Supplier
    public let customer: Customer
    public let affectedDocument: DocumentIdentifier
    public let reasonCode: CreditNoteReasonCode
    public let reasonDescription: String
    public let taxTotal: TaxTotal
    public let monetaryTotal: CreditNoteMonetaryTotal
    public let lines: [CreditNoteLine]
    public let additionalNotes: [DocumentNote]
    public let signature: SignatureInformation?
    public let ublVersion: String
    public let customizationID: String

    public init(
        identifier: DocumentIdentifier,
        issueDate: IssueDate,
        issueTime: IssueTime? = nil,
        currency: CurrencyCode,
        supplier: Supplier,
        customer: Customer,
        affectedDocument: DocumentIdentifier,
        reasonCode: CreditNoteReasonCode,
        reasonDescription: String,
        taxTotal: TaxTotal,
        monetaryTotal: CreditNoteMonetaryTotal,
        lines: [CreditNoteLine],
        additionalNotes: [DocumentNote] = [],
        signature: SignatureInformation? = nil,
        ublVersion: String = "2.1",
        customizationID: String = "2.0"
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
        self.signature = signature
        self.ublVersion = ublVersion
        self.customizationID = customizationID
    }
}
