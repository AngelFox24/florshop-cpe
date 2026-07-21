import Foundation

/// Convierte un importe monetario a la leyenda exigida por el comprobante.
public protocol AmountInWordsFormatting: Sendable {
    func format(_ amount: Decimal, currency: CurrencyCode) throws -> String
}

public enum AmountInWordsError: Error, Equatable, Sendable {
    case negativeAmount
    case moreThanTwoDecimalPlaces
    case exceedsMaximumAmount
}
