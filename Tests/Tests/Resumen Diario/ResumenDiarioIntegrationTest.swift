import Foundation
import Testing
@testable import FlorShopCPE

@Suite(.serialized)
struct ResumenDiarioIntegrationTests {
    @Test func resumenDiarioLargeLifecycle() async throws {
        //MARK: Creation
        let summary = try ResumenDiarioLargeExample.getResumenDiarioLarge(sequence: 1)
        #expect(summary.lines.count == 4)
        #expect(summary.lines.map(\.lineID) == [1, 2, 3, 4])
        #expect(summary.lines.map(\.documentType) == [.boleta, .boleta, .notaDeCredito, .notaDeDebito])
        #expect(summary.lines.allSatisfy { $0.condition == .add })

        try await verifyResumenDiarioLifecycle(summary, prefix: "FlorShopCPE-ResumenDiarioLargeIntegration")
    }

    @Test func resumenDiarioSmallLifecycle() async throws {
        //MARK: Creation
        let summary = try ResumenDiarioSmallExample.getResumenDiarioSmall(sequence: 2)
        #expect(summary.lines.count == 1)
        #expect(summary.lines[0].lineID == 1)
        #expect(summary.lines[0].condition == .add)

        try await verifyResumenDiarioLifecycle(summary, prefix: "FlorShopCPE-ResumenDiarioSmallIntegration")
    }

    @Test func resumenDiarioModifyLifecycle() async throws {
        //MARK: Creation
        let summary = try ResumenDiarioModifyExample.getResumenDiarioModify(sequence: 3)
        #expect(summary.lines.count == 1)
        #expect(summary.lines[0].condition == .modify)

        try await verifyResumenDiarioLifecycle(summary, prefix: "FlorShopCPE-ResumenDiarioModifyIntegration")
    }

    @Test func resumenDiarioVoidLifecycle() async throws {
        //MARK: Creation
        let summary = try ResumenDiarioVoidExample.getResumenDiarioVoid(sequence: 4)
        #expect(summary.lines.count == 1)
        #expect(summary.lines[0].condition == .void)

        try await verifyResumenDiarioLifecycle(summary, prefix: "FlorShopCPE-ResumenDiarioVoidIntegration")
    }
}

private func verifyResumenDiarioLifecycle(_ summary: ResumenDiarioBoletas, prefix: String) async throws {
    //MARK: Sing
    let signedSummary = try SingDocumentExample.sing(document: summary)
    #expect(try XMLSecSignatureVerifier().verify(signedSummary.xml))

    try await withTemporaryDirectory(prefix: prefix) { directory in
        //MARK: Zip
        let document = try ZipDocumentExample.zip(signedDocument: signedSummary, url: directory)
        #expect(try Data(contentsOf: document.signedXMLURL) == signedSummary.xml)
        #expect(!(try Data(contentsOf: document.zipURL)).isEmpty)

        //MARK: Summit
        guard ProcessInfo.processInfo.environment["FLORSHOP_CPE_RUN_RESUMEN_DIARIO_INTEGRATION_LIFE_CYCLE"] == "true" else {
            return
        }
        let submission = try await SummitDocumentExample.summitSummaryBeta(
            document: document,
            ruc: summary.supplier.taxIdentifier.value
        )
        #expect(!submission.ticket.isEmpty)
        
        //MARK: Verify Status
        let status = try await SummitDocumentExample.summaryStatusBeta(
            ticket: submission.ticket,
            document: document,
            ruc: summary.supplier.taxIdentifier.value
        )
        switch status {
        case .processing:
            break
        case let .completed(result):
            #expect(result.responseCode == "0")
            #expect(result.status == .accepted || result.status == .acceptedWithObservations)
        case let .failed(result):
            Issue.record("SUNAT rechazó el resumen diario: \(result.responseCode)")
        }
    }
}
