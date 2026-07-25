import Foundation

#if os(Linux)
import FoundationNetworking
#endif

/// Credenciales que se insertan en el encabezado WS-Security de SUNAT.
public enum SunatCredentials: Sendable {
    /// Credenciales públicas del ambiente BETA. Solo requiere el RUC emisor.
    case beta(emitterRUC: String)

    /// Credenciales SOL para producción.
    /// El usuario y la contraseña se proporcionan por cada invocación, por lo
    /// que una misma API puede atender a varios emisores.
    case sol(username: String, password: String)
}

public enum SunatBillSubmissionError: Error, Equatable {
    case invalidEmitterRUC
    case invalidSOLCredentials
    case unableToReadZIP
    case invalidHTTPResponse
    case unexpectedHTTPStatus(statusCode: Int, details: String?)
    case soapFault(code: String?, message: String)
    case invalidSunatResponse
    case invalidCDR(details: String)
    case transportFailed(String)
}

public enum SunatBillSubmissionStatus: Sendable, Equatable {
    case accepted
    case acceptedWithObservations
    case rejected
}

public struct SunatObservation: Sendable, Equatable {
    public let code: String?
    public let description: String?

    public init(code: String?, description: String?) {
        self.code = code
        self.description = description
    }
}

/// Resultado de `sendBill` interpretado a partir del CDR entregado por SUNAT.
public struct SunatBillSubmissionResult: Sendable {
    public let status: SunatBillSubmissionStatus
    public let responseCode: String
    public let descriptions: [String]
    public let observations: [SunatObservation]
    public let cdrArchive: Data
    public let cdrXML: Data

    public init(
        status: SunatBillSubmissionStatus,
        responseCode: String,
        descriptions: [String],
        observations: [SunatObservation],
        cdrArchive: Data,
        cdrXML: Data
    ) {
        self.status = status
        self.responseCode = responseCode
        self.descriptions = descriptions
        self.observations = observations
        self.cdrArchive = cdrArchive
        self.cdrXML = cdrXML
    }
}

public struct SunatHTTPResponse: Sendable {
    public let statusCode: Int
    public let body: Data
    public let contentType: String?

    public init(statusCode: Int, body: Data = Data(), contentType: String? = nil) {
        self.statusCode = statusCode
        self.body = body
        self.contentType = contentType
    }
}

/// Abstracción del transporte para probar SOAP sin enviar documentos a SUNAT.
public protocol SunatHTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> SunatHTTPResponse
}

public struct URLSessionSunatHTTPTransport: SunatHTTPTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> SunatHTTPResponse {
        let (body, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SunatBillSubmissionError.invalidHTTPResponse
        }
        return SunatHTTPResponse(
            statusCode: response.statusCode,
            body: body,
            contentType: response.value(forHTTPHeaderField: "Content-Type")
        )
    }
}

/// Cliente SUNAT para enviar una factura, boleta o nota individual mediante la
/// operación SOAP `sendBill`.
public struct SunatBillClient {
    public static let betaEndpoint = URL(string: "https://e-beta.sunat.gob.pe/ol-ti-itcpfegem-beta/billService")!
    public static let productionEndpoint = URL(string: "https://e-factura.sunat.gob.pe/ol-ti-itcpfegem/billService")!

    private let transport: any SunatHTTPTransport
    private let packageValidator: SunatBillPackageValidator

    public init(
        transport: any SunatHTTPTransport = URLSessionSunatHTTPTransport(),
        packageValidator: SunatBillPackageValidator = SunatBillPackageValidator()
    ) {
        self.transport = transport
        self.packageValidator = packageValidator
    }

    /// Envía un ZIP previamente generado. El endpoint y las credenciales SOAP
    /// se determinan a partir de `credentials`.
    ///
    public func submit(
        zipAt zipURL: URL,
        credentials: SunatCredentials
    ) async throws -> SunatBillSubmissionResult {
        let configuration = try configuration(for: credentials)

        let package = try packageValidator.validate(zipAt: zipURL)
        let archiveData: Data
        do {
            archiveData = try Data(contentsOf: package.archiveURL)
        } catch {
            throw SunatBillSubmissionError.unableToReadZIP
        }

        let request = SunatSOAPRequestBuilder.makeSendBillRequest(
            endpoint: configuration.endpoint,
            package: package,
            archiveData: archiveData,
            username: configuration.username,
            password: configuration.password
        )

        do {
            let response = try await transport.send(request)
            guard (200 ... 299).contains(response.statusCode) else {
                do {
                    _ = try SunatBillResponseParser.parse(response)
                } catch let error as SunatBillSubmissionError {
                    if case .soapFault = error {
                        throw error
                    }
                } catch {
                    // A non-SOAP response is reported below with its HTTP code.
                }
                throw SunatBillSubmissionError.unexpectedHTTPStatus(
                    statusCode: response.statusCode,
                    details: responseDiagnostic(from: response.body)
                )
            }
            return try SunatBillResponseParser.parse(response)
        } catch let error as SunatBillSubmissionError {
            throw error
        } catch {
            throw SunatBillSubmissionError.transportFailed(error.localizedDescription)
        }
    }

    private func configuration(for credentials: SunatCredentials) throws -> SubmissionConfiguration {
        switch credentials {
        case let .beta(emitterRUC):
            guard emitterRUC.range(of: #"^\d{11}$"#, options: .regularExpression) != nil else {
                throw SunatBillSubmissionError.invalidEmitterRUC
            }
            return SubmissionConfiguration(
                endpoint: Self.betaEndpoint,
                username: emitterRUC + "MODDATOS",
                password: "MODDATOS"
            )
        case let .sol(username, password):
            guard !username.isEmpty, !password.isEmpty else {
                throw SunatBillSubmissionError.invalidSOLCredentials
            }
            return SubmissionConfiguration(
                endpoint: Self.productionEndpoint,
                username: username,
                password: password
            )
        }
    }

    private func responseDiagnostic(from body: Data) -> String? {
        let maximumDiagnosticLength = 4_000
        guard let text = String(data: body, encoding: .utf8) else { return nil }
        let diagnostic = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !diagnostic.isEmpty else { return nil }
        return String(diagnostic.prefix(maximumDiagnosticLength))
    }
}

private struct SubmissionConfiguration {
    let endpoint: URL
    let username: String
    let password: String
}

private enum SunatSOAPRequestBuilder {
    static func makeSendBillRequest(
        endpoint: URL,
        package: SunatBillPackage,
        archiveData: Data,
        username: String,
        password: String
    ) -> URLRequest {
        let soapEnvelope = """
        <?xml version="1.0" encoding="UTF-8"?>
        <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ser="http://service.sunat.gob.pe" xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
          <soapenv:Header>
            <wsse:Security>
              <wsse:UsernameToken>
                <wsse:Username>\(escaped(username))</wsse:Username>
                <wsse:Password>\(escaped(password))</wsse:Password>
              </wsse:UsernameToken>
            </wsse:Security>
          </soapenv:Header>
          <soapenv:Body>
            <ser:sendBill>
              <fileName>\(escaped(package.fileName))</fileName>
              <contentFile>\(archiveData.base64EncodedString())</contentFile>
            </ser:sendBill>
          </soapenv:Body>
        </soapenv:Envelope>
        """

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("sendBill", forHTTPHeaderField: "SOAPAction")
        request.httpBody = soapEnvelope.utf8Data
        return request
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private extension String {
    var utf8Data: Data { Data(utf8) }
}
