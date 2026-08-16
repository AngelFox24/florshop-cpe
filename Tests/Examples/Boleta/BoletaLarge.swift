import Foundation
import Testing
import FlorShopCPE

/// Ejemplo ejecutable del flujo completo de una boleta contra SUNAT beta.
///
/// No es una prueba unitaria: está dentro del target de tests para que Xcode
/// pueda compilarlo y ejecutarlo sin crear una aplicación adicional. Solo se
/// conecta a SUNAT cuando `FLORSHOP_CPE_RUN_BOLETA_EXAMPLE=true`.
@Test func completeBoletaLifecycleExample() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["FLORSHOP_CPE_RUN_BOLETA_EXAMPLE"] == "true" else {
        return
    }

    var limaCalendar = Calendar(identifier: .gregorian)
    limaCalendar.timeZone = try #require(TimeZone(identifier: "America/Lima"))
    let now = Date()
    let dateComponents = limaCalendar.dateComponents(
        [.year, .month, .day, .hour, .minute, .second],
        from: now
    )
    let issueDate = IssueDate(
        year: try #require(dateComponents.year),
        month: try #require(dateComponents.month),
        day: try #require(dateComponents.day)
    )
    let issueTime = IssueTime(
        hour: try #require(dateComponents.hour),
        minute: try #require(dateComponents.minute),
        second: try #require(dateComponents.second)             // Por defecto: 0
    )
    let correlative = String(max(1, Int(now.timeIntervalSince1970) % 99_999_999))
    let identifier = DocumentIdentifier(
        series: "BC01",
        number: correlative
    )

    let boleta = Boleta(
        identifier: identifier,
        issueDate: issueDate,
        issueTime: issueTime,                                  // Por defecto: nil
        currency: .pen,
        supplier: Supplier(
            taxIdentifier: PartyIdentifier(
                value: "10708255195",
                documentType: .ruc
            ),
            commercialName: "Electrodomésticos Cruz de Motupe", // Por defecto: nil
            legalName: "Vega Poblete Carlos Enrique",
            address: Address(                                  // Por defecto: nil
                ubigeoCode: "150130",                         // Por defecto: nil
                addressTypeCode: "0000",                      // Por defecto: nil; lo proporciona el POS
                urbanization: "URB. SAN BORJA",               // Por defecto: nil
                city: "LIMA",                                 // Por defecto: nil
                department: "LIMA",                           // Por defecto: nil
                district: "SAN BORJA",                        // Por defecto: nil
                line: "CAL. PABLO USANDIZAGA 670",
                countryCode: "PE"                             // Por defecto: "PE"
            ),
            contact: Contact(                                  // Por defecto: nil
                telephone: "+51 999 999 999",                 // Por defecto: nil
                email: "ventas@ejemplo.pe"                    // Por defecto: nil
            )
        ),
        customer: Customer(
            identifier: PartyIdentifier(
                value: "46237547",
                documentType: .dni
            ),
            legalName: "Pazos Atoche Luana Karina",
            address: Address(                                  // Por defecto: nil
                ubigeoCode: "150122",                         // Por defecto: nil
                addressTypeCode: "0000",                      // Por defecto: nil
                urbanization: "URB. MIRAFLORES",              // Por defecto: nil
                city: "LIMA",                                 // Por defecto: nil
                department: "LIMA",                           // Por defecto: nil
                district: "MIRAFLORES",                       // Por defecto: nil
                line: "CAL. AUGUSTO ANGULO 130",
                countryCode: "PE"                             // Por defecto: "PE"
            )
        ),
        lines: [
            // Precio gravado que incluye IGV. Se escriben también los valores
            // predeterminados para que la forma completa de la API sea visible.
            InvoiceLine(
                id: "1",
                quantity: .units(1),
                pricing: .taxed(
                    998.00,
                    rate: 18,                                  // Por defecto: 18
                    basis: .includingTaxes                     // Por defecto: .includingTaxes
                ),
                item: Item(
                    description: "Refrigeradora marca AXM no frost de 200 ltrs.",
                    sellerItemIdentifier: "REF564",             // Por defecto: nil
                    commodityClassificationCode: "52141501"     // Por defecto: nil
                )
            ),
            // Cantidad fraccionaria de kilogramos y precio gravado sin IGV.
            InvoiceLine(
                id: "2",
                quantity: .kilograms(34.521234),
                pricing: .taxed(
                    2.50,
                    rate: 18,                                  // Por defecto: 18
                    basis: .excludingTaxes
                ),
                item: Item(
                    description: "Café tostado vendido por kilogramo",
                    sellerItemIdentifier: "CAF-KG",            // Por defecto: nil
                    commodityClassificationCode: nil            // Por defecto: nil
                )
            ),
            // Operación exonerada, expresada en gramos con decimales.
            InvoiceLine(
                id: "3",
                quantity: .grams(250.125),
                pricing: .exempt(0.08),
                item: Item(
                    description: "Producto exonerado vendido por gramos",
                    sellerItemIdentifier: nil,                  // Por defecto: nil
                    commodityClassificationCode: nil            // Por defecto: nil
                )
            ),
            // Operación inafecta medida en litros.
            InvoiceLine(
                id: "4",
                quantity: .liters(1.75),
                pricing: .unaffected(12.40),
                item: Item(
                    description: "Producto inafecto vendido por litros",
                    sellerItemIdentifier: "INA-LT",            // Por defecto: nil
                    commodityClassificationCode: nil            // Por defecto: nil
                )
            ),
            // Entrega gratuita: el importe es un valor referencial y no se cobra.
            InvoiceLine(
                id: "5",
                quantity: .meters(2.345678),
                pricing: .free(referenceValue: 4.80),
                item: Item(
                    description: "Muestra gratuita entregada por metros",
                    sellerItemIdentifier: nil,                  // Por defecto: nil
                    commodityClassificationCode: nil            // Por defecto: nil
                )
            ),
            // La forma corta usa ambos valores predeterminados de `.taxed`:
            // tasa 18 y precio que incluye impuestos.
            InvoiceLine(
                id: "6",
                quantity: .serviceUnits(1.5),
                pricing: .taxed(59.00),                         // Por defecto: rate 18 y .includingTaxes
                item: Item(
                    description: "Servicio cobrado por unidad de servicio",
                    sellerItemIdentifier: "SRV-001",           // Por defecto: nil
                    commodityClassificationCode: nil            // Por defecto: nil
                )
            )
        ],
        payableRoundingAmount: nil,                             // Por defecto: nil
        additionalNotes: []                                    // Por defecto: []
    )

    // Todos los importes derivados están disponibles antes de firmar.
    #expect(boleta.netAmount == 1048.77)
    #expect(boleta.taxAmount == 181.27)
    #expect(boleta.totalAmount == 1230.04)
    #expect(boleta.lines[1].lineExtensionAmount.value == 86.30)
    #expect(boleta.lines[4].isFreeOfCharge == true)
    #expect(boleta.lines[4].lineExtensionAmount.value == 11.26)

    // La API también representa exportaciones. No se agrega esta línea a la
    // boleta enviada porque una exportación real requiere un contexto comercial
    // y un tipo de operación distintos de esta venta local de demostración.
    let exportLineExample = InvoiceLine(
        id: "EXPORT-1",
        quantity: .units(2),
        pricing: .export(30.00),
        item: Item(
            description: "Ejemplo de producto destinado a exportación",
            sellerItemIdentifier: nil,                         // Por defecto: nil
            commodityClassificationCode: nil                   // Por defecto: nil
        )
    )
    #expect(exportLineExample.taxTreatment == .export)
    #expect(exportLineExample.lineExtensionAmount.value == 60.00)
    //MARK: SING
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
    #expect(try XMLSecSignatureVerifier().verify(signedBoleta.xml))

    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("FlorShopCPE-BoletaExample-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer {
        try? fileManager.removeItem(at: temporaryDirectory)
    }
    //MARK: ZIP
    let document = try CPEDocumentWriter().write(
        signedBoleta,
        output: CPEOutputConfiguration(rootDirectory: temporaryDirectory)
    )
    let signedXMLReadFromDisk = try Data(contentsOf: document.signedXMLURL)
    let zipReadFromDisk = try Data(contentsOf: document.zipURL)

    print("""

    ===== BOLETA FIRMADA Y EMPAQUETADA =====
    XML: \(document.signedXMLURL.path)
    ZIP: \(document.zipURL.path)
    Tamaño ZIP: \(zipReadFromDisk.count) bytes
    \(String(decoding: signedXMLReadFromDisk, as: UTF8.self))
    ===== FIN BOLETA FIRMADA Y EMPAQUETADA =====

    """)

    let result = try await SunatBillClient().submit(
        document: document,
        credentials: .beta(emitterRUC: boleta.supplier.taxIdentifier.value)
    )
    let cdrArtifacts = try #require(result.cdrArtifacts)
    let cdrXMLReadFromDisk = try Data(contentsOf: cdrArtifacts.xmlURL)

    print("""

    ===== RESPUESTA SUNAT BETA =====
    Estado: \(result.status)
    Código: \(result.responseCode)
    Descripciones: \(result.descriptions)
    Observaciones: \(result.observations)
    CDR ZIP: \(cdrArtifacts.archiveURL.path)
    CDR XML: \(cdrArtifacts.xmlURL.path)
    \(String(decoding: cdrXMLReadFromDisk, as: UTF8.self))
    ===== FIN RESPUESTA SUNAT BETA =====

    """)

    #expect(result.status == .accepted)
    #expect(result.responseCode == "0")
    #expect(result.observations.isEmpty)
    #expect(!result.cdrArchive.isEmpty)
    #expect(!result.cdrXML.isEmpty)
}
