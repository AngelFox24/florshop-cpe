import Foundation

#if os(Linux) || os(macOS)
import XMLSecBridge
#endif

/// Firma los CPE UBL soportados mediante XMLDSIG usando libxmlsec.
struct XMLSecCPESigner: CPESigning, CreditNoteSigning, DebitNoteSigning, VoidedDocumentsSigning {
    private let transformer: any UBLInvoiceXMLTransforming
    private let dailySummaryTransformer: any DailySummaryXMLTransforming
    private let creditNoteTransformer: any CreditNoteXMLTransforming
    private let debitNoteTransformer: any DebitNoteXMLTransforming
    private let voidedDocumentsTransformer: any VoidedDocumentsXMLTransforming

    init(
        transformer: any UBLInvoiceXMLTransforming = UBLInvoiceXMLTransformer(),
        dailySummaryTransformer: any DailySummaryXMLTransforming = DailySummaryXMLTransformer(),
        creditNoteTransformer: any CreditNoteXMLTransforming = CreditNoteXMLTransformer(),
        debitNoteTransformer: any DebitNoteXMLTransforming = DebitNoteXMLTransformer(),
        voidedDocumentsTransformer: any VoidedDocumentsXMLTransforming = VoidedDocumentsXMLTransformer()
    ) {
        self.transformer = transformer
        self.dailySummaryTransformer = dailySummaryTransformer
        self.creditNoteTransformer = creditNoteTransformer
        self.debitNoteTransformer = debitNoteTransformer
        self.voidedDocumentsTransformer = voidedDocumentsTransformer
    }

    func sign(_ summary: ResumenDiarioBoletas, configuration: SigningConfiguration) throws -> SignedSummaryCPE {
        let unsignedXML = try dailySummaryTransformer.transform(summary)
        switch configuration.credentials {
        case let .pkcs12(path, passwordProvider):
            return SignedSummaryCPE(
                xml: try signPKCS12(
                    xml: Data(unsignedXML.utf8),
                    path: path,
                    password: passwordProvider(),
                    signatureID: SignatureInformation.xmlSignatureID
                ),
                identity: CPEIdentity(summary: summary)
            )
        }
    }

    func sign(
        _ document: any UBLInvoiceDocument,
        configuration: SigningConfiguration
    ) throws -> SignedBillCPE {
        let unsignedXML = try transformer.transform(document)

        switch configuration.credentials {
        case let .pkcs12(path, passwordProvider):
            return SignedBillCPE(
                xml: try signPKCS12(
                    xml: Data(unsignedXML.utf8),
                    path: path,
                    password: passwordProvider(),
                    signatureID: SignatureInformation.xmlSignatureID
                ),
                identity: CPEIdentity(document: document)
            )
        }
    }

    func sign(
        _ note: NotaCredito,
        configuration: SigningConfiguration
    ) throws -> SignedBillCPE {
        let unsignedXML = try creditNoteTransformer.transform(note)

        switch configuration.credentials {
        case let .pkcs12(path, passwordProvider):
            return SignedBillCPE(
                xml: try signPKCS12(
                    xml: Data(unsignedXML.utf8),
                    path: path,
                    password: passwordProvider(),
                    signatureID: SignatureInformation.xmlSignatureID
                ),
                identity: CPEIdentity(note: note)
            )
        }
    }

    func sign(
        _ note: NotaDebito,
        configuration: SigningConfiguration
    ) throws -> SignedBillCPE {
        let unsignedXML = try debitNoteTransformer.transform(note)

        switch configuration.credentials {
        case let .pkcs12(path, passwordProvider):
            return SignedBillCPE(
                xml: try signPKCS12(
                    xml: Data(unsignedXML.utf8),
                    path: path,
                    password: passwordProvider(),
                    signatureID: SignatureInformation.xmlSignatureID
                ),
                identity: CPEIdentity(debitNote: note)
            )
        }
    }

    func sign(
        _ communication: ComunicacionBaja,
        configuration: SigningConfiguration
    ) throws -> SignedSummaryCPE {
        let unsignedXML = try voidedDocumentsTransformer.transform(communication)

        switch configuration.credentials {
        case let .pkcs12(path, passwordProvider):
            return SignedSummaryCPE(
                xml: try signPKCS12(
                    xml: Data(unsignedXML.utf8),
                    path: path,
                    password: passwordProvider(),
                    signatureID: SignatureInformation.xmlSignatureID
                ),
                identity: CPEIdentity(communication: communication)
            )
        }
    }

    private func signPKCS12(
        xml: Data,
        path: URL,
        password: String,
        signatureID: String
    ) throws -> Data {
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
        return Data(bytes: signedXML, count: signedXMLSize)
        #else
        throw CPESigningError.unsupportedPlatform
        #endif
    }
}
