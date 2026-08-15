import Foundation

/// Escritor XML interno: concentra el escape de contenido y atributos.
struct XMLWriter {
    private var lines: [String] = []
    private var indentationLevel = 0
    private let documentCurrency: CurrencyCode?

    init(documentCurrency: CurrencyCode? = nil) {
        self.documentCurrency = documentCurrency
    }

    var result: String { lines.joined(separator: "\n") }

    mutating func declaration() {
        lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    }

    mutating func open(_ name: String, attributes: [String: String] = [:]) {
        append("<\(name)\(renderedAttributes(attributes))>")
        indentationLevel += 1
    }

    mutating func close(_ name: String) {
        indentationLevel -= 1
        append("</\(name)>")
    }

    mutating func empty(_ name: String, attributes: [String: String] = [:]) {
        append("<\(name)\(renderedAttributes(attributes)) />")
    }

    mutating func element(_ name: String, text: String, attributes: [String: String] = [:]) {
        append("<\(name)\(renderedAttributes(attributes))>\(escape(text))</\(name)>")
    }

    mutating func monetaryElement(_ name: String, amount: MonetaryAmount) {
        guard let documentCurrency else {
            preconditionFailure("XMLWriter requires a document currency for monetary elements")
        }
        element(
            name,
            text: formatMoney(amount.value),
            attributes: ["currencyID": documentCurrency.rawValue]
        )
    }

    mutating func unitPriceElement(_ name: String, amount: MonetaryAmount) {
        guard let documentCurrency else {
            preconditionFailure("XMLWriter requires a document currency for monetary elements")
        }
        element(
            name,
            text: formatDecimal(amount.value, scale: CPEPrecision.unitValueScale),
            attributes: ["currencyID": documentCurrency.rawValue]
        )
    }

    func formatQuantity(_ value: Decimal) -> String {
        formatDecimal(value, scale: CPEPrecision.unitValueScale)
    }

    func formatRate(_ value: Decimal) -> String {
        formatDecimal(value, scale: CPEPrecision.rateScale)
    }

    private mutating func append(_ line: String) {
        lines.append(String(repeating: "   ", count: indentationLevel) + line)
    }

    private func renderedAttributes(_ attributes: [String: String]) -> String {
        attributes.keys.sorted().map { key in
            " \(key)=\"\(escape(attributes[key] ?? ""))\""
        }.joined()
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func formatMoney(_ value: Decimal) -> String {
        let normalized = CPEPrecision.monetary(value)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        return formatter.string(from: normalized as NSDecimalNumber)
            ?? NSDecimalNumber(decimal: normalized).stringValue
    }

    private func formatDecimal(_ value: Decimal, scale: Int) -> String {
        let normalized = CPEPrecision.rounded(value, scale: scale)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = scale
        formatter.roundingMode = .halfUp
        return formatter.string(from: normalized as NSDecimalNumber)
            ?? NSDecimalNumber(decimal: normalized).stringValue
    }
}
