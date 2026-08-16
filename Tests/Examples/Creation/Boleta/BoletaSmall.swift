import Foundation
import FlorShopCPE

struct BoletaSmall {
    static func getBoletaSmallExample(now: Date = Date()) throws -> Boleta {
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

        return Boleta(
            identifier: DocumentIdentifier(
                series: "BC01",
                number: String(max(1, Int(now.timeIntervalSince1970) % 99_999_999))
            ),
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
                    id: "1",
                    quantity: .units(1),
                    pricing: .taxed(10),
                    item: Item(description: "Producto")
                )
            ]
        )
    }
}
