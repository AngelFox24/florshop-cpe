import Foundation

/// Motivos de Nota de Débito del catálogo 10 de SUNAT.
public enum DebitNoteReasonCode: String, Codable, CaseIterable, Sendable {
    case interesesPorMora = "01"
    case aumentoEnElValor = "02"
    case penalidadesUOtrosConceptos = "03"
    case ajustesDeOperacionesDeExportacion = "11"
    case ajustesAfectosAlIVAP = "12"
    case penalidades = "13"

    public var defaultDescription: String {
        switch self {
        case .interesesPorMora: "INTERESES POR MORA"
        case .aumentoEnElValor: "AUMENTO EN EL VALOR"
        case .penalidadesUOtrosConceptos: "PENALIDADES U OTROS CONCEPTOS"
        case .ajustesDeOperacionesDeExportacion: "AJUSTES DE OPERACIONES DE EXPORTACIÓN"
        case .ajustesAfectosAlIVAP: "AJUSTES AFECTOS AL IVAP"
        case .penalidades: "PENALIDADES"
        }
    }
}

/// Totales monetarios admitidos por SUNAT en una Nota de Débito UBL 2.1.
public struct DebitNoteMonetaryTotal: Equatable, Sendable {
    public let chargeTotalAmount: MonetaryAmount?
    public let payableRoundingAmount: MonetaryAmount?
    public let payableAmount: MonetaryAmount

    init(
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
public struct DebitNoteLine: Equatable, Sendable {
    public let id: String
    public let quantity: Quantity?
    public let pricing: LinePricing
    public let taxTreatment: TaxTreatment
    public let taxCategory: TaxCategory
    public let lineExtensionAmount: MonetaryAmount
    public let alternativePrices: [AlternativePrice]
    public let taxTotal: LineTaxTotal
    public let item: Item
    public let price: MonetaryAmount?

    public init(
        id: String,
        quantity: Quantity,
        pricing: LinePricing,
        item: Item
    ) {
        let calculated = CPECalculation.line(
            quantity: quantity.value,
            pricing: pricing
        )
        let taxTreatment = pricing.taxTreatment
        let taxCategory = taxTreatment.category
        self.id = id
        self.quantity = quantity
        self.pricing = pricing
        self.taxTreatment = taxTreatment
        self.taxCategory = taxCategory
        self.lineExtensionAmount = calculated.lineExtensionAmount
        self.alternativePrices = calculated.alternativePrices
        self.taxTotal = calculated.taxTotal
        self.item = item
        self.price = calculated.price
    }

    /// Incremento cuyo importe es el dato comercial primario (por ejemplo,
    /// una penalidad) y por ello no tiene cantidad ni precio unitario UBL.
    public init(
        id: String,
        pricing: LinePricing,
        item: Item
    ) {
        let calculated = CPECalculation.line(
            quantity: 1,
            pricing: pricing
        )
        let taxTreatment = pricing.taxTreatment
        let taxCategory = taxTreatment.category
        self.id = id
        self.quantity = nil
        self.pricing = pricing
        self.taxTreatment = taxTreatment
        self.taxCategory = taxCategory
        self.lineExtensionAmount = calculated.lineExtensionAmount
        self.alternativePrices = []
        self.taxTotal = calculated.taxTotal
        self.item = item
        self.price = nil
    }

    /// Facilita reutilizar una línea ya calculada cuando el débito incrementa
    /// el valor de un bien o servicio del comprobante afectado.
    public init(invoiceLine: InvoiceLine) {
        self.init(
            id: invoiceLine.id,
            quantity: invoiceLine.quantity,
            pricing: invoiceLine.pricing,
            item: invoiceLine.item
        )
    }
}

/// Nota de Débito electrónica UBL 2.1 vinculada a una factura o boleta.
///
/// Las notas cuya serie empieza con `F` se envían individualmente. Las que
/// empiezan con `B` se informan mediante un Resumen Diario como documento `08`.
public struct NotaDebito: Equatable, Sendable {
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
        reasonDescription: String? = nil,
        lines: [DebitNoteLine],
        payableRoundingAmount: Decimal? = nil,
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
        self.reasonDescription = reasonDescription ?? reasonCode.defaultDescription
        self.lines = lines
        self.taxTotal = CPECalculation.taxTotal(from: lines, taxTotal: \.taxTotal)
        let calculatedTotal = CPECalculation.monetaryTotal(
            lineAmounts: lines.map(\.lineExtensionAmount),
            taxTotal: self.taxTotal,
            payableRoundingAmount: payableRoundingAmount.map(MonetaryAmount.init(value:))
        )
        self.monetaryTotal = DebitNoteMonetaryTotal(
            payableRoundingAmount: calculatedTotal.payableRoundingAmount,
            payableAmount: calculatedTotal.payableAmount
        )
        self.additionalNotes = additionalNotes
    }

    public var documentType: ElectronicDocumentType { .notaDeDebito }
    public var netAmount: Decimal { CPEPrecision.monetarySum(lines.map(\.lineExtensionAmount.value)) }
    public var taxAmount: Decimal { taxTotal.amount.value }
    public var totalAmount: Decimal { monetaryTotal.payableAmount.value }
}
