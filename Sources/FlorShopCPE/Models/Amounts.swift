import Foundation

public struct MonetaryAmount: Codable, Equatable, Sendable {
    public let value: Decimal
    public let currency: CurrencyCode

    public init(value: Decimal, currency: CurrencyCode) {
        self.value = value
        self.currency = currency
    }
}

public struct Quantity: Codable, Equatable, Sendable {
    public let value: Decimal
    public let unitCode: UnitCode

    public init(value: Decimal, unitCode: UnitCode) {
        self.value = value
        self.unitCode = unitCode
    }
}

public enum UnitCode: String, Codable, Sendable {
    case unit = "NIU"
    case kilogram = "KGM"
    case gram = "GRM"
    case liter = "LTR"
    case meter = "MTR"
    case serviceUnit = "ZZ"
}

public struct MonetaryTotal: Codable, Equatable, Sendable {
    public let lineExtensionAmount: MonetaryAmount
    public let taxInclusiveAmount: MonetaryAmount
    public let payableAmount: MonetaryAmount

    public init(
        lineExtensionAmount: MonetaryAmount,
        taxInclusiveAmount: MonetaryAmount,
        payableAmount: MonetaryAmount
    ) {
        self.lineExtensionAmount = lineExtensionAmount
        self.taxInclusiveAmount = taxInclusiveAmount
        self.payableAmount = payableAmount
    }
}
