import FlorShopCPE

struct ResumenDiarioSmallExample {
    static func getResumenDiarioSmall(sequence: Int? = nil) throws -> ResumenDiarioBoletas {
        let boleta = try BoletaSmallExample.getBoletaSmall()
        let generationDate = try currentLimaExampleDateTime().issueDate

        // MARK: Example of Resumen Diario
        return try ResumenDiarioBoletas(
            sequence: sequence ?? defaultResumenDiarioExampleSequence(),
            issueDate: generationDate,
            entries: [.boleta(boleta)]
        )
        // MARK: End of Example
    }
}
