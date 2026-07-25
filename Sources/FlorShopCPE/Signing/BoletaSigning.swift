import Foundation

public protocol BoletaSigning {
    func sign(_ boleta: Boleta, configuration: SigningConfiguration) throws -> SignedBoleta
}

public struct SignedBoleta: Sendable {
    public let xml: Data

    public init(xml: Data) {
        self.xml = xml
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

public enum BoletaSigningError: Error, Equatable, Sendable {
    case unsupportedPlatform
    case invalidSignatureURI
    case signingFailed(String)
}
