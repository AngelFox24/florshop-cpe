/// Contrato para transformar una factura o boleta a un documento UBL Invoice.
public protocol UBLInvoiceXMLTransforming {
    func transform(_ document: any UBLInvoiceDocument) throws -> String
}
