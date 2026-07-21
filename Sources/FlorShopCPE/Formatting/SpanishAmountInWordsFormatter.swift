import Foundation

/// Formatea importes positivos en español usando la convención `CON NN/100`.
public struct SpanishAmountInWordsFormatter: AmountInWordsFormatting, Sendable {
    /// Máximo expresable: 999,999,999,999,999.99.
    public static let maximumAmount = Decimal(string: "999999999999999.99", locale: Locale(identifier: "en_US_POSIX"))!

    public init() {}

    public func format(_ amount: Decimal, currency: CurrencyCode) throws -> String {
        guard amount >= 0 else { throw AmountInWordsError.negativeAmount }
        guard amount <= Self.maximumAmount else { throw AmountInWordsError.exceedsMaximumAmount }

        let cents = try cents(from: amount)
        let integerPart = cents / 100
        let fractionalPart = cents % 100
        let words = words(for: integerPart)
        return "SON \(words) CON \(String(format: "%02d", fractionalPart))/100 \(currencyName(for: currency))"
    }

    private func cents(from amount: Decimal) throws -> Int64 {
        var scaled = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        guard scaled == rounded else { throw AmountInWordsError.moreThanTwoDecimalPlaces }
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    private func currencyName(for currency: CurrencyCode) -> String {
        switch currency {
        case .pen: "SOLES"
        case .usd: "DÓLARES AMERICANOS"
        case .eur: "EUROS"
        }
    }

    private func words(for number: Int64) -> String {
        guard number > 0 else { return "CERO" }

        let groups = [
            Int(number % 1_000),
            Int((number / 1_000) % 1_000),
            Int((number / 1_000_000) % 1_000),
            Int((number / 1_000_000_000) % 1_000),
            Int((number / 1_000_000_000_000) % 1_000)
        ]
        let fragments = groups.enumerated().reversed().compactMap { index, group -> String? in
            guard group > 0 else { return nil }
            return groupWords(group, scale: index)
        }
        return masculine(fragments.joined(separator: " "))
    }

    private func groupWords(_ number: Int, scale: Int) -> String {
        let words = hundreds(number)
        switch scale {
        case 0:
            return words
        case 1:
            return number == 1 ? "MIL" : "\(masculine(words)) MIL"
        case 2:
            return number == 1 ? "UN MILLÓN" : "\(masculine(words)) MILLONES"
        case 3:
            return number == 1 ? "MIL MILLONES" : "\(masculine(words)) MIL MILLONES"
        case 4:
            return number == 1 ? "UN BILLÓN" : "\(masculine(words)) BILLONES"
        default:
            return words
        }
    }

    private func hundreds(_ number: Int) -> String {
        precondition((0...999).contains(number))
        if number < 100 { return tens(number) }
        if number == 100 { return "CIEN" }

        let hundreds = [
            1: "CIENTO", 2: "DOSCIENTOS", 3: "TRESCIENTOS", 4: "CUATROCIENTOS",
            5: "QUINIENTOS", 6: "SEISCIENTOS", 7: "SETECIENTOS", 8: "OCHOCIENTOS", 9: "NOVECIENTOS"
        ]
        let prefix = hundreds[number / 100]!
        let remainder = number % 100
        return remainder == 0 ? prefix : "\(prefix) \(tens(remainder))"
    }

    private func tens(_ number: Int) -> String {
        let basic = [
            0: "CERO", 1: "UNO", 2: "DOS", 3: "TRES", 4: "CUATRO", 5: "CINCO",
            6: "SEIS", 7: "SIETE", 8: "OCHO", 9: "NUEVE", 10: "DIEZ", 11: "ONCE",
            12: "DOCE", 13: "TRECE", 14: "CATORCE", 15: "QUINCE", 16: "DIECISÉIS",
            17: "DIECISIETE", 18: "DIECIOCHO", 19: "DIECINUEVE", 20: "VEINTE",
            21: "VEINTIUNO", 22: "VEINTIDÓS", 23: "VEINTITRÉS", 24: "VEINTICUATRO",
            25: "VEINTICINCO", 26: "VEINTISÉIS", 27: "VEINTISIETE", 28: "VEINTIOCHO", 29: "VEINTINUEVE"
        ]
        if let value = basic[number] { return value }

        let tens = [3: "TREINTA", 4: "CUARENTA", 5: "CINCUENTA", 6: "SESENTA", 7: "SETENTA", 8: "OCHENTA", 9: "NOVENTA"]
        let ten = number / 10
        let unit = number % 10
        return unit == 0 ? tens[ten]! : "\(tens[ten]!) Y \(basic[unit]!)"
    }

    private func masculine(_ words: String) -> String {
        if words.hasSuffix("VEINTIUNO") {
            return String(words.dropLast(9)) + "VEINTIÚN"
        }
        if words.hasSuffix(" Y UNO") {
            return String(words.dropLast(3)) + "UN"
        }
        if words.hasSuffix("UNO") {
            return String(words.dropLast(3)) + "UN"
        }
        return words
    }
}
