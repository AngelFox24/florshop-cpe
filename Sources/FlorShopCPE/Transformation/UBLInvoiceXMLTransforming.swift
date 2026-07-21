/// Contrato para transformar una boleta del dominio a un documento XML UBL.
public protocol UBLInvoiceXMLTransforming {
    func transform(_ boleta: Boleta) throws -> String
}
