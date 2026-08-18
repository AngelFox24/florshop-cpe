import Foundation
import FlorShopCPE

struct SummitDocumentExample {
    // Example in: Examples/Zip/ZipDocument.swift to optain CPEDocument
    static func summitBeta(document: CPEDocument, ruc: String) async throws -> SunatBillSubmissionResult {
        // MARK: Example of Summit Beta
        let result: SunatBillSubmissionResult = try await SunatBillClient().submit(
            document: document,
            credentials: .beta(emitterRUC: ruc) //Se enviara a SUNAT beta
        )
        let status = result.status                                  //Enum: accepted, acceptedWithObservations, rejected
        let resposeCode: String = result.responseCode
        let descriptions: [String] = result.descriptions
        let observations: [SunatObservation] = result.observations
        // MARK: End of Example
        return result
    }
    
    static func summitProd(document: CPEDocument, username: String, password: String) async throws -> SunatBillSubmissionResult {
        let result: SunatBillSubmissionResult = try await SunatBillClient().submit(
            document: document,
            credentials: .sol(username: username, password: password) //Se enviara a SUNAT Produccion
        )
        return result
    }

    static func summitSummaryBeta(document: CPEDocument, ruc: String) async throws -> SunatSummarySubmission {
        try await SunatSummaryClient().submit(
            document: document,
            credentials: .beta(emitterRUC: ruc)
        )
    }

    static func summaryStatusBeta(ticket: String, document: CPEDocument, ruc: String) async throws -> SunatSummaryProcessingResult {
        try await SunatSummaryClient().status(
            ticket: ticket,
            document: document,
            credentials: .beta(emitterRUC: ruc)
        )
    }
}
