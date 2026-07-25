import Foundation

#if os(Linux) || os(macOS)
import XMLSecBridge
#endif

/// Verifica la integridad de una firma XMLDSIG contenida en un documento UBL.
public protocol XMLSignatureVerifying {
    /// - Returns: `true` si la firma coincide con el contenido actual del XML;
    ///   `false` si el XML fue alterado o la firma no es válida.
    ///
    /// Esta operación usa el certificado incluido en `ds:KeyInfo` para revisar
    /// la integridad. No sustituye una validación de confianza de la cadena de
    /// certificados, que se incorporará con una política de certificados.
    func verify(_ xml: Data) throws -> Bool
}

public enum XMLSignatureVerificationError: Error, Equatable {
    case unsupportedPlatform
    case verificationFailed(String)
}

public struct XMLSecSignatureVerifier: XMLSignatureVerifying {
    public init() {}

    public func verify(_ xml: Data) throws -> Bool {
        #if os(Linux) || os(macOS)
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = xml.withUnsafeBytes { xmlBytes in
            flor_shop_xmlsec_verify(
                xmlBytes.bindMemory(to: UInt8.self).baseAddress,
                xml.count,
                &errorMessage
            )
        }

        defer {
            if let errorMessage { flor_shop_xmlsec_free(errorMessage) }
        }

        guard result >= 0 else {
            let message = errorMessage.map { String(cString: $0) } ?? "Error desconocido de libxmlsec."
            throw XMLSignatureVerificationError.verificationFailed(message)
        }
        return result == 1
        #else
        throw XMLSignatureVerificationError.unsupportedPlatform
        #endif
    }
}
