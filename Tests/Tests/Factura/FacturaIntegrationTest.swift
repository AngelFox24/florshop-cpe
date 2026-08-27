import Foundation
import Testing
@testable import FlorShopCPE

@Test func facturaLargeLifecycle() async throws {
    //MARK: Creation
    let factura = try FacturaLargeExample.getFacturaLarge(serie: "F001", correlative: "1")
    #expect(factura.netAmount == 1329.06)
    #expect(factura.taxAmount == 231.72)
    #expect(factura.totalAmount == 1560.78)
    #expect(factura.lines.count == 6)
    #expect(factura.lines[4].isFreeOfCharge == true)
    
    try await verifyFacturaLifecycle(
        factura,
        temporaryDirectoryPrefix: "FlorShopCPE-FacturaLargeIntegration"
    )
}

@Test func facturaSmallLifecycle() async throws {
    //MARK: Creation
    let factura = try FacturaSmallExample.getFacturaSmall(serie: "F001", correlative: "2")
    #expect(factura.netAmount == 10.00)
    #expect(factura.taxAmount == 1.80)
    #expect(factura.totalAmount == 11.80)
    #expect(factura.paymentCondition == .cash)
    
    try await verifyFacturaLifecycle(
        factura,
        temporaryDirectoryPrefix: "FlorShopCPE-FacturaSmallIntegration"
    )
}

private func verifyFacturaLifecycle(_ factura: Factura, temporaryDirectoryPrefix: String) async throws {
    //MARK: Sing
    let signedFactura = try SingDocumentExample.sing(document: factura)
    #expect(try FlorShopCPE.verify(signedFactura.xml))

    try await withTemporaryDirectory(prefix: temporaryDirectoryPrefix) { directory in
        //MARK: Zip
        let document = try ZipDocumentExample.zip(signedDocument: signedFactura, url: directory)
        #expect(try Data(contentsOf: document.signedXMLURL) == signedFactura.xml)
        #expect(!(try Data(contentsOf: document.zipURL)).isEmpty)

        //MARK: Summit
        guard ProcessInfo.processInfo.environment["FLORSHOP_CPE_RUN_FACTURA_INTEGRATION_LIFE_CYCLE"] == "true" else {
            return
        }
        let result = try await SummitDocumentExample.summitBeta(
            document: document,
            ruc: factura.supplier.taxIdentifier.value
        )
        #expect(result.status == .accepted)
        #expect(result.responseCode == "0")
        #expect(result.observations.isEmpty)
        #expect(!result.cdrArchive.isEmpty)
        #expect(!result.cdrXML.isEmpty)
        #expect(result.cdrArtifacts != nil)
    }
}
