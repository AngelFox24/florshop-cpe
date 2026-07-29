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
    var signature: SignatureInformation? { get }
    var ublVersion: String { get }
    var customizationID: String { get }
    var operationTypeCode: String { get }

    /// Tipo que corresponde al modelo concreto, independientemente del valor
    /// recibido en `identifier`.
    var expectedDocumentType: ElectronicDocumentType { get }
}

public struct DocumentNote: Codable, Equatable, Sendable {
    public let value: String
    public let languageLocaleID: String

    public init(value: String, languageLocaleID: String) {
        self.value = value
        self.languageLocaleID = languageLocaleID
    }
}
