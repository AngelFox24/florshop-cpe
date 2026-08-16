import Foundation
import FlorShopCPE

enum BoletaExampleError: Error {
    case invalidLimaTimeZone
    case incompleteCurrentDate
}

struct BoletaLarge {
    static func getBoletaLargeExample(now: Date = Date()) throws -> Boleta {
        // MARK: Example of Boleta
        var limaCalendar = Calendar(identifier: .gregorian)
        guard let limaTimeZone = TimeZone(identifier: "America/Lima") else {
            throw BoletaExampleError.invalidLimaTimeZone
        }
        limaCalendar.timeZone = limaTimeZone

        let dateComponents = limaCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: now
        )
        guard let year = dateComponents.year,
              let month = dateComponents.month,
              let day = dateComponents.day,
              let hour = dateComponents.hour,
              let minute = dateComponents.minute,
              let second = dateComponents.second else {
            throw BoletaExampleError.incompleteCurrentDate
        }

        let issueDate = IssueDate(year: year, month: month, day: day)
        let issueTime = IssueTime(
            hour: hour,
            minute: minute,
            second: second                                      // Por defecto: 0
        )
        let correlative = String(max(1, Int(now.timeIntervalSince1970) % 99_999_999))

        return Boleta(
            identifier: DocumentIdentifier(series: "BC01", number: correlative),
            issueDate: issueDate,
            issueTime: issueTime,                              // Por defecto: nil
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
                    id: "1",
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
                    id: "2",
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
                    id: "3",
                    quantity: .grams(250.125),
                    pricing: .exempt(0.08),
                    item: Item(
                        description: "Producto exonerado vendido por gramos",
                        sellerItemIdentifier: nil,             // Por defecto: nil
                        commodityClassificationCode: nil       // Por defecto: nil
                    )
                ),
                InvoiceLine(
                    id: "4",
                    quantity: .liters(1.75),
                    pricing: .unaffected(12.40),
                    item: Item(
                        description: "Producto inafecto vendido por litros",
                        sellerItemIdentifier: "INA-LT",       // Por defecto: nil
                        commodityClassificationCode: nil       // Por defecto: nil
                    )
                ),
                InvoiceLine(
                    id: "5",
                    quantity: .meters(2.345678),
                    pricing: .free(referenceValue: 4.80),
                    item: Item(
                        description: "Muestra gratuita entregada por metros",
                        sellerItemIdentifier: nil,             // Por defecto: nil
                        commodityClassificationCode: nil       // Por defecto: nil
                    )
                ),
                InvoiceLine(
                    id: "6",
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
        // MARK: End of Example of Boleta
    }

    static func run() async throws {
        // MARK: Creacion de Boleta

        let boleta = try getBoletaLargeExample()

        // MARK: SING

        let signingConfiguration = SigningConfiguration(
            credentials: .pkcs12(
                path: URL(fileURLWithPath: "/Users/angel/Downloads/LLAMA-PE-CERTIFICADO-DEMO-1070825519.pfx"),
                passwordProvider: { "Foxangel2498." }
            )
        )
        let signedBoleta = try XMLSecCPESigner().sign(
            boleta,
            configuration: signingConfiguration
        )

        // MARK: ZIP

        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("FlorShopCPE-BoletaLarge-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }
        let document = try CPEDocumentWriter().write(
            signedBoleta,
            output: CPEOutputConfiguration(rootDirectory: temporaryDirectory)
        )
        let signedXML = try Data(contentsOf: document.signedXMLURL)
        let zip = try Data(contentsOf: document.zipURL)

        print("""

        ===== BOLETA FIRMADA Y EMPAQUETADA =====
        XML: \(document.signedXMLURL.path)
        ZIP: \(document.zipURL.path)
        Tamaño ZIP: \(zip.count) bytes
        \(String(decoding: signedXML, as: UTF8.self))
        ===== FIN BOLETA FIRMADA Y EMPAQUETADA =====

        """)

        // MARK: Envio a SUNAT

        let environment = ProcessInfo.processInfo.environment
        guard environment["FLORSHOP_CPE_RUN_BOLETA_EXAMPLE"] == "true" else {
            return
        }
        let result = try await SunatBillClient().submit(
            document: document,
            credentials: .beta(emitterRUC: boleta.supplier.taxIdentifier.value)
        )
        let cdrXML = result.cdrArtifacts.flatMap { try? Data(contentsOf: $0.xmlURL) }

        print("""

        ===== RESPUESTA SUNAT BETA =====
        Estado: \(result.status)
        Código: \(result.responseCode)
        Descripciones: \(result.descriptions)
        Observaciones: \(result.observations)
        \(cdrXML.map { String(decoding: $0, as: UTF8.self) } ?? "CDR no disponible")
        ===== FIN RESPUESTA SUNAT BETA =====

        """)
    }
}
