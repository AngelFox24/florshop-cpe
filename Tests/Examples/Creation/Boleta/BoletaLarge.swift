import Foundation
import FlorShopCPE

struct BoletaLargeExample {
    static func getBoletaLarge(serie: String? = nil, correlative: String? = nil) throws -> Boleta {
        let dateTime = try currentLimaExampleDateTime()
        let series = serie ?? "BC01"
        let correlative = correlative ?? String(timestampBasedNumber(from: dateTime.instant, modulo: 99_999_999))
        // MARK: Example of Boleta
        return Boleta(
            identifier: DocumentIdentifier(series: series, number: correlative),
            issueDate: IssueDate(year: dateTime.issueDate.year, month: dateTime.issueDate.month, day: dateTime.issueDate.day),
            issueTime: IssueTime(hour: dateTime.issueTime.hour, minute: dateTime.issueTime.minute, second: dateTime.issueTime.second),    // Por defecto: nil
            currency: .pen,
            supplier: Supplier(
                taxIdentifier: PartyIdentifier(
                    value: "10708255195",
                    documentType: .ruc
                ),
                commercialName: "Electrodomésticos Cruz de Motupe", // Por defecto: nil
                legalName: "Vega Poblete Carlos Enrique",
                address: Address(                              // Por defecto: nil
                    ubigeoCode: "150130",                     // Por defecto: nil
                    addressTypeCode: "0000",                  // Por defecto: nil; lo proporciona el POS
                    urbanization: "URB. SAN BORJA",           // Por defecto: nil
                    city: "LIMA",                             // Por defecto: nil
                    department: "LIMA",                       // Por defecto: nil
                    district: "SAN BORJA",                    // Por defecto: nil
                    line: "CAL. PABLO USANDIZAGA 670",
                    countryCode: "PE"                         // Por defecto: "PE"
                ),
                contact: Contact(                              // Por defecto: nil
                    telephone: "+51 999 999 999",             // Por defecto: nil
                    email: "ventas@ejemplo.pe"                // Por defecto: nil
                )
            ),
            customer: Customer(
                identifier: PartyIdentifier(
                    value: "46237547",
                    documentType: .dni
                ),
                legalName: "Pazos Atoche Luana Karina",
                address: Address(                              // Por defecto: nil
                    ubigeoCode: "150122",                     // Por defecto: nil
                    addressTypeCode: "0000",                  // Por defecto: nil
                    urbanization: "URB. MIRAFLORES",          // Por defecto: nil
                    city: "LIMA",                             // Por defecto: nil
                    department: "LIMA",                       // Por defecto: nil
                    district: "MIRAFLORES",                   // Por defecto: nil
                    line: "CAL. AUGUSTO ANGULO 130",
                    countryCode: "PE"                         // Por defecto: "PE"
                )
            ),
            lines: [
                InvoiceLine(
                    quantity: .units(1),
                    pricing: .taxed(
                        998.00,
                        rate: 18,                              // Por defecto: 18
                        basis: .includingTaxes                 // Por defecto: .includingTaxes
                    ),
                    item: Item(
                        description: "Refrigeradora marca AXM no frost de 200 ltrs.",
                        sellerItemIdentifier: "REF564",       // Por defecto: nil
                        commodityClassificationCode: "52141501" // Por defecto: nil
                    )
                ),
                InvoiceLine(
                    quantity: .kilograms(34.521234),
                    pricing: .taxed(
                        2.50,
                        rate: 18,                              // Por defecto: 18
                        basis: .excludingTaxes
                    ),
                    item: Item(
                        description: "Café tostado vendido por kilogramo",
                        sellerItemIdentifier: "CAF-KG",       // Por defecto: nil
                        commodityClassificationCode: nil       // Por defecto: nil
                    )
                ),
                InvoiceLine(
                    quantity: .grams(250.125),
                    pricing: .exempt(0.08),
                    item: Item(
                        description: "Producto exonerado vendido por gramos",
                        sellerItemIdentifier: nil,             // Por defecto: nil
                        commodityClassificationCode: nil       // Por defecto: nil
                    )
                ),
                InvoiceLine(
                    quantity: .liters(1.75),
                    pricing: .unaffected(12.40),
                    item: Item(
                        description: "Producto inafecto vendido por litros",
                        sellerItemIdentifier: "INA-LT",       // Por defecto: nil
                        commodityClassificationCode: nil       // Por defecto: nil
                    )
                ),
                InvoiceLine(
                    quantity: .meters(2.345678),
                    pricing: .free(referenceValue: 4.80),
                    item: Item(
                        description: "Muestra gratuita entregada por metros",
                        sellerItemIdentifier: nil,             // Por defecto: nil
                        commodityClassificationCode: nil       // Por defecto: nil
                    )
                ),
                InvoiceLine(
                    quantity: .serviceUnits(1.5),
                    pricing: .taxed(59.00),                    // Por defecto: rate 18 y .includingTaxes
                    item: Item(
                        description: "Servicio cobrado por unidad de servicio",
                        sellerItemIdentifier: "SRV-001",      // Por defecto: nil
                        commodityClassificationCode: nil       // Por defecto: nil
                    )
                )
            ],
            payableRoundingAmount: nil,                         // Por defecto: nil
            additionalNotes: []                                // Por defecto: []
        )
        // MARK: End of Example
    }
}
