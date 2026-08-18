import Foundation
import FlorShopCPE

struct NotaDebitoSmallExample {
    static func getNotaDebitoSmall(serie: String? = nil, correlative: String? = nil) throws -> NotaDebito {
        let dateTime = try currentLimaExampleDateTime()

        // MARK: Example of Nota de Debito
        return NotaDebito(
            identifier: DocumentIdentifier(
                series: serie ?? "FD01",
                number: correlative ?? String(max(1, Int(dateTime.instant.timeIntervalSince1970) % 99_999_999))
            ),
            issueDate: IssueDate(year: dateTime.issueDate.year, month: dateTime.issueDate.month, day: dateTime.issueDate.day),
            currency: .pen,
            supplier: Supplier(
                taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
                legalName: "EMISOR S.A.C.",
                address: Address(addressTypeCode: "0000", line: "LIMA")
            ),
            customer: Customer(
                identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
                legalName: "CLIENTE S.A.C."
            ),
            affectedDocument: AffectedDocumentIdentifier(series: "F001", number: "12345", type: .factura),
            reasonCode: .aumentoEnElValor,
            lines: [
                DebitNoteLine(
                    pricing: .taxed(11.80),
                    item: Item(description: "Incremento")
                )
            ]
        )
        // MARK: End of Example
    }
}
