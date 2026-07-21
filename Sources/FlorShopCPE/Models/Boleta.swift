import Foundation

/// Modelo de dominio de una boleta de venta electrónica.
///
/// No contiene lógica de serialización ni de comunicación con SUNAT. Es la
/// entrada que utilizará un transformador UBL en una capa posterior.
public struct Boleta: Codable, Equatable, Sendable {
    public let identifier: DocumentIdentifier
    public let issueDate: IssueDate
    public let issueTime: IssueTime?
    public let currency: CurrencyCode
    public let supplier: Supplier
    public let customer: Customer
    public let taxTotal: TaxTotal
    public let monetaryTotal: MonetaryTotal
    public let lines: [InvoiceLine]
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
        taxTotal: TaxTotal,
        monetaryTotal: MonetaryTotal,
        lines: [InvoiceLine],
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
        self.taxTotal = taxTotal
        self.monetaryTotal = monetaryTotal
        self.lines = lines
        self.signature = signature
        self.ublVersion = ublVersion
        self.customizationID = customizationID
    }
}

public struct DocumentIdentifier: Codable, Equatable, Sendable {
    public let series: String
    public let number: String
    public let type: ElectronicDocumentType

    public init(series: String, number: String, type: ElectronicDocumentType = .boleta) {
        self.series = series
        self.number = number
        self.type = type
    }

    public var value: String { "\(series)-\(number)" }
}

public enum ElectronicDocumentType: String, Codable, Sendable {
    case factura = "01"
    case boleta = "03"
    case notaDeCredito = "07"
    case notaDeDebito = "08"
}

public struct IssueDate: Codable, Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

public struct IssueTime: Codable, Equatable, Sendable {
    public let hour: Int
    public let minute: Int
    public let second: Int

    public init(hour: Int, minute: Int, second: Int = 0) {
        self.hour = hour
        self.minute = minute
        self.second = second
    }
}

public enum CurrencyCode: String, Codable, Sendable {
    case pen = "PEN"
    case usd = "USD"
    case eur = "EUR"
}
