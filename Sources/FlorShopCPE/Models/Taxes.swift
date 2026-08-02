import Foundation

public struct TaxTotal: Codable, Equatable, Sendable {
    public let amount: MonetaryAmount
    public let subtotals: [TaxSubtotal]

    public init(amount: MonetaryAmount, subtotals: [TaxSubtotal]) {
        self.amount = amount
        self.subtotals = subtotals
    }
}

public struct TaxSubtotal: Codable, Equatable, Sendable {
    public let taxableAmount: MonetaryAmount
    public let taxAmount: MonetaryAmount
    public let scheme: TaxScheme

    public init(taxableAmount: MonetaryAmount, taxAmount: MonetaryAmount, scheme: TaxScheme) {
        self.taxableAmount = taxableAmount
        self.taxAmount = taxAmount
        self.scheme = scheme
    }
}

/// Impuestos aplicables a una línea de comprobante.
/// Incluye la afectación y tasa que no se requieren en el resumen global.
public struct LineTaxTotal: Codable, Equatable, Sendable {
    public let amount: MonetaryAmount
    public let subtotals: [LineTaxSubtotal]

    public init(amount: MonetaryAmount, subtotals: [LineTaxSubtotal]) {
        self.amount = amount
        self.subtotals = subtotals
    }
}

public struct LineTaxSubtotal: Codable, Equatable, Sendable {
    public let taxableAmount: MonetaryAmount
    public let taxAmount: MonetaryAmount
    public let category: TaxCategory

    public init(taxableAmount: MonetaryAmount, taxAmount: MonetaryAmount, category: TaxCategory) {
        self.taxableAmount = taxableAmount
        self.taxAmount = taxAmount
        self.category = category
    }
}

public struct TaxCategory: Codable, Equatable, Sendable {
    public let percent: Decimal?
    public let exemptionReasonCode: TaxExemptionReasonCode?
    public let scheme: TaxScheme

    public init(
        percent: Decimal? = nil,
        exemptionReasonCode: TaxExemptionReasonCode? = nil,
        scheme: TaxScheme
    ) {
        self.percent = percent
        self.exemptionReasonCode = exemptionReasonCode
        self.scheme = scheme
    }
}

public enum TaxExemptionReasonCode: String, Codable, Sendable {
    case gravadoOperacionOnerosa = "10"
    case exonerado = "20"
    case inafecto = "30"
    case inafectoRetiroPorBonificacion = "31"
    case exportacion = "40"
}

public struct TaxScheme: Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let typeCode: String

    public init(identifier: String, name: String, typeCode: String) {
        self.identifier = identifier
        self.name = name
        self.typeCode = typeCode
    }

    public static let igv = TaxScheme(identifier: "1000", name: "IGV", typeCode: "VAT")
    public static let inafecto = TaxScheme(identifier: "9998", name: "INAFECTO", typeCode: "FRE")
    public static let gratuito = TaxScheme(identifier: "9996", name: "GRA", typeCode: "FRE")
}
