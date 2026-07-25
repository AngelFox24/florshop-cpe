import Foundation

public protocol CPESigning {
    func sign(
        _ document: any UBLInvoiceDocument,
        configuration: SigningConfiguration
    ) throws -> SignedCPE
}

/// Comprobante electrónico firmado, aún sin escribir en disco.
///
/// Además del XML, conserva la identidad necesaria para crear sus archivos
/// SUNAT sin volver a pedir el modelo de dominio original.
public struct SignedCPE: Sendable {
    public let xml: Data
    public let identity: CPEIdentity

    public init(xml: Data, identity: CPEIdentity) {
        self.xml = xml
        self.identity = identity
    }

    public var xmlString: String? {
        String(data: xml, encoding: .utf8)
    }
}

public struct SigningConfiguration: Sendable {
    public let signature: SignatureInformation
    public let credentials: SigningCredentials

    public init(signature: SignatureInformation, credentials: SigningCredentials) {
        self.signature = signature
        self.credentials = credentials
    }
}

public enum SigningCredentials: Sendable {
    case pkcs12(
        path: URL,
        passwordProvider: @Sendable () throws -> String
    )
}

public enum CPESigningError: Error, Equatable, Sendable {
    case unsupportedPlatform
    case invalidSignatureURI
    case signingFailed(String)
}
