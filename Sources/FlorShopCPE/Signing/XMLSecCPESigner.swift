import Foundation

#if os(Linux) || os(macOS)
import XMLSecBridge
#endif

/// Firma los CPE UBL soportados mediante XMLDSIG usando libxmlsec.
public struct XMLSecCPESigner: CPESigning {
    private let transformer: any UBLInvoiceXMLTransforming
    private let dailySummaryTransformer: any DailySummaryXMLTransforming

    public init(
        transformer: any UBLInvoiceXMLTransforming = UBLInvoiceXMLTransformer(),
        dailySummaryTransformer: any DailySummaryXMLTransforming = DailySummaryXMLTransformer()
    ) {
        self.transformer = transformer
        self.dailySummaryTransformer = dailySummaryTransformer
    }

    public func sign(
        _ summary: ResumenDiarioBoletas,
        configuration: SigningConfiguration
    ) throws -> SignedCPE {
        let unsignedXML = try dailySummaryTransformer.transform(summary, signature: configuration.signature)
        let signatureID = try signatureID(from: configuration.signature.uri)
        switch configuration.credentials {
        case let .pkcs12(path, passwordProvider):
            return try signPKCS12(
                xml: Data(unsignedXML.utf8),
                path: path,
                password: passwordProvider(),
                signatureID: signatureID,
                identity: CPEIdentity(summary: summary)
            )
        }
    }

    public func sign(
        _ document: any UBLInvoiceDocument,
        configuration: SigningConfiguration
    ) throws -> SignedCPE {
        let unsignedXML = try transformer.transform(document, signature: configuration.signature)
        let signatureID = try signatureID(from: configuration.signature.uri)

        switch configuration.credentials {
        case let .pkcs12(path, passwordProvider):
            return try signPKCS12(
                xml: Data(unsignedXML.utf8),
                path: path,
                password: passwordProvider(),
                signatureID: signatureID,
                identity: CPEIdentity(document: document)
            )
        }
    }

    private func signatureID(from uri: String) throws -> String {
        guard uri.hasPrefix("#"), uri.count > 1 else {
            throw CPESigningError.invalidSignatureURI
        }
        return String(uri.dropFirst())
    }

    private func signPKCS12(
        xml: Data,
        path: URL,
        password: String,
        signatureID: String,
        identity: CPEIdentity
    ) throws -> SignedCPE {
        #if os(Linux) || os(macOS)
        var signedXML: UnsafeMutablePointer<UInt8>?
        var signedXMLSize = 0
        var errorMessage: UnsafeMutablePointer<CChar>?

        let result = xml.withUnsafeBytes { xmlBytes in
            path.path.withCString { pathPointer in
                password.withCString { passwordPointer in
                    signatureID.withCString { signatureIDPointer in
                        flor_shop_xmlsec_sign_pkcs12(
                            xmlBytes.bindMemory(to: UInt8.self).baseAddress,
                            xml.count,
                            pathPointer,
                            passwordPointer,
                            signatureIDPointer,
                            &signedXML,
                            &signedXMLSize,
                            &errorMessage
                        )
                    }
                }
            }
        }

        defer {
            if let signedXML { flor_shop_xmlsec_free(signedXML) }
            if let errorMessage { flor_shop_xmlsec_free(errorMessage) }
        }

        guard result == 0, let signedXML else {
            let message = errorMessage.map { String(cString: $0) } ?? "Error desconocido de libxmlsec."
            throw CPESigningError.signingFailed(message)
        }
        return SignedCPE(
            xml: Data(bytes: signedXML, count: signedXMLSize),
            identity: identity
        )
        #else
        throw CPESigningError.unsupportedPlatform
        #endif
    }
}
