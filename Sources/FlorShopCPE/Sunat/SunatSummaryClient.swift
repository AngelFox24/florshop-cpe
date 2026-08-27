import Foundation

#if os(Linux)
import FoundationNetworking
#endif

public enum SunatSummaryError: Error, Equatable {
    case invalidEmitterRUC
    case invalidSOLCredentials
    case unableToReadZIP
    case invalidHTTPResponse
    case unexpectedHTTPStatus(statusCode: Int, details: String?)
    case soapFault(code: String?, message: String)
    case invalidSunatResponse
    case missingTicket
    case missingCDR(statusCode: String)
    case unknownStatusCode(String)
    case invalidCDR(details: String)
    case transportFailed(String)
}

public struct SunatSummarySubmission: Sendable, Equatable {
    public let ticket: String

    public init(ticket: String) {
        self.ticket = ticket
    }
}

public enum SunatSummaryProcessingResult: Sendable {
    case processing
    case completed(SunatBillSubmissionResult)
    case failed(SunatBillSubmissionResult)
}

/// Cliente del flujo asíncrono `sendSummary` / `getStatus` de SUNAT.
struct SunatSummaryClient {
    static let betaEndpoint = SunatBillClient.betaEndpoint
    static let productionEndpoint = SunatBillClient.productionEndpoint

    private let transport: any SunatHTTPTransport
    private let packageValidator: SunatSummaryPackageValidator
    private let documentWriter: CPEDocumentWriter

    init(
        transport: any SunatHTTPTransport = URLSessionSunatHTTPTransport(),
        packageValidator: SunatSummaryPackageValidator = SunatSummaryPackageValidator(),
        documentWriter: CPEDocumentWriter = CPEDocumentWriter()
    ) {
        self.transport = transport
        self.packageValidator = packageValidator
        self.documentWriter = documentWriter
    }

    func submit(
        document: SunatSummaryDocument,
        credentials: SunatCredentials
    ) async throws -> SunatSummarySubmission {
        let configuration = try configuration(for: credentials)
        let package = try packageValidator.validate(zipAt: document.zipURL)
        let archive: Data
        do { archive = try Data(contentsOf: package.archiveURL) }
        catch { throw SunatSummaryError.unableToReadZIP }
        let request = SummarySOAPRequestBuilder.sendSummary(
            endpoint: configuration.endpoint,
            fileName: package.fileName,
            archive: archive,
            username: configuration.username,
            password: configuration.password
        )
        let response = try await send(request)
        return SunatSummarySubmission(ticket: try SummarySOAPResponseParser.ticket(from: response.body))
    }

    /// Consulta una vez el ticket. El consumidor decide cuándo volver a
    /// consultar si SUNAT devuelve el código 98 (en proceso).
    func status(
        ticket: String,
        document: SunatSummaryDocument,
        credentials: SunatCredentials
    ) async throws -> SunatSummaryProcessingResult {
        guard !ticket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SunatSummaryError.missingTicket
        }
        let configuration = try configuration(for: credentials)
        let request = SummarySOAPRequestBuilder.getStatus(
            endpoint: configuration.endpoint,
            ticket: ticket,
            username: configuration.username,
            password: configuration.password
        )
        let response = try await send(request)
        let status = try SummarySOAPResponseParser.status(from: response.body)
        if status.code == "98" { return .processing }
        guard status.code == "0" || status.code == "99" else {
            throw SunatSummaryError.unknownStatusCode(status.code)
        }
        guard let content = status.content else { throw SunatSummaryError.missingCDR(statusCode: status.code) }
        let result: SunatBillSubmissionResult
        do { result = try SunatBillResponseParser.parseCDR(archiveData: content) }
        catch let error as SunatBillSubmissionError { throw map(error) }
        let artifacts = try documentWriter.storeCDR(result, for: document)
        let stored = SunatBillSubmissionResult(
            status: result.status,
            responseCode: result.responseCode,
            descriptions: result.descriptions,
            observations: result.observations,
            cdrArchive: result.cdrArchive,
            cdrXML: result.cdrXML,
            cdrArtifacts: artifacts
        )
        return status.code == "0" ? .completed(stored) : .failed(stored)
    }

    private func send(_ request: URLRequest) async throws -> SunatHTTPResponse {
        do {
            let response = try await transport.send(request)
            do { try SunatBillResponseParser.throwSOAPFaultIfPresent(in: response.body) }
            catch let error as SunatBillSubmissionError { throw map(error) }
            guard (200 ... 299).contains(response.statusCode) else {
                throw SunatSummaryError.unexpectedHTTPStatus(
                    statusCode: response.statusCode,
                    details: String(data: response.body, encoding: .utf8).map { String($0.prefix(4_000)) }
                )
            }
            return response
        } catch let error as SunatSummaryError { throw error }
        catch { throw SunatSummaryError.transportFailed(error.localizedDescription) }
    }

    private func configuration(for credentials: SunatCredentials) throws -> SummaryConfiguration {
        switch credentials {
        case let .beta(ruc):
            guard ruc.range(of: #"^\d{11}$"#, options: .regularExpression) != nil else {
                throw SunatSummaryError.invalidEmitterRUC
            }
            return SummaryConfiguration(endpoint: Self.betaEndpoint, username: ruc + "MODDATOS", password: "MODDATOS")
        case let .sol(username, password):
            guard !username.isEmpty, !password.isEmpty else { throw SunatSummaryError.invalidSOLCredentials }
            return SummaryConfiguration(endpoint: Self.productionEndpoint, username: username, password: password)
        }
    }

    private func map(_ error: SunatBillSubmissionError) -> SunatSummaryError {
        switch error {
        case let .soapFault(code, message): return .soapFault(code: code, message: message)
        case let .invalidCDR(details): return .invalidCDR(details: details)
        case .invalidSunatResponse: return .invalidSunatResponse
        default: return .transportFailed(String(describing: error))
        }
    }
}

