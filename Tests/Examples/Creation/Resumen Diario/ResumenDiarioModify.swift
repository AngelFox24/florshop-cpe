import FlorShopCPE

/// Este caso no forma parte de `ResumenDiarioLarge` porque un comprobante no
/// puede aparecer repetido con condiciones `.add` y `.modify` en el mismo resumen.
struct ResumenDiarioModifyExample {
    static func getResumenDiarioModify(sequence: Int? = nil) throws -> ResumenDiarioBoletas {
        let boleta = try BoletaSmallExample.getBoletaSmall()
        let generationDate = try currentLimaExampleDateTime().issueDate

        // MARK: Example of Resumen Diario Modify
        return try ResumenDiarioBoletas(
            sequence: sequence ?? defaultResumenDiarioExampleSequence(),
            issueDate: generationDate,
            entries: [.boleta(boleta, condition: .modify)]
        )
        // MARK: End of Example
    }
}
