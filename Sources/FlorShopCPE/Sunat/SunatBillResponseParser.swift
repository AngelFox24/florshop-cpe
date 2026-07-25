import Foundation
import ZIPFoundation

#if os(Linux)
import FoundationXML
#endif

enum SunatBillResponseParser {
    static func parse(_ response: SunatHTTPResponse) throws -> SunatBillSubmissionResult {
        if let contentType = response.contentType,
           let boundary = multipartBoundary(from: contentType) {
            let parts = try MIMEPart.parse(data: response.body, boundary: boundary)
            for part in parts where part.isSOAP {
                try throwSOAPFaultIfPresent(in: part.body)
            }

            guard let cdrArchive = parts.first(where: { $0.isZIP })?.body else {
                throw SunatBillSubmissionError.invalidSunatResponse
            }
            return try parseCDR(archiveData: cdrArchive)
        } else {
            try throwSOAPFaultIfPresent(in: response.body)
            guard let cdrArchive = SOAPBinaryResponseParser.parse(response.body) else {
                throw SunatBillSubmissionError.invalidSunatResponse
            }
            return try parseCDR(archiveData: cdrArchive)
        }
    }

    private static func parseCDR(archiveData: Data) throws -> SunatBillSubmissionResult {
        let archive: Archive
        do {
            archive = try Archive(data: archiveData, accessMode: .read)
        } catch {
            throw SunatBillSubmissionError.invalidCDR
        }

        let entries = Array(archive)
        guard entries.count == 1, let entry = entries.first,
              entry.type == .file,
              URL(fileURLWithPath: entry.path).pathExtension.caseInsensitiveCompare("xml") == .orderedSame else {
            throw SunatBillSubmissionError.invalidCDR
        }

        var xml = Data()
        do {
            _ = try archive.extract(entry) { xml.append($0) }
        } catch {
            throw SunatBillSubmissionError.invalidCDR
        }

        let cdr = try CDRDocumentParser.parse(xml)
        let status: SunatBillSubmissionStatus
        if cdr.responseCode == "0" {
            status = cdr.observations.isEmpty ? .accepted : .acceptedWithObservations
        } else {
            status = .rejected
        }

        return SunatBillSubmissionResult(
            status: status,
            responseCode: cdr.responseCode,
            descriptions: cdr.descriptions,
            observations: cdr.observations,
            cdrArchive: archiveData,
            cdrXML: xml
        )
    }

    private static func throwSOAPFaultIfPresent(in data: Data) throws {
        guard let fault = SOAPFaultParser.parse(data) else { return }
        throw SunatBillSubmissionError.soapFault(code: fault.code, message: fault.message)
    }

