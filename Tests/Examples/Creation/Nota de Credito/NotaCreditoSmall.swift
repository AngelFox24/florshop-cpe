import Foundation
import FlorShopCPE

struct NotaCreditoSmallExample {
    static func getNotaCreditoSmall(serie: String? = nil, correlative: String? = nil) throws -> NotaCredito {
        let dateTime = try currentLimaExampleDateTime()

        // MARK: Example of Nota de Credito
        return NotaCredito(
            identifier: DocumentIdentifier(
                series: serie ?? "FC01",
                number: correlative ?? String(timestampBasedNumber(from: dateTime.instant, modulo: 99_999_999))
            ),
            issueDate: IssueDate(year: dateTime.issueDate.year, month: dateTime.issueDate.month, day: dateTime.issueDate.day),
            currency: .pen,
            supplier: Supplier(
                taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
                legalName: "EMISOR S.A.C."
            ),
            customer: Customer(
                identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
                legalName: "CLIENTE S.A.C."
            ),
            affectedDocument: AffectedDocumentIdentifier(series: "F001", number: "12345", type: .factura),
            reasonCode: .devolucionTotal,
            lines: [
                CreditNoteLine(
                    quantity: .units(1),
                    pricing: .taxed(11.80),
                    item: Item(description: "Producto devuelto")
                )
            ]
        )
        // MARK: End of Example
    }
}
