import Foundation

/// Modelo de dominio de una factura electrónica UBL 2.1.
///
/// La serialización, firma, empaquetado y comunicación con SUNAT permanecen
/// fuera del modelo.
public struct Factura: Equatable, Sendable, UBLInvoiceDocument {
    public let identifier: DocumentIdentifier
    public let issueDate: IssueDate
    public let issueTime: IssueTime?
    public let currency: CurrencyCode
    public let supplier: Supplier
    public let customer: Customer
    public let taxTotal: TaxTotal
    public let monetaryTotal: MonetaryTotal
    public let lines: [InvoiceLine]
    public let additionalNotes: [DocumentNote]
    public let orderReference: String?
    public let despatchDocumentReferences: [DocumentReference]
    public let buyerAddress: Address?
    public let paymentCondition: PaymentCondition
    public let allowanceCharges: [AllowanceCharge]

    public var documentType: ElectronicDocumentType { .factura }

    public init(
        identifier: DocumentIdentifier,
        issueDate: IssueDate,
        issueTime: IssueTime? = nil,
        currency: CurrencyCode,
        supplier: Supplier,
        customer: Customer,
        lines: [InvoiceLine],
        additionalNotes: [DocumentNote] = [],
        orderReference: String? = nil,
        despatchDocumentReferences: [DocumentReference] = [],
        buyerAddress: Address? = nil,
        paymentCondition: PaymentCondition,
        allowanceCharges: [AllowanceCharge] = [],
        payableRoundingAmount: Decimal? = nil
    ) {
        self.identifier = identifier
        self.issueDate = issueDate
        self.issueTime = issueTime
        self.currency = currency
        self.supplier = supplier
        self.customer = customer
        self.lines = lines
        self.additionalNotes = additionalNotes
        self.orderReference = orderReference
        self.despatchDocumentReferences = despatchDocumentReferences
        self.buyerAddress = buyerAddress
        self.paymentCondition = paymentCondition
        self.allowanceCharges = allowanceCharges
        self.taxTotal = CPECalculation.taxTotal(from: lines, taxTotal: \.taxTotal)
        self.monetaryTotal = CPECalculation.monetaryTotal(
            lineAmounts: lines.map(\.lineExtensionAmount),
            taxTotal: self.taxTotal,
            allowanceCharges: allowanceCharges,
            payableRoundingAmount: payableRoundingAmount.map(MonetaryAmount.init(value:))
        )
    }

    public var netAmount: Decimal { monetaryTotal.lineExtensionAmount.value }
    public var taxAmount: Decimal { taxTotal.amount.value }
    public var totalAmount: Decimal { monetaryTotal.payableAmount.value }
}
