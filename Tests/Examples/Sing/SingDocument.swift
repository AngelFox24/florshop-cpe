import Foundation
import FlorShopCPE

struct SingDocumentExample {
    static func sing(document: Factura) throws -> SignedBillCPE {
        // MARK: Example of Sing
        let signedDocument: SignedBillCPE = try FlorShopCPE.sign(
            document,
            configuration: configuration
        )
        // MARK: End of Example
        return signedDocument
    }

    static func sing(document: Boleta) throws -> SignedBillCPE {
        try FlorShopCPE.sign(document, configuration: configuration)
    }

    static func sing(document: NotaCredito) throws -> SignedBillCPE {
        try FlorShopCPE.sign(document, configuration: configuration)
    }

    static func sing(document: NotaDebito) throws -> SignedBillCPE {
        try FlorShopCPE.sign(document, configuration: configuration)
    }

    static func sing(document: ResumenDiarioBoletas) throws -> SignedSummaryCPE {
        try FlorShopCPE.sign(document, configuration: configuration)
    }

    static func sing(document: ComunicacionBaja) throws -> SignedSummaryCPE {
        try FlorShopCPE.sign(document, configuration: configuration)
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
