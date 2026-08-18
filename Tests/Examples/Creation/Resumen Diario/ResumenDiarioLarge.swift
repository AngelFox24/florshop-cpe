import Foundation
import FlorShopCPE

struct ResumenDiarioLargeExample {
    static func getResumenDiarioLarge(series: String? = nil, sequence: Int? = nil) throws -> ResumenDiarioBoletas {
        let series = series ?? "BC01"
        let base = max(1, Int(Date().timeIntervalSince1970) % 99_999_990)
        let boleta = try BoletaLargeExample.getBoletaLarge(
            serie: series,
            correlative: String(base)
        )
        let secondBoleta = try BoletaSmallExample.getBoletaSmall(
            serie: series,
            correlative: String(base + 1)
        )
        let creditNote = try NotaCreditoLargeExample.getNotaCreditoLarge(
            serie: "BC02",
            correlative: String(base + 2),
            affectedBoleta: boleta
        )
        let debitNote = try NotaDebitoLargeExample.getNotaDebitoLarge(
            serie: "BD01",
            correlative: String(base + 3),
            affectedBoleta: boleta
        )
        let generationDate = try currentLimaExampleDateTime().issueDate

        // MARK: Example of Resumen Diario
        return try ResumenDiarioBoletas(
            sequence: sequence ?? defaultResumenDiarioExampleSequence(),
            issueDate: generationDate,
            entries: [
                .boleta(boleta, condition: .add),             // Por defecto: .add
                .boleta(secondBoleta, condition: .add),       // Por defecto: .add
                .creditNote(creditNote, condition: .add),     // Por defecto: .add
                .debitNote(debitNote, condition: .add)        // Por defecto: .add
            ]
        )
        // MARK: End of Example
    }
}

func defaultResumenDiarioExampleSequence() -> Int {
    max(1, Int(Date().timeIntervalSince1970) % 99_997)
}
