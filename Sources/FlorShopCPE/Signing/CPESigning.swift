import Foundation

protocol CPESigning {
    func sign(
        _ document: any UBLInvoiceDocument,
        configuration: SigningConfiguration
    ) throws -> SignedBillCPE
}

/// Capacidad interna de firma específica para notas de crédito.
protocol CreditNoteSigning {
    func sign(
        _ note: NotaCredito,
        configuration: SigningConfiguration
    ) throws -> SignedBillCPE
}

/// Capacidad interna de firma específica para notas de débito.
protocol DebitNoteSigning {
    func sign(
        _ note: NotaDebito,
        configuration: SigningConfiguration
    ) throws -> SignedBillCPE
}

/// Capacidad interna de firma específica para comunicaciones de baja.
protocol VoidedDocumentsSigning {
    func sign(
        _ communication: ComunicacionBaja,
        configuration: SigningConfiguration
    ) throws -> SignedSummaryCPE
}

/// Comprobante electrónico firmado, aún sin escribir en disco.
///
/// Además del XML, conserva la identidad necesaria para crear sus archivos
/// SUNAT sin volver a pedir el modelo de dominio original.
public protocol SignedCPE: Sendable {
    var xml: Data { get }
    var identity: CPEIdentity { get }
}

public extension SignedCPE {
    var xmlString: String? {
        String(data: xml, encoding: .utf8)
    }
}

/// CPE firmado que se envía mediante la operación SUNAT `sendBill`.
public struct SignedBillCPE: SignedCPE {
    public let xml: Data
    public let identity: CPEIdentity

    init(xml: Data, identity: CPEIdentity) {
        self.xml = xml
        self.identity = identity
    }
}

/// CPE firmado que se envía mediante la operación SUNAT `sendSummary`.
public struct SignedSummaryCPE: SignedCPE {
    public let xml: Data
    public let identity: CPEIdentity

    init(xml: Data, identity: CPEIdentity) {
        self.xml = xml
        self.identity = identity
    }
}

public struct SigningConfiguration: Sendable {
    public let credentials: SigningCredentials

    public init(credentials: SigningCredentials) {
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
    case signingFailed(String)
}
