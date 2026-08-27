import Foundation
import Testing
@testable import FlorShopCPE

@Test func boletaLargeLifecycle() async throws {
    //MARK: Creation
    let boleta = try BoletaLargeExample.getBoletaLarge(serie: "BC01", correlative: "1")
    #expect(boleta.netAmount == 1048.77)
    #expect(boleta.taxAmount == 181.27)
    #expect(boleta.totalAmount == 1230.04)
    #expect(boleta.lines[1].lineExtensionAmount.value == 86.30)
    #expect(boleta.lines[4].isFreeOfCharge == true)
    #expect(boleta.lines[4].lineExtensionAmount.value == 11.26)
    
    //MARK: Sing
    let signedBoleta = try SingDocumentExample.sing(document: boleta)
    #expect(try FlorShopCPE.verify(signedBoleta.xml))
    
    try await withTemporaryDirectory(prefix: "FlorShopCPE-BoletaLargeIntegration") { temporaryDirectory in
        //MARK: Zip
        let document = try ZipDocumentExample.zip(
            signedDocument: signedBoleta,
            url: temporaryDirectory
        )
        #expect(try Data(contentsOf: document.signedXMLURL) == signedBoleta.xml)
        #expect(!(try Data(contentsOf: document.zipURL)).isEmpty)
        
        //Print XML
        let signedXML = try Data(contentsOf: document.signedXMLURL)
        print("""
            ===== BOLETA FIRMADA Y EMPAQUETADA =====
            XML: \(document.signedXMLURL.path)
            ZIP: \(document.zipURL.path)
            \(String(decoding: signedXML, as: UTF8.self))
            ===== FIN BOLETA FIRMADA Y EMPAQUETADA =====
            """)
        //MARK: Summit
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_BOLETA_INTEGRATION_LIFE_CYCLE"] == "true" else {
            return
        }
        let result = try await SummitDocumentExample.summitBeta(
            document: document,
            ruc: boleta.supplier.taxIdentifier.value
        )
        #expect(result.status == .accepted)
        #expect(result.responseCode == "0")
        #expect(result.observations.isEmpty)
        #expect(!result.cdrArchive.isEmpty)
        #expect(!result.cdrXML.isEmpty)
        #expect(result.cdrArtifacts != nil)
        
        //Print result
        let cdrXML = result.cdrArtifacts.flatMap { try? Data(contentsOf: $0.xmlURL) }
        print("""
            ===== RESPUESTA SUNAT BETA =====
            Estado: \(result.status)
            Código: \(result.responseCode)
            Descripciones: \(result.descriptions)
            Observaciones: \(result.observations)
            \(cdrXML.map { String(decoding: $0, as: UTF8.self) } ?? "CDR no disponible")
            ===== FIN RESPUESTA SUNAT BETA =====
            """)
    }
}

@Test func boletaSmallLifecycle() async throws {
    //MARK: Creation
    let boleta = try BoletaSmallExample.getBoletaSmall(serie: "BC01", correlative: "2")
    #expect(boleta.netAmount == 10.00)
    #expect(boleta.taxAmount == 1.80)
    #expect(boleta.totalAmount == 11.80)
    #expect(boleta.lines.count == 1)
    #expect(boleta.lines[0].lineExtensionAmount.value == 10.00)
    
    //MARK: Sing
    let signedBoleta = try SingDocumentExample.sing(document: boleta)
    #expect(try FlorShopCPE.verify(signedBoleta.xml))
    
    try await withTemporaryDirectory(prefix: "FlorShopCPE-BoletaSmallIntegration") { temporaryDirectory in
        //MARK: Zip
        let document = try ZipDocumentExample.zip(
            signedDocument: signedBoleta,
            url: temporaryDirectory
        )
        #expect(try Data(contentsOf: document.signedXMLURL) == signedBoleta.xml)
        #expect(!(try Data(contentsOf: document.zipURL)).isEmpty)
        
        //MARK: Summit
        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_BOLETA_INTEGRATION_LIFE_CYCLE"] == "true" else {
            return
        }
        let result = try await SummitDocumentExample.summitBeta(
            document: document,
            ruc: boleta.supplier.taxIdentifier.value
        )
        #expect(result.status == .accepted)
        #expect(result.responseCode == "0")
        #expect(result.observations.isEmpty)
        #expect(!result.cdrArchive.isEmpty)
        #expect(!result.cdrXML.isEmpty)
        #expect(result.cdrArtifacts != nil)
    }
}
