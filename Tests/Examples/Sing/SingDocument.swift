import Foundation
import FlorShopCPE

struct SingDocument {
    // Example of UBLInvoiceDocument in: Examples/Creation/...
    // Boleta, Factura, Nota de Credito, Nota de Debito, Resumen Diario y Comunicación de Baja conforman UBLInvoiceDocument
    static func sing(document: UBLInvoiceDocument) async throws -> SignedCPE {
        // MARK: Example of Sing
        let signedBoleta: SignedCPE = try XMLSecCPESigner().sign(
            document,
            configuration: SigningConfiguration(
                credentials: .pkcs12(
                    path: URL(fileURLWithPath: "/Users/angel/Downloads/LLAMA-PE-CERTIFICADO-DEMO-1070825519.pfx"),
                    passwordProvider: { "Foxangel2498." }
                )
            )
        )
        // MARK: End of Example
        return signedBoleta
    }
}
