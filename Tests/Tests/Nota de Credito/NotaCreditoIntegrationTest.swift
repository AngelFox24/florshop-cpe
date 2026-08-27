import Foundation
import Testing
@testable import FlorShopCPE

@Test func notaCreditoLargeLifecycle() async throws {
    //MARK: Creation
    let note = try NotaCreditoLargeExample.getNotaCreditoLarge(serie: "FC01", correlative: "1")
    #expect(note.lines.map(\.id) == ["1"])
    #expect(note.netAmount == 100.00)
    #expect(note.taxAmount == 18.00)
    #expect(note.totalAmount == 118.00)
    #expect(note.reasonDescription == "DEVOLUCIÓN TOTAL DEL PRODUCTO")
    
    try await verifyNotaCreditoLifecycle(note, prefix: "FlorShopCPE-NotaCreditoLargeIntegration")
}

@Test func notaCreditoSmallLifecycle() async throws {
    //MARK: Creation
    let note = try NotaCreditoSmallExample.getNotaCreditoSmall(serie: "FC01", correlative: "2")
    #expect(note.netAmount == 10.00)
    #expect(note.taxAmount == 1.80)
    #expect(note.totalAmount == 11.80)
    #expect(note.reasonDescription == CreditNoteReasonCode.devolucionTotal.defaultDescription)
    
    try await verifyNotaCreditoLifecycle(note, prefix: "FlorShopCPE-NotaCreditoSmallIntegration")
}

private func verifyNotaCreditoLifecycle(_ note: NotaCredito, prefix: String) async throws {
    //MARK: Sing
    let signedNote = try SingDocumentExample.sing(document: note)
    #expect(try XMLSecSignatureVerifier().verify(signedNote.xml))

    try await withTemporaryDirectory(prefix: prefix) { directory in
        //MARK: Zip
        let document = try ZipDocumentExample.zip(signedDocument: signedNote, url: directory)
        #expect(try Data(contentsOf: document.signedXMLURL) == signedNote.xml)
        #expect(!(try Data(contentsOf: document.zipURL)).isEmpty)

        //MARK: Summit
        guard ProcessInfo.processInfo.environment["FLORSHOP_CPE_RUN_NOTA_CREDITO_INTEGRATION_LIFE_CYCLE"] == "true" else {
            return
        }
        let result = try await SummitDocumentExample.summitBeta(
            document: document,
            ruc: note.supplier.taxIdentifier.value
        )
        #expect(result.status == .accepted)
        #expect(result.responseCode == "0")
        #expect(result.observations.isEmpty)
        #expect(!result.cdrArchive.isEmpty)
        #expect(!result.cdrXML.isEmpty)
    }
}
