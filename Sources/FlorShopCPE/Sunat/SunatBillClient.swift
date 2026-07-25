import Foundation

#if os(Linux)
import FoundationNetworking
#endif

/// Credenciales que se insertan en el encabezado WS-Security de SUNAT.
public enum SunatCredentials: Sendable {
    /// Credenciales públicas del ambiente BETA. Solo requiere el RUC emisor.
    case beta(emitterRUC: String)

    /// Credenciales SOL para una futura implementación de producción.
    /// El usuario y la contraseña se proporcionan por cada invocación, por lo
    /// que una misma API puede atender a varios emisores.
    case sol(username: String, password: String)
}

public enum SunatBillSubmissionError: Error, Equatable {
    case invalidEmitterRUC
    case invalidSOLCredentials
    case unableToReadZIP
    case invalidHTTPResponse
    case unexpectedHTTPStatus(Int)
    case transportFailed(String)
}

/// Acuse técnico del envío. El CDR y la respuesta SOAP se procesarán en la
/// siguiente iteración.
public struct SunatBillSubmissionReceipt: Sendable {
    public let statusCode: Int

    public init(statusCode: Int) {
        self.statusCode = statusCode
    }
}

public struct SunatHTTPResponse: Sendable {
    public let statusCode: Int

    public init(statusCode: Int) {
        self.statusCode = statusCode
    }
}

/// Abstracción del transporte para probar SOAP sin enviar documentos a SUNAT.
public protocol SunatHTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> SunatHTTPResponse
}

public struct URLSessionSunatHTTPTransport: SunatHTTPTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> SunatHTTPResponse {
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SunatBillSubmissionError.invalidHTTPResponse
        }
        return SunatHTTPResponse(statusCode: response.statusCode)
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
    /// Esta primera versión no interpreta el cuerpo de la respuesta ni el CDR
    /// devuelto por SUNAT.
    public func submit(
        zipAt zipURL: URL,
        credentials: SunatCredentials
    ) async throws -> SunatBillSubmissionReceipt {
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
                throw SunatBillSubmissionError.unexpectedHTTPStatus(response.statusCode)
            }
            return SunatBillSubmissionReceipt(statusCode: response.statusCode)
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
        let boundary = "FlorShopCPE-\(UUID().uuidString)"
        let rootContentID = "soap-envelope@florshop-cpe"
        let archiveContentID = "\(package.fileName)@florshop-cpe"
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
              <contentFile>cid:\(archiveContentID)</contentFile>
            </ser:sendBill>
          </soapenv:Body>
        </soapenv:Envelope>
        """

        var body = Data()
        body.append("--\(boundary)\r\n".utf8Data)
        body.append("Content-Type: text/xml; charset=UTF-8\r\n".utf8Data)
        body.append("Content-Transfer-Encoding: 8bit\r\n".utf8Data)
        body.append("Content-ID: <\(rootContentID)>\r\n\r\n".utf8Data)
        body.append(soapEnvelope.utf8Data)
        body.append("\r\n--\(boundary)\r\n".utf8Data)
        body.append("Content-Type: application/zip\r\n".utf8Data)
        body.append("Content-Transfer-Encoding: binary\r\n".utf8Data)
        body.append("Content-ID: <\(archiveContentID)>\r\n".utf8Data)
        body.append("Content-Disposition: attachment; filename=\"\(package.fileName)\"\r\n\r\n".utf8Data)
        body.append(archiveData)
        body.append("\r\n--\(boundary)--\r\n".utf8Data)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/related; type=\"text/xml\"; start=\"<\(rootContentID)>\"; boundary=\"\(boundary)\"",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue("text/xml", forHTTPHeaderField: "SOAPAction")
        request.httpBody = body
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
