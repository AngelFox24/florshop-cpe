import Foundation

/// Escritor XML interno: concentra el escape de contenido y atributos.
struct XMLWriter {
    private var lines: [String] = []
    private var indentationLevel = 0

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
}
