import Foundation
import FlorShopCPE

struct BoletaSmallExample {
    static func getBoletaSmall(serie: String? = nil, correlative: String? = nil) throws -> Boleta {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        guard let timeZone = TimeZone(identifier: "America/Lima") else {
            throw BoletaExampleError.invalidLimaTimeZone
        }
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            throw BoletaExampleError.incompleteCurrentDate
        }
        let series = serie ?? "BC01"
        let correlative = correlative ?? String(max(1, Int(now.timeIntervalSince1970) % 99_999_999))
        
        // MARK: Example of Boleta
        return Boleta(
            identifier: DocumentIdentifier(series: series, number: correlative),
            issueDate: IssueDate(year: year, month: month, day: day),
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
