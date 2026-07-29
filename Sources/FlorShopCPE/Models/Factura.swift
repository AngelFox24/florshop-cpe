import Foundation

/// Modelo de dominio de una factura electrónica UBL 2.1.
///
/// La serialización, firma, empaquetado y comunicación con SUNAT permanecen
/// fuera del modelo.
public struct Factura: Codable, Equatable, Sendable, UBLInvoiceDocument {
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
    public let paymentTerms: [PaymentTerm]
    public let allowanceCharges: [AllowanceCharge]
    public let signature: SignatureInformation?
    public let ublVersion: String
    public let customizationID: String
    public let operationTypeCode: String

    public var expectedDocumentType: ElectronicDocumentType { .factura }

    public init(
        identifier: DocumentIdentifier,
        issueDate: IssueDate,
        issueTime: IssueTime? = nil,
        currency: CurrencyCode,
        supplier: Supplier,
        customer: Customer,
        taxTotal: TaxTotal,
        monetaryTotal: MonetaryTotal,
        lines: [InvoiceLine],
        additionalNotes: [DocumentNote] = [],
        orderReference: String? = nil,
        despatchDocumentReferences: [DocumentReference] = [],
        buyerAddress: Address? = nil,
        paymentTerms: [PaymentTerm] = [],
        allowanceCharges: [AllowanceCharge] = [],
        signature: SignatureInformation? = nil,
        ublVersion: String = "2.1",
        customizationID: String = "2.0",
        operationTypeCode: String = "0101"
    ) {
        self.identifier = identifier
        self.issueDate = issueDate
        self.issueTime = issueTime
        self.currency = currency
        self.supplier = supplier
        self.customer = customer
        self.taxTotal = taxTotal
        self.monetaryTotal = monetaryTotal
        self.lines = lines
        self.additionalNotes = additionalNotes
        self.orderReference = orderReference
        self.despatchDocumentReferences = despatchDocumentReferences
        self.buyerAddress = buyerAddress
        self.paymentTerms = paymentTerms
        self.allowanceCharges = allowanceCharges
        self.signature = signature
        self.ublVersion = ublVersion
        self.customizationID = customizationID
        self.operationTypeCode = operationTypeCode
    }
}
