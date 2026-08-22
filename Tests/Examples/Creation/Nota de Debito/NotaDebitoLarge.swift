import Foundation
import FlorShopCPE

struct NotaDebitoLargeExample {
    static func getNotaDebitoLarge(
        serie: String? = nil,
        correlative: String? = nil,
        affectedBoleta: Boleta? = nil
    ) throws -> NotaDebito {
        let dateTime = try currentLimaExampleDateTime()

        // MARK: Example of Nota de Debito
        return NotaDebito(
            identifier: DocumentIdentifier(
                series: serie ?? "FD01",
                number: correlative ?? String(timestampBasedNumber(from: dateTime.instant, modulo: 99_999_999))
            ),
            issueDate: affectedBoleta?.issueDate ?? IssueDate(year: dateTime.issueDate.year, month: dateTime.issueDate.month, day: dateTime.issueDate.day),
            issueTime: IssueTime(hour: dateTime.issueTime.hour, minute: dateTime.issueTime.minute, second: dateTime.issueTime.second),    // Por defecto: nil
            currency: .pen,
            supplier: affectedBoleta?.supplier ?? Supplier(
                taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
                commercialName: "EMISOR",                    // Por defecto: nil
                legalName: "EMISOR S.A.C.",
                address: Address(                             // Por defecto: nil
                    ubigeoCode: "150130",                    // Por defecto: nil
                    addressTypeCode: "0000",                 // Por defecto: nil
                    urbanization: "URB. SAN BORJA",          // Por defecto: nil
                    city: "LIMA",                            // Por defecto: nil
                    department: "LIMA",                      // Por defecto: nil
                    district: "SAN BORJA",                   // Por defecto: nil
                    line: "CAL. PABLO USANDIZAGA 670",
                    countryCode: "PE"                        // Por defecto: "PE"
                ),
                contact: Contact(                             // Por defecto: nil
                    telephone: "+51 999 999 999",            // Por defecto: nil
                    email: "ventas@ejemplo.pe"               // Por defecto: nil
                )
            ),
            customer: affectedBoleta?.customer ?? Customer(
                identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
                legalName: "CLIENTE S.A.C.",
                address: Address(                             // Por defecto: nil
                    ubigeoCode: "150122",                    // Por defecto: nil
                    addressTypeCode: "0000",                 // Por defecto: nil
                    urbanization: "URB. MIRAFLORES",         // Por defecto: nil
                    city: "LIMA",                            // Por defecto: nil
                    department: "LIMA",                      // Por defecto: nil
                    district: "MIRAFLORES",                  // Por defecto: nil
                    line: "CAL. AUGUSTO ANGULO 130",
                    countryCode: "PE"                        // Por defecto: "PE"
                )
            ),
            affectedDocument: affectedBoleta.map { AffectedDocumentIdentifier(boleta: $0) }
                ?? AffectedDocumentIdentifier(series: "F001", number: "12345", type: .factura),
            reasonCode: .aumentoEnElValor,
            reasonDescription: "AUMENTO EN EL VALOR DEL PRODUCTO", // Por defecto: descripción de .aumentoEnElValor
            lines: [
                DebitNoteLine(
                    quantity: .units(1),
                    pricing: .taxed(10.00, rate: 18, basis: .excludingTaxes),
                    item: Item(
                        description: "AUMENTO EN EL VALOR DEL PRODUCTO",
                        sellerItemIdentifier: "P001",         // Por defecto: nil
                        commodityClassificationCode: "52141501" // Por defecto: nil
                    )
                ),
                DebitNoteLine(
                    pricing: .taxed(5.00, rate: 18, basis: .excludingTaxes),
                    item: Item(description: "PENALIDAD SIN CANTIDAD NI PRECIO UNITARIO")
                )
            ],
            payableRoundingAmount: nil,                       // Por defecto: nil
            additionalNotes: [DocumentNote("AJUSTE COORDINADO CON EL CLIENTE")] // Por defecto: []
        )
        // MARK: End of Example
    }
}
