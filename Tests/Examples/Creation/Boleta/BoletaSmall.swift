import Foundation
import FlorShopCPE

struct BoletaSmallExample {
    static func getBoletaSmall(serie: String? = nil, correlative: String? = nil) throws -> Boleta {
        let dateTime = try currentLimaExampleDateTime()
        let series = serie ?? "BC01"
        let correlative = correlative ?? String(timestampBasedNumber(from: dateTime.instant, modulo: 99_999_999))
        
        // MARK: Example of Boleta
        return Boleta(
            identifier: DocumentIdentifier(series: series, number: correlative),
            issueDate: IssueDate(year: dateTime.issueDate.year, month: dateTime.issueDate.month, day: dateTime.issueDate.day),
            currency: .pen,
            supplier: Supplier(
                taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
                legalName: "Vega Poblete Carlos Enrique"
            ),
            customer: Customer(
                identifier: PartyIdentifier(value: "46237547", documentType: .dni),
                legalName: "Pazos Atoche Luana Karina"
            ),
            lines: [
                InvoiceLine(
                    quantity: .units(1),
                    pricing: .taxed(11.80),
                    item: Item(description: "Producto")
                )
            ]
        )
        // MARK: End of Example
    }
}
