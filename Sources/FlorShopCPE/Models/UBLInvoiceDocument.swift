/// Datos comunes de los comprobantes que SUNAT representa mediante la raíz
/// UBL `Invoice`, actualmente factura y boleta de venta.
public protocol UBLInvoiceDocument: Sendable {
    var identifier: DocumentIdentifier { get }
    var issueDate: IssueDate { get }
    var issueTime: IssueTime? { get }
    var currency: CurrencyCode { get }
    var supplier: Supplier { get }
    var customer: Customer { get }
    var taxTotal: TaxTotal { get }
    var monetaryTotal: MonetaryTotal { get }
    var lines: [InvoiceLine] { get }
    var additionalNotes: [DocumentNote] { get }

    /// Tipo determinado por el modelo concreto. No forma parte del
    /// identificador para impedir combinaciones como `Boleta` + `factura`.
    var documentType: ElectronicDocumentType { get }
}

public struct DocumentNote: Codable, Equatable, Sendable {
    public let value: String
    public let languageLocaleID: String

    public init(value: String, languageLocaleID: String) {
        self.value = value
        self.languageLocaleID = languageLocaleID
    }
}
