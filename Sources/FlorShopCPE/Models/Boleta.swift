import Foundation

/// Modelo de dominio de una boleta de venta electrónica.
///
/// No contiene lógica de serialización ni de comunicación con SUNAT. Es la
/// entrada que utilizará un transformador UBL en una capa posterior.
public struct Boleta: Equatable, Sendable, UBLInvoiceDocument {
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

    public var documentType: ElectronicDocumentType { .boleta }

    public init(
        identifier: DocumentIdentifier,
        issueDate: IssueDate,
        issueTime: IssueTime? = nil,
        currency: CurrencyCode,
        supplier: Supplier,
        customer: Customer,
        lines: [InvoiceLine],
        payableRoundingAmount: Decimal? = nil,
        additionalNotes: [DocumentNote] = []
    ) {
        self.identifier = identifier
        self.issueDate = issueDate
        self.issueTime = issueTime
        self.currency = currency
        self.supplier = supplier
        self.customer = customer
        let identifiedLines = lines.enumerated().map { offset, line in
            line.assigningID(String(offset + 1))
        }
        self.lines = identifiedLines
        self.taxTotal = CPECalculation.taxTotal(from: identifiedLines, taxTotal: \.taxTotal)
        self.monetaryTotal = CPECalculation.monetaryTotal(
            lineAmounts: identifiedLines
                .filter { $0.taxTreatment != .free }
                .map(\.lineExtensionAmount),
            taxTotal: self.taxTotal,
            payableRoundingAmount: payableRoundingAmount.map(MonetaryAmount.init(value:))
        )
        self.additionalNotes = additionalNotes
    }

    public var netAmount: Decimal { monetaryTotal.lineExtensionAmount.value }
    public var taxAmount: Decimal { taxTotal.amount.value }
    public var totalAmount: Decimal { monetaryTotal.payableAmount.value }
}

public struct DocumentIdentifier: Codable, Equatable, Sendable {
    public let series: String
    public let number: String

    public init(series: String, number: String) {
        self.series = series
        self.number = number
    }

    public var value: String { "\(series)-\(number)" }
}

public enum ElectronicDocumentType: String, Codable, Sendable {
    case factura = "01"
    case boleta = "03"
    case notaDeCredito = "07"
    case notaDeDebito = "08"
}

/// Tipo del comprobante de venta que una Nota de Crédito o Débito modifica.
///
/// Está separado de `ElectronicDocumentType` para que una nota no pueda
/// declarar como documento afectado otra nota.
public enum AffectedInvoiceDocumentType: String, Codable, Sendable {
    case factura = "01"
    case boleta = "03"
}

/// Referencia tipada al comprobante afectado por una Nota de Crédito o Débito.
/// El documento raíz usa `DocumentIdentifier`, cuyo tipo lo infiere su modelo.
public struct AffectedDocumentIdentifier: Codable, Equatable, Sendable {
    public let identifier: DocumentIdentifier
    public let type: AffectedInvoiceDocumentType

    public init(
        series: String,
        number: String,
        type: AffectedInvoiceDocumentType
    ) {
        self.identifier = DocumentIdentifier(series: series, number: number)
        self.type = type
    }

    public init(factura: Factura) {
        self.identifier = factura.identifier
        self.type = .factura
    }

    public init(boleta: Boleta) {
        self.identifier = boleta.identifier
        self.type = .boleta
    }

    public var series: String { identifier.series }
    public var number: String { identifier.number }
    public var value: String { identifier.value }
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
