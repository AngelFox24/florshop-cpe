import Foundation
//MARK: SIGN
/// Firma una factura usando la configuración indicada.
public func sign(_ document: Factura, configuration: SigningConfiguration) throws -> SignedBillCPE {
    try XMLSecCPESigner().sign(document, configuration: configuration)
}
/// Firma una boleta usando la configuración indicada.
public func sign(_ document: Boleta, configuration: SigningConfiguration) throws -> SignedBillCPE {
    try XMLSecCPESigner().sign(document, configuration: configuration)
}
/// Firma una nota de crédito usando la configuración indicada.
public func sign(_ document: NotaCredito, configuration: SigningConfiguration) throws -> SignedBillCPE {
    try XMLSecCPESigner().sign(document, configuration: configuration)
}
/// Firma una nota de débito usando la configuración indicada.
public func sign(_ document: NotaDebito, configuration: SigningConfiguration) throws -> SignedBillCPE {
    try XMLSecCPESigner().sign(document, configuration: configuration)
}
/// Firma un resumen diario usando la configuración indicada.
public func sign(_ document: ResumenDiarioBoletas, configuration: SigningConfiguration) throws -> SignedSummaryCPE {
    try XMLSecCPESigner().sign(document, configuration: configuration)
}
/// Firma una comunicación de baja usando la configuración indicada.
public func sign(_ document: ComunicacionBaja, configuration: SigningConfiguration) throws -> SignedSummaryCPE {
    try XMLSecCPESigner().sign(document, configuration: configuration)
}
//MARK: VERIFY
/// Verifica la integridad de la firma XMLDSIG contenida en un documento UBL.
public func verify(_ signedXML: Data) throws -> Bool {
    try XMLSecSignatureVerifier().verify(signedXML)
}
//MARK: WRITE
/// Escribe el XML firmado y crea el ZIP que se enviará a SUNAT.
public func write(_ signedDocument: SignedBillCPE, output: CPEOutputConfiguration) throws -> SunatBillDocument {
    try CPEDocumentWriter().write(signedDocument, output: output)
}
/// Escribe un resumen o comunicación firmada y crea su ZIP para SUNAT.
public func write(_ signedDocument: SignedSummaryCPE, output: CPEOutputConfiguration) throws -> SunatSummaryDocument {
    try CPEDocumentWriter().write(signedDocument, output: output)
}
//MARK: SUBMIT
/// Envía una factura, boleta o nota mediante `sendBill`.
public func submit(document: SunatBillDocument, credentials: SunatCredentials) async throws -> SunatBillSubmissionResult {
    try await SunatBillClient().submit(document: document, credentials: credentials)
}
/// Envía un resumen diario o comunicación de baja mediante `sendSummary`.
public func submit(document: SunatSummaryDocument, credentials: SunatCredentials) async throws -> SunatSummarySubmission {
    try await SunatSummaryClient().submit(document: document, credentials: credentials)
}
//MARK: STATUS
/// Consulta una vez el estado de un ticket de resumen diario o comunicación de baja.
public func status(ticket: String, document: SunatSummaryDocument, credentials: SunatCredentials) async throws -> SunatSummaryProcessingResult {
    try await SunatSummaryClient().status(ticket: ticket, document: document, credentials: credentials)
}
