import Foundation
import FlorShopCPE

struct SingDocumentExample {
    // Boleta y Factura conforman UBLInvoiceDocument.
    static func sing(document: UBLInvoiceDocument) throws -> SignedCPE {
        // MARK: Example of Sing
        let signedDocument: SignedCPE = try XMLSecCPESigner().sign(
            document,
            configuration: configuration
        )
        // MARK: End of Example
        return signedDocument
    }

    static func sing(document: NotaCredito) throws -> SignedCPE {
        try XMLSecCPESigner().sign(document, configuration: configuration)
    }

    static func sing(document: NotaDebito) throws -> SignedCPE {
        try XMLSecCPESigner().sign(document, configuration: configuration)
    }

    static func sing(document: ResumenDiarioBoletas) throws -> SignedCPE {
        try XMLSecCPESigner().sign(document, configuration: configuration)
    }

    static func sing(document: ComunicacionBaja) throws -> SignedCPE {
        try XMLSecCPESigner().sign(document, configuration: configuration)
    }

    private static var configuration: SigningConfiguration {
        SigningConfiguration(
            credentials: .pkcs12(
                path: URL(fileURLWithPath: "/Users/angel/Downloads/LLAMA-PE-CERTIFICADO-DEMO-1070825519.pfx"),
                passwordProvider: { "Foxangel2498." }
            )
        )
    }
}