    private static func multipartBoundary(from contentType: String) -> String? {
        for parameter in contentType.split(separator: ";").dropFirst() {
            let pieces = parameter.split(separator: "=", maxSplits: 1)
            guard pieces.count == 2,
                  pieces[0].trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("boundary") == .orderedSame else {
                continue
            }
            return pieces[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return nil
    }
}

private final class SOAPBinaryResponseParser: NSObject, XMLParserDelegate {
    private var isInsideResponseValue = false
    private var responseValue = ""

    static func parse(_ xml: Data) -> Data? {
        let delegate = SOAPBinaryResponseParser()
        let parser = XMLParser(data: xml)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { return nil }
        return Data(base64Encoded: delegate.responseValue, options: .ignoreUnknownCharacters)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = (qName ?? elementName).split(separator: ":").last.map(String.init)
        isInsideResponseValue = name == "applicationResponse" || name == "sendBillReturn" || name == "return"
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideResponseValue {
            responseValue += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = (qName ?? elementName).split(separator: ":").last.map(String.init)
        if name == "applicationResponse" || name == "sendBillReturn" || name == "return" {
            isInsideResponseValue = false
        }
    }
}

private struct MIMEPart {
    let headers: [String: String]
    let body: Data

    var isSOAP: Bool {
        headers["content-type"]?.lowercased().contains("xml") == true
    }

    var isZIP: Bool {
        let contentType = headers["content-type"]?.lowercased() ?? ""
        let disposition = headers["content-disposition"]?.lowercased() ?? ""
        return contentType.contains("zip") || disposition.contains(".zip")
    }

    static func parse(data: Data, boundary: String) throws -> [MIMEPart] {
        let boundaryMarker = Data("--\(boundary)".utf8)
        let separator = Data("\r\n\r\n".utf8)
        let bodyBoundaryMarker = Data("\r\n--\(boundary)".utf8)
        var parts: [MIMEPart] = []
        var searchStart = data.startIndex

        while let markerRange = data.range(of: boundaryMarker, options: [], in: searchStart ..< data.endIndex) {
            var partStart = markerRange.upperBound
            if data[partStart...].starts(with: Data("--".utf8)) {
                break
            }
            if data[partStart...].starts(with: Data("\r\n".utf8)) {
                partStart = data.index(partStart, offsetBy: 2)
            }
            guard let headerRange = data.range(of: separator, options: [], in: partStart ..< data.endIndex) else {
                throw SunatBillSubmissionError.invalidSunatResponse
            }
            let headers = parseHeaders(data[partStart ..< headerRange.lowerBound])
            let bodyStart = headerRange.upperBound
            guard let nextBoundary = data.range(of: bodyBoundaryMarker, options: [], in: bodyStart ..< data.endIndex) else {
                throw SunatBillSubmissionError.invalidSunatResponse
            }
            parts.append(MIMEPart(headers: headers, body: Data(data[bodyStart ..< nextBoundary.lowerBound])))
            searchStart = data.index(nextBoundary.lowerBound, offsetBy: 2)
        }

        guard !parts.isEmpty else {
            throw SunatBillSubmissionError.invalidSunatResponse
        }
        return parts
    }

    private static func parseHeaders(_ data: Data.SubSequence) -> [String: String] {
        let text = String(decoding: data, as: UTF8.self)
        return text.split(separator: "\r\n").reduce(into: [:]) { headers, line in
            let pieces = line.split(separator: ":", maxSplits: 1)
            guard pieces.count == 2 else { return }
            headers[pieces[0].trimmingCharacters(in: .whitespaces).lowercased()] = pieces[1].trimmingCharacters(in: .whitespaces)
        }
    }
}

private struct CDRDocument {
    let responseCode: String
    let descriptions: [String]
    let observations: [SunatObservation]
}

private final class CDRDocumentParser: NSObject, XMLParserDelegate {
    private var responseCode: String?
    private var descriptions: [String] = []
    private var observations: [SunatObservation] = []
    private var currentObservation: SunatObservation?
    private var currentElement: String?
    private var text = ""

    static func parse(_ xml: Data) throws -> CDRDocument {
        let delegate = CDRDocumentParser()
        let parser = XMLParser(data: xml)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), let responseCode = delegate.responseCode else {
            throw SunatBillSubmissionError.invalidCDR
        }
        return CDRDocument(
            responseCode: responseCode,
            descriptions: delegate.descriptions,
            observations: delegate.observations
        )
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = localName(qName ?? elementName)
        currentElement = name
        text = ""
        if name == "Status" {
            currentObservation = SunatObservation(code: nil, description: nil)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = localName(qName ?? elementName)
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "ResponseCode" where !value.isEmpty:
            responseCode = value
        case "Description" where !value.isEmpty:
            descriptions.append(value)
        case "StatusReasonCode" where !value.isEmpty:
            currentObservation = SunatObservation(code: value, description: currentObservation?.description)
        case "StatusReason" where !value.isEmpty:
            currentObservation = SunatObservation(code: currentObservation?.code, description: value)
        case "Status":
            if let currentObservation,
               currentObservation.code != nil || currentObservation.description != nil {
                observations.append(currentObservation)
            }
            currentObservation = nil
        default:
            break
        }
        currentElement = nil
        text = ""
    }

    private func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }
}

private struct SOAPFault {
    let code: String?
    let message: String
}

private final class SOAPFaultParser: NSObject, XMLParserDelegate {
    private var currentElement: String?
    private var text = ""
    private var code: String?
    private var message: String?

    static func parse(_ xml: Data) -> SOAPFault? {
        let delegate = SOAPFaultParser()
        let parser = XMLParser(data: xml)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), let message = delegate.message else { return nil }
        return SOAPFault(code: delegate.code, message: message)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = (qName ?? elementName).split(separator: ":").last.map(String.init)
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = (qName ?? elementName).split(separator: ":").last.map(String.init)
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if name == "faultcode" { code = value }
        if name == "faultstring" { message = value }
        currentElement = nil
        text = ""
    }
}
