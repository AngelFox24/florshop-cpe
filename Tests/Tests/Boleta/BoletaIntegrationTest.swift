import Foundation
import Testing
@testable import FlorShopCPE

@Suite(.serialized)
struct BoletaIntegrationTests {
    @Test func boletaLargeLifecycle() async throws {
        //MARK: Creation
        let boleta = try BoletaLargeExample.getBoletaLarge(serie: "BC01", correlative: "0001")
        #expect(boleta.netAmount == 1048.77)
        #expect(boleta.taxAmount == 181.27)
        #expect(boleta.totalAmount == 1230.04)
        #expect(boleta.lines[1].lineExtensionAmount.value == 86.30)
        #expect(boleta.lines[4].isFreeOfCharge == true)
        #expect(boleta.lines[4].lineExtensionAmount.value == 11.26)
        
        //MARK: Sing
        let signedBoleta = try SingDocumentExample.sing(document: boleta)
        #expect(try XMLSecSignatureVerifier().verify(signedBoleta.xml))
        
        //Creation of temporary directory to zip
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("FlorShopCPE-BoletaIntegration-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }
        
        //MARK: Zip
        let document = try ZipDocumentExample.zip(signedDocument: signedBoleta, url: temporaryDirectory)
        #expect(try Data(contentsOf: document.signedXMLURL) == signedBoleta.xml)
        #expect(!(try Data(contentsOf: document.zipURL)).isEmpty)
        //MARK: Summit
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_BOLETA_INTEGRATION_LIFE_CYCLE"] == "true" else { return }
        let result = try await SummitDocumentExample.summitBeta(document: document, ruc: boleta.supplier.taxIdentifier.value)
        #expect(result.status == .accepted)
        #expect(result.responseCode == "0")
        #expect(result.observations.isEmpty)
        #expect(!result.cdrArchive.isEmpty)
        #expect(!result.cdrXML.isEmpty)
        #expect(result.cdrArtifacts != nil)
    }
    @Test func boletaSmallLifecycle() async throws {
        //MARK: Creation
        let boleta = try BoletaSmallExample.getBoletaSmall(serie: "BC01", correlative: "0001")
        #expect(boleta.netAmount == 1048.77)
        #expect(boleta.taxAmount == 181.27)
        #expect(boleta.totalAmount == 1230.04)
        #expect(boleta.lines[1].lineExtensionAmount.value == 10)
        
        //MARK: Sing
        let signedBoleta = try SingDocumentExample.sing(document: boleta)
        #expect(try XMLSecSignatureVerifier().verify(signedBoleta.xml))
        
        //Creation of temporary directory to zip
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("FlorShopCPE-BoletaIntegration-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }
        
        //MARK: Zip
        let document = try ZipDocumentExample.zip(signedDocument: signedBoleta, url: temporaryDirectory)
        #expect(try Data(contentsOf: document.signedXMLURL) == signedBoleta.xml)
        #expect(!(try Data(contentsOf: document.zipURL)).isEmpty)
        //MARK: Summit
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_BOLETA_INTEGRATION_LIFE_CYCLE"] == "true" else { return }
        let result = try await SummitDocumentExample.summitBeta(document: document, ruc: boleta.supplier.taxIdentifier.value)
        #expect(result.status == .accepted)
        #expect(result.responseCode == "0")
        #expect(result.observations.isEmpty)
        #expect(!result.cdrArchive.isEmpty)
        #expect(!result.cdrXML.isEmpty)
        #expect(result.cdrArtifacts != nil)
    }
}
