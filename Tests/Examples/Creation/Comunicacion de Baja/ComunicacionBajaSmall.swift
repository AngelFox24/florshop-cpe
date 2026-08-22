import FlorShopCPE

struct ComunicacionBajaSmallExample {
    static func getComunicacionBajaSmall(sequence: Int? = nil) throws -> ComunicacionBaja {
        let context = try makeComunicacionBajaExampleContext()

        // MARK: Example of Comunicacion de Baja
        return try ComunicacionBaja(
            sequence: sequence ?? context.sequence,
            issueDate: context.issueDate,
            referenceDate: context.issueDate,
            supplier: Supplier(
                taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
                legalName: "EMISOR S.A.C."
            ),
            lines: [
                VoidedDocumentLine(
                    lineID: 1,
                    documentType: .factura,
                    documentIdentifier: DocumentIdentifier(series: "F001", number: "12345"),
                    reason: "DOCUMENTO NO OTORGADO"
                )
            ]
        )
        // MARK: End of Example
    }
}
