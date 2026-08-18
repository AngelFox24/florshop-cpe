import Foundation
import FlorShopCPE

struct FacturaLargeExample {
    static func getFacturaLarge(serie: String? = nil, correlative: String? = nil) throws -> Factura {
        let dateTime = try currentLimaExampleDateTime()
        let installmentDueDate = try limaExampleIssueDate(addingDays: 15, to: dateTime.instant)

        // MARK: Example of Factura
        return Factura(
            identifier: DocumentIdentifier(
                series: serie ?? "F001",
                number: correlative ?? String(max(1, Int(dateTime.instant.timeIntervalSince1970) % 99_999_999))
            ),
            issueDate: IssueDate(year: dateTime.issueDate.year, month: dateTime.issueDate.month, day: dateTime.issueDate.day),
            issueTime: IssueTime(hour: dateTime.issueTime.hour, minute: dateTime.issueTime.minute, second: dateTime.issueTime.second),    // Por defecto: nil
            currency: .pen,
            supplier: Supplier(
                taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
                commercialName: "NKR PRODUCTS",               // Por defecto: nil
                legalName: "NKR PROFESSIONAL PRODUCTS S.A.C.",
                address: Address(                              // Por defecto: nil
                    ubigeoCode: "150130",                     // Por defecto: nil
                    addressTypeCode: "0000",                  // Por defecto: nil
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
                identifier: PartyIdentifier(value: "20109072177", documentType: .ruc),
                legalName: "CENCOSUD RETAIL PERU S.A.",
                address: Address(                              // Por defecto: nil
                    ubigeoCode: "150103",                     // Por defecto: nil
                    addressTypeCode: "0000",                  // Por defecto: nil
                    urbanization: "URB. ATE",                 // Por defecto: nil
                    city: "LIMA",                             // Por defecto: nil
                    department: "LIMA",                       // Por defecto: nil
                    district: "ATE",                          // Por defecto: nil
                    line: "AV. NICOLAS AYLLON 4297",
                    countryCode: "PE"                         // Por defecto: "PE"
                )
            ),
            lines: [
                InvoiceLine(
                    quantity: .units(15),
                    pricing: .taxed(75.07, rate: 18, basis: .excludingTaxes), // Por defecto: rate 18
                    item: Item(
                        description: "COLA ENTOMOLÓGICA K-GLUE X 1 LT",
                        sellerItemIdentifier: "KGLUE-1L",     // Por defecto: nil
                        commodityClassificationCode: "12161902" // Por defecto: nil
                    )
                ),
                InvoiceLine(
                    quantity: .kilograms(34.521234),
                    pricing: .taxed(
                        2.95,
                        rate: 18,                              // Por defecto: 18
                        basis: .includingTaxes                 // Por defecto: .includingTaxes
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
            additionalNotes: [DocumentNote("ORDEN DE COMPRA 4301113494")], // Por defecto: []
            orderReference: "4301113494",                    // Por defecto: nil
            despatchDocumentReferences: [                     // Por defecto: []
                DocumentReference(
                    identifier: "EG07-00000280",
                    documentTypeCode: "09",
                    documentTypeDescription: "GUIA DE REMISION REMITENTE" // Por defecto: nil
                )
            ],
            buyerAddress: Address(                            // Por defecto: nil
                ubigeoCode: "150122",                       // Por defecto: nil
                addressTypeCode: "0000",                    // Por defecto: nil
                urbanization: "URB. MIRAFLORES",            // Por defecto: nil
                city: "LIMA",                               // Por defecto: nil
                department: "LIMA",                         // Por defecto: nil
                district: "MIRAFLORES",                     // Por defecto: nil
                line: "CAL. AUGUSTO ANGULO 130",
                countryCode: "PE"                           // Por defecto: "PE"
            ),
            paymentCondition: .credit(
                installments: [
                    PaymentInstallment(
                        amount: MonetaryAmount(value: 1560.78),
                        dueDate: installmentDueDate
                    )
                ]
            ),
            allowanceCharges: [],                            // Por defecto: []
            payableRoundingAmount: nil                       // Por defecto: nil
        )
        // MARK: End of Example
    }
}
