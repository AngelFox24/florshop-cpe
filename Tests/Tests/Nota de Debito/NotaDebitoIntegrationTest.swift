import Foundation
import Testing
@testable import FlorShopCPE

@Test func notaDebitoLargeLifecycle() async throws {
    //MARK: Creation
    let note = try NotaDebitoLargeExample.getNotaDebitoLarge(serie: "FD01", correlative: "1")
    #expect(note.lines.map(\.id) == ["1", "2"])
    #expect(note.netAmount == 15.00)
    #expect(note.taxAmount == 2.70)
    #expect(note.totalAmount == 17.70)
    #expect(note.lines[1].quantity == nil)
    #expect(note.lines[1].price == nil)
    
    try await verifyNotaDebitoLifecycle(note, prefix: "FlorShopCPE-NotaDebitoLargeIntegration")
}

@Test func notaDebitoSmallLifecycle() async throws {
    //MARK: Creation
    let note = try NotaDebitoSmallExample.getNotaDebitoSmall(serie: "FD01", correlative: "2")
    #expect(note.netAmount == 10.00)
    #expect(note.taxAmount == 1.80)
    #expect(note.totalAmount == 11.80)
    #expect(note.reasonDescription == DebitNoteReasonCode.aumentoEnElValor.defaultDescription)
    
    try await verifyNotaDebitoLifecycle(note, prefix: "FlorShopCPE-NotaDebitoSmallIntegration")
}

private func verifyNotaDebitoLifecycle(_ note: NotaDebito, prefix: String) async throws {
    //MARK: Sing
    let signedNote = try SingDocumentExample.sing(document: note)
    #expect(try XMLSecSignatureVerifier().verify(signedNote.xml))

    try await withTemporaryDirectory(prefix: prefix) { directory in
        //MARK: Zip
        let document = try ZipDocumentExample.zip(signedDocument: signedNote, url: directory)
        #expect(try Data(contentsOf: document.signedXMLURL) == signedNote.xml)
        #expect(!(try Data(contentsOf: document.zipURL)).isEmpty)

        //MARK: Summit
        guard ProcessInfo.processInfo.environment["FLORSHOP_CPE_RUN_NOTA_DEBITO_INTEGRATION_LIFE_CYCLE"] == "true" else {
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
