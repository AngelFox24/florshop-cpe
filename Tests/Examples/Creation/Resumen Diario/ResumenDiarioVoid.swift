import FlorShopCPE

/// Este caso no forma parte de `ResumenDiarioLarge` porque un comprobante no
/// puede aparecer repetido con condiciones `.add` y `.void` en el mismo resumen.
struct ResumenDiarioVoidExample {
    static func getResumenDiarioVoid(sequence: Int? = nil) throws -> ResumenDiarioBoletas {
        let boleta = try BoletaSmallExample.getBoletaSmall()
        let generationDate = try currentLimaExampleDateTime().issueDate

        // MARK: Example of Resumen Diario Void
        return try ResumenDiarioBoletas(
            sequence: sequence ?? defaultResumenDiarioExampleSequence(),
            issueDate: generationDate,
            entries: [.boleta(boleta, condition: .void)]
        )
        // MARK: End of Example
    }
}
