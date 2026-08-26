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
        try await retrySummaryBetaAuthentication {
            try await SunatSummaryClient().submit(
                document: document,
                credentials: .beta(emitterRUC: ruc)
            )
        }
    }

    static func summaryStatusBeta(ticket: String, document: CPEDocument, ruc: String) async throws -> SunatSummaryProcessingResult {
        try await retrySummaryBetaAuthentication {
            try await SunatSummaryClient().status(
                ticket: ticket,
                document: document,
                credentials: .beta(emitterRUC: ruc)
            )
        }
    }

    /// El ambiente público BETA puede responder HTTP 401 cuando `sendSummary`
    /// y `getStatus` autentican con MODDATOS con muy poca separación. Esta
    /// política pertenece solamente al ejemplo de integración; el cliente de
    /// la librería conserva y entrega la respuesta original de SUNAT.
    private static func retrySummaryBetaAuthentication<T>(
        operation: () async throws -> T
    ) async throws -> T {
        let maximumAttempts = 3

        for attempt in 1 ... maximumAttempts {
            do {
                return try await operation()
            } catch let error as SunatSummaryError {
                guard case .unexpectedHTTPStatus(statusCode: 401, details: _) = error,
                      attempt < maximumAttempts else {
                    throw error
                }
                print("SUNAT BETA RESUMEN DIARIO: HTTP 401, reintento \(attempt + 1)/\(maximumAttempts)")
                try await Task.sleep(for: .seconds(2))
            }
        }

        preconditionFailure("El bucle de reintentos debe devolver o lanzar un error.")
    }
}
