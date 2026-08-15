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

    public var defaultDescription: String {
        switch self {
        case .anulacionDeOperacion: "ANULACIÓN DE LA OPERACIÓN"
        case .anulacionPorErrorEnRUC: "ANULACIÓN POR ERROR EN EL RUC"
        case .correccionPorErrorEnDescripcion: "CORRECCIÓN POR ERROR EN LA DESCRIPCIÓN"
        case .descuentoGlobal: "DESCUENTO GLOBAL"
        case .descuentoPorItem: "DESCUENTO POR ÍTEM"
        case .devolucionTotal: "DEVOLUCIÓN TOTAL"
        case .devolucionPorItem: "DEVOLUCIÓN POR ÍTEM"
        case .bonificacion: "BONIFICACIÓN"
        case .disminucionEnElValor: "DISMINUCIÓN EN EL VALOR"
        case .otrosConceptos: "OTROS CONCEPTOS"
        case .ajustesDeOperacionesDeExportacion: "AJUSTES DE OPERACIONES DE EXPORTACIÓN"
        case .ajustesAfectosAlIVAP: "AJUSTES AFECTOS AL IVAP"
        case .correccionMontoNetoPendienteOFechasDePago:
            "CORRECCIÓN DEL MONTO NETO PENDIENTE DE PAGO Y/O FECHAS DE PAGO"
        }
    }
}

/// Totales monetarios permitidos por SUNAT dentro de una Nota de Crédito.
public struct CreditNoteMonetaryTotal: Equatable, Sendable {
    public let allowanceTotalAmount: MonetaryAmount?
    public let chargeTotalAmount: MonetaryAmount?
    public let prepaidAmount: MonetaryAmount?
    public let payableRoundingAmount: MonetaryAmount?
    public let payableAmount: MonetaryAmount

    init(
        allowanceTotalAmount: MonetaryAmount? = nil,
        chargeTotalAmount: MonetaryAmount? = nil,
        prepaidAmount: MonetaryAmount? = nil,
        payableRoundingAmount: MonetaryAmount? = nil,
        payableAmount: MonetaryAmount
    ) {
        self.allowanceTotalAmount = allowanceTotalAmount
        self.chargeTotalAmount = chargeTotalAmount
        self.prepaidAmount = prepaidAmount
        self.payableRoundingAmount = payableRoundingAmount
        self.payableAmount = payableAmount
    }
}

/// Línea afectada por una Nota de Crédito UBL 2.1.
public struct CreditNoteLine: Equatable, Sendable {
    public let id: String
    public let quantity: Quantity
    public let pricing: LinePricing
    public let taxTreatment: TaxTreatment
    public let taxCategory: TaxCategory
    public let lineExtensionAmount: MonetaryAmount
    public let alternativePrices: [AlternativePrice]
    public let taxTotal: LineTaxTotal
    public let item: Item
    public let price: MonetaryAmount

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

    /// Facilita reutilizar el detalle calculado del comprobante afectado.
    public init(invoiceLine: InvoiceLine) {
        self.init(
            id: invoiceLine.id,
            quantity: invoiceLine.quantity,
            pricing: invoiceLine.pricing,
            item: invoiceLine.item
        )
    }
}

/// Nota de Crédito electrónica UBL 2.1 vinculada a una factura o boleta.
///
/// El modelo no realiza persistencia, reintentos ni comunicación de red. Esos
/// aspectos corresponden al sistema consumidor de la librería.
public struct NotaCredito: Equatable, Sendable {
    public let identifier: DocumentIdentifier
    public let issueDate: IssueDate
    public let issueTime: IssueTime?
    public let currency: CurrencyCode
    public let supplier: Supplier
    public let customer: Customer
    public let affectedDocument: AffectedDocumentIdentifier
    public let reasonCode: CreditNoteReasonCode
    public let reasonDescription: String
    public let taxTotal: TaxTotal
    public let monetaryTotal: CreditNoteMonetaryTotal
    public let lines: [CreditNoteLine]
    public let additionalNotes: [DocumentNote]

    public init(
        identifier: DocumentIdentifier,
        issueDate: IssueDate,
        issueTime: IssueTime? = nil,
        currency: CurrencyCode,
        supplier: Supplier,
        customer: Customer,
        affectedDocument: AffectedDocumentIdentifier,
        reasonCode: CreditNoteReasonCode,
        reasonDescription: String? = nil,
        lines: [CreditNoteLine],
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
            lineAmounts: lines
                .filter { $0.taxTreatment != .free }
                .map(\.lineExtensionAmount),
            taxTotal: self.taxTotal,
            payableRoundingAmount: payableRoundingAmount.map(MonetaryAmount.init(value:))
        )
        self.monetaryTotal = CreditNoteMonetaryTotal(
            payableRoundingAmount: calculatedTotal.payableRoundingAmount,
            payableAmount: calculatedTotal.payableAmount
        )
        self.additionalNotes = additionalNotes
    }

    public var documentType: ElectronicDocumentType { .notaDeCredito }
    public var netAmount: Decimal {
        CPEPrecision.monetarySum(
            lines.lazy
                .filter { $0.taxTreatment != .free }
                .map(\.lineExtensionAmount.value)
        )
    }
    public var taxAmount: Decimal { taxTotal.amount.value }
    public var totalAmount: Decimal { monetaryTotal.payableAmount.value }
}