private struct SummaryConfiguration {
    let endpoint: URL
    let username: String
    let password: String
}

private enum SummarySOAPRequestBuilder {
    static func sendSummary(endpoint: URL, fileName: String, archive: Data, username: String, password: String) -> URLRequest {
        request(
            endpoint: endpoint,
            action: "sendSummary",
            body: "<ser:sendSummary><fileName>\(escape(fileName))</fileName><contentFile>\(archive.base64EncodedString())</contentFile></ser:sendSummary>",
            username: username,
            password: password
        )
    }

    static func getStatus(endpoint: URL, ticket: String, username: String, password: String) -> URLRequest {
        request(
            endpoint: endpoint,
            action: "getStatus",
            body: "<ser:getStatus><ticket>\(escape(ticket))</ticket></ser:getStatus>",
            username: username,
            password: password
        )
    }

    private static func request(endpoint: URL, action: String, body: String, username: String, password: String) -> URLRequest {
        let envelope = """
        <?xml version="1.0" encoding="UTF-8"?>
        <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ser="http://service.sunat.gob.pe" xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
          <soapenv:Header><wsse:Security><wsse:UsernameToken><wsse:Username>\(escape(username))</wsse:Username><wsse:Password>\(escape(password))</wsse:Password></wsse:UsernameToken></wsse:Security></soapenv:Header>
          <soapenv:Body>\(body)</soapenv:Body>
        </soapenv:Envelope>
        """
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("urn:\(action)", forHTTPHeaderField: "SOAPAction")
        request.httpBody = Data(envelope.utf8)
        return request
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

#if os(Linux)
import FoundationXML
#endif

private enum SummarySOAPResponseParser {
    static func ticket(from xml: Data) throws -> String {
        let values = try parse(xml)
        guard let ticket = values.ticket, !ticket.isEmpty else { throw SunatSummaryError.missingTicket }
        return ticket
    }

    static func status(from xml: Data) throws -> (code: String, content: Data?) {
        let values = try parse(xml)
        guard let code = values.statusCode, !code.isEmpty else { throw SunatSummaryError.invalidSunatResponse }
        let content = values.content.flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) }
        return (code, content)
    }

    private static func parse(_ xml: Data) throws -> SummarySOAPValues {
        let delegate = SummarySOAPDelegate()
        let parser = XMLParser(data: xml)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { throw SunatSummaryError.invalidSunatResponse }
        return SummarySOAPValues(ticket: delegate.ticket, statusCode: delegate.statusCode, content: delegate.content)
    }
}

private struct SummarySOAPValues { let ticket: String?; let statusCode: String?; let content: String? }

private final class SummarySOAPDelegate: NSObject, XMLParserDelegate {
    var ticket: String?
    var statusCode: String?
    var content: String?
    private var current = ""
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        current = (qName ?? elementName).split(separator: ":").last.map(String.init) ?? elementName
        text = ""
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = (qName ?? elementName).split(separator: ":").last.map(String.init) ?? elementName
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if ["ticket", "sendSummaryReturn", "return"].contains(name), statusCode == nil, !value.isEmpty { ticket = value }
        if name == "statusCode" { statusCode = value }
        if name == "content" { content = value }
        current = ""
        text = ""
    }
}
