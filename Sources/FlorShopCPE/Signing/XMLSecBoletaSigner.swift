import Foundation

#if os(Linux) || os(macOS)
import XMLSecBridge
#endif

/// Firma una boleta UBL mediante XMLDSIG usando libxmlsec en Linux.
public struct XMLSecBoletaSigner: BoletaSigning {
    private let transformer: any UBLInvoiceXMLTransforming

    public init(transformer: any UBLInvoiceXMLTransforming = UBLInvoiceXMLTransformer()) {
        self.transformer = transformer
    }

    public func sign(_ boleta: Boleta, configuration: SigningConfiguration) throws -> SignedBoleta {
        let boletaToSign = boleta.replacing(signature: configuration.signature)
        let unsignedXML = try transformer.transform(boletaToSign)
        let signatureID = try signatureID(from: configuration.signature.uri)

        switch configuration.credentials {
        case let .pkcs12(path, passwordProvider):
            return try signPKCS12(
                xml: Data(unsignedXML.utf8),
                path: path,
                password: passwordProvider(),
                signatureID: signatureID
            )
        }
    }

    private func signatureID(from uri: String) throws -> String {
        guard uri.hasPrefix("#"), uri.count > 1 else {
            throw BoletaSigningError.invalidSignatureURI
        }
        return String(uri.dropFirst())
    }

    private func signPKCS12(xml: Data, path: URL, password: String, signatureID: String) throws -> SignedBoleta {
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
            throw BoletaSigningError.signingFailed(message)
        }
        return SignedBoleta(xml: Data(bytes: signedXML, count: signedXMLSize))
        #else
        throw BoletaSigningError.unsupportedPlatform
        #endif
    }
}

private extension Boleta {
    func replacing(signature: SignatureInformation) -> Boleta {
        Boleta(
            identifier: identifier,
            issueDate: issueDate,
            issueTime: issueTime,
            currency: currency,
            supplier: supplier,
            customer: customer,
            taxTotal: taxTotal,
            monetaryTotal: monetaryTotal,
            lines: lines,
            signature: signature,
            ublVersion: ublVersion,
            customizationID: customizationID
        )
    }
}
