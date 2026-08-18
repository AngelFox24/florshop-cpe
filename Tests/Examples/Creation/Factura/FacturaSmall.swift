import Foundation
import FlorShopCPE

struct FacturaSmallExample {
    static func getFacturaSmall(serie: String? = nil, correlative: String? = nil) throws -> Factura {
        let dateTime = try currentLimaExampleDateTime()

        // MARK: Example of Factura
        return Factura(
            identifier: DocumentIdentifier(
                series: serie ?? "F001",
                number: correlative ?? String(max(1, Int(dateTime.instant.timeIntervalSince1970) % 99_999_999))
            ),
            issueDate: IssueDate(year: dateTime.issueDate.year, month: dateTime.issueDate.month, day: dateTime.issueDate.day),
            currency: .pen,
            supplier: Supplier(
                taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
                legalName: "Vega Poblete Carlos Enrique"
            ),
            customer: Customer(
                identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
                legalName: "CLIENTE S.A.C."
            ),
            lines: [
                InvoiceLine(
                    quantity: .units(1),
                    pricing: .taxed(11.80),
                    item: Item(description: "Producto")
                )
            ],
            paymentCondition: .cash
        )
        // MARK: End of Example
    }
}
