import Foundation
import Testing
@testable import FlorShopCPE

@Test func comunicacionBajaLargeLifecycle() async throws {
    //MARK: Creation
    let communication = try ComunicacionBajaLargeExample.getComunicacionBajaLarge(sequence: 1)
    #expect(communication.lines.count == 3)
    #expect(communication.lines.map(\.lineID) == [1, 2, 3])
    #expect(communication.lines.map(\.documentType) == [.factura, .notaDeCredito, .notaDeDebito])
    
    try await verifyComunicacionBajaLifecycle(
        communication,
        prefix: "FlorShopCPE-ComunicacionBajaLargeIntegration"
    )
}

@Test func comunicacionBajaSmallLifecycle() async throws {
    //MARK: Creation
    let communication = try ComunicacionBajaSmallExample.getComunicacionBajaSmall(sequence: 2)
    #expect(communication.lines.count == 1)
    #expect(communication.lines[0].documentType == .factura)
    
    try await verifyComunicacionBajaLifecycle(
        communication,
        prefix: "FlorShopCPE-ComunicacionBajaSmallIntegration"
    )
}

private func verifyComunicacionBajaLifecycle(_ communication: ComunicacionBaja, prefix: String) async throws {
    //MARK: Sing
    let signedCommunication = try SingDocumentExample.sing(document: communication)
    #expect(try FlorShopCPE.verify(signedCommunication.xml))

    try await withTemporaryDirectory(prefix: prefix) { directory in
        //MARK: Zip
        let document = try ZipDocumentExample.zip(signedDocument: signedCommunication, url: directory)
        #expect(try Data(contentsOf: document.signedXMLURL) == signedCommunication.xml)
        #expect(!(try Data(contentsOf: document.zipURL)).isEmpty)

        //MARK: Summit
        guard ProcessInfo.processInfo.environment["FLORSHOP_CPE_RUN_COMUNICACION_BAJA_INTEGRATION_LIFE_CYCLE"] == "true" else {
            return
        }
        let submission = try await SummitDocumentExample.summitSummaryBeta(
            document: document,
            ruc: communication.supplier.taxIdentifier.value
        )
        #expect(!submission.ticket.isEmpty)
        
        //MARK: Verify Status
        let status = try await SummitDocumentExample.summaryStatusBeta(
            ticket: submission.ticket,
            document: document,
            ruc: communication.supplier.taxIdentifier.value
        )
        switch status {
        case .processing:
            break
        case let .completed(result):
            #expect(result.responseCode == "0")
            #expect(result.status == .accepted || result.status == .acceptedWithObservations)
        case let .failed(result):
            Issue.record("SUNAT rechazó la comunicación de baja: \(result.responseCode)")
        }
    }
}
