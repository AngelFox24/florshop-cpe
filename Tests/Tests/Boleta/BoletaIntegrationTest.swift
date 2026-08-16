import Foundation
import Testing
@testable import FlorShopCPE

@Suite(.serialized)
struct BoletaIntegrationTests {
    @Test func completeBoletaLifecycle() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_BOLETA_EXAMPLE"] == "true" else {
            return
        }

        let boleta = try BoletaLarge.getBoletaLargeExample()
        #expect(boleta.netAmount == 1048.77)
        #expect(boleta.taxAmount == 181.27)
        #expect(boleta.totalAmount == 1230.04)
        #expect(boleta.lines[1].lineExtensionAmount.value == 86.30)
        #expect(boleta.lines[4].isFreeOfCharge == true)
        #expect(boleta.lines[4].lineExtensionAmount.value == 11.26)

        let signingConfiguration = SigningConfiguration(
            credentials: .pkcs12(
                path: URL(fileURLWithPath: "/Users/angel/Downloads/LLAMA-PE-CERTIFICADO-DEMO-1070825519.pfx"),
                passwordProvider: { "Foxangel2498." }
            )
        )
        let signedBoleta = try XMLSecCPESigner().sign(
            boleta,
            configuration: signingConfiguration
        )
        #expect(try XMLSecSignatureVerifier().verify(signedBoleta.xml))

        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("FlorShopCPE-BoletaIntegration-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let document = try CPEDocumentWriter().write(
            signedBoleta,
            output: CPEOutputConfiguration(rootDirectory: temporaryDirectory)
        )
        #expect(try Data(contentsOf: document.signedXMLURL) == signedBoleta.xml)
        #expect(!(try Data(contentsOf: document.zipURL)).isEmpty)

        let result = try await SunatBillClient().submit(
            document: document,
            credentials: .beta(emitterRUC: boleta.supplier.taxIdentifier.value)
        )
        #expect(result.status == .accepted)
        #expect(result.responseCode == "0")
        #expect(result.observations.isEmpty)
        #expect(!result.cdrArchive.isEmpty)
        #expect(!result.cdrXML.isEmpty)
        #expect(result.cdrArtifacts != nil)
    }
}
