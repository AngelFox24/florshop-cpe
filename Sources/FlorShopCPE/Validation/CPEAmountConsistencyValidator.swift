import Foundation

/// Inconsistencias detectadas después de aplicar la precisión oficial de cada
/// clase de número. Las comparaciones nunca dependen del formato textual XML.
enum CPEAmountConsistencyValidationError: Error, Equatable, Sendable {
    case lineExtensionAmountMismatch(String)
    case lineTaxTotalMismatch(String)
    case documentTaxTotalMismatch
    case payableAmountMismatch
    case dailySummaryTotalMismatch(Int)
}

/// Comprueba internamente que el motor de cálculo y el documento que será
/// serializado conservan exactamente los mismos importes normalizados.
struct CPEAmountConsistencyValidator: Sendable {
    init() {}

    func validate(_ document: any UBLInvoiceDocument) throws {
        for line in document.lines {
            try validateLine(
                id: line.id,
                quantity: line.quantity,
                pricing: line.pricing,
                lineExtensionAmount: line.lineExtensionAmount,
                price: line.price,
                taxTotal: line.taxTotal,
                isFree: line.isFreeOfCharge == true || isFree(line.taxTotal)
            )
        }
        try validateTaxTotal(document.taxTotal, lineTaxes: document.lines.map(\.taxTotal))

        let total = document.monetaryTotal
        try validatePayable(
            taxInclusive: total.taxInclusiveAmount,
            allowance: nil,
            charge: nil,
            prepaid: total.prepaidAmount,
            rounding: total.payableRoundingAmount,
            payable: total.payableAmount
        )
    }

    func validate(_ note: NotaCredito) throws {
        for line in note.lines {
            try validateLine(
                id: line.id,
                quantity: line.quantity,
                pricing: line.pricing,
                lineExtensionAmount: line.lineExtensionAmount,
                price: line.price,
                taxTotal: line.taxTotal,
                isFree: isFree(line.taxTotal)
            )
        }
        try validateTaxTotal(note.taxTotal, lineTaxes: note.lines.map(\.taxTotal))

        let lineAndTaxTotal = normalizedSum(
            note.lines
                .filter { $0.taxTreatment != .free }
                .map(\.lineExtensionAmount)
        )
            + CPEPrecision.monetary(note.taxTotal.amount.value)
        let total = note.monetaryTotal
        try validatePayable(
            taxInclusiveValue: CPEPrecision.monetary(lineAndTaxTotal),
            allowance: total.allowanceTotalAmount,
            charge: total.chargeTotalAmount,
            prepaid: total.prepaidAmount,
            rounding: total.payableRoundingAmount,
            payable: total.payableAmount
        )
    }

    func validate(_ note: NotaDebito) throws {
        for line in note.lines {
            if let quantity = line.quantity, let price = line.price {
                try validateLine(
                    id: line.id,
                    quantity: quantity,
                    pricing: line.pricing,
                    lineExtensionAmount: line.lineExtensionAmount,
                    price: price,
                    taxTotal: line.taxTotal,
                    isFree: isFree(line.taxTotal)
                )
            } else {
                try validateLineTaxTotal(id: line.id, taxTotal: line.taxTotal)
            }
        }
        try validateTaxTotal(note.taxTotal, lineTaxes: note.lines.map(\.taxTotal))

        let lineAndTaxTotal = normalizedSum(
            note.lines
                .filter { $0.taxTreatment != .free }
                .map(\.lineExtensionAmount)
        )
            + CPEPrecision.monetary(note.taxTotal.amount.value)
        let total = note.monetaryTotal
        try validatePayable(
            taxInclusiveValue: CPEPrecision.monetary(lineAndTaxTotal),
            allowance: nil,
            charge: total.chargeTotalAmount,
            prepaid: nil,
            rounding: total.payableRoundingAmount,
            payable: total.payableAmount
        )
    }

    func validate(_ summary: ResumenDiarioBoletas) throws {
        for line in summary.lines {
            let ordinarySales = line.sales
                .filter { !Self.freeSaleTypes.contains($0.type) }
                .map(\.amount)
            let expected = normalizedSum(ordinarySales)
                + normalizedSum(line.taxes.map(\.amount))
                + normalized(line.chargeTotalAmount)
            guard CPEPrecision.monetary(expected) == CPEPrecision.monetary(line.totalAmount.value) else {
                throw CPEAmountConsistencyValidationError.dailySummaryTotalMismatch(line.lineID)
            }
        }
    }

    private func validateLine(
        id: String,
        quantity: Quantity,
        pricing: LinePricing,
        lineExtensionAmount: MonetaryAmount,
        price: MonetaryAmount,
        taxTotal: LineTaxTotal,
        isFree: Bool
    ) throws {
        let expected = CPEPrecision.lineAmount(
            unitPrice: isFree ? pricing.amount : price.value,
            quantity: quantity.value
        )
        guard expected == CPEPrecision.monetary(lineExtensionAmount.value) else {
            throw CPEAmountConsistencyValidationError.lineExtensionAmountMismatch(id)
        }
        try validateLineTaxTotal(id: id, taxTotal: taxTotal)
    }

    private func validateLineTaxTotal(id: String, taxTotal: LineTaxTotal) throws {
        let expected = normalizedSum(taxTotal.subtotals.map(\.taxAmount))
        guard expected == CPEPrecision.monetary(taxTotal.amount.value) else {
            throw CPEAmountConsistencyValidationError.lineTaxTotalMismatch(id)
        }
    }

    private func validateTaxTotal(_ taxTotal: TaxTotal, lineTaxes: [LineTaxTotal]) throws {
        let subtotalSum = normalizedSum(taxTotal.subtotals.map(\.taxAmount))
        let lineSum = normalizedSum(lineTaxes.map(\.amount))
        let declared = CPEPrecision.monetary(taxTotal.amount.value)
        guard declared == subtotalSum, declared == lineSum else {
            throw CPEAmountConsistencyValidationError.documentTaxTotalMismatch
        }
    }

    private func validatePayable(
        taxInclusive: MonetaryAmount,
        allowance: MonetaryAmount?,
        charge: MonetaryAmount?,
        prepaid: MonetaryAmount?,
        rounding: MonetaryAmount?,
        payable: MonetaryAmount
    ) throws {
        try validatePayable(
            taxInclusiveValue: CPEPrecision.monetary(taxInclusive.value),
            allowance: allowance,
            charge: charge,
            prepaid: prepaid,
            rounding: rounding,
            payable: payable
        )
    }

    private func validatePayable(
        taxInclusiveValue: Decimal,
        allowance: MonetaryAmount?,
        charge: MonetaryAmount?,
        prepaid: MonetaryAmount?,
        rounding: MonetaryAmount?,
        payable: MonetaryAmount
    ) throws {
        let expected = CPEPrecision.monetary(
            taxInclusiveValue
                - normalized(allowance)
                + normalized(charge)
                - normalized(prepaid)
                + normalized(rounding)
        )
        guard expected == CPEPrecision.monetary(payable.value) else {
            throw CPEAmountConsistencyValidationError.payableAmountMismatch
        }
    }

    private func normalizedSum(_ amounts: [MonetaryAmount]) -> Decimal {
        CPEPrecision.monetarySum(amounts.lazy.map(\.value))
    }

    private func normalized(_ amount: MonetaryAmount?) -> Decimal {
        amount.map { CPEPrecision.monetary($0.value) } ?? .zero
    }

    private func isFree(_ taxTotal: LineTaxTotal) -> Bool {
        taxTotal.subtotals.contains {
            $0.category.scheme.identifier == TaxScheme.gratuito.identifier
        }
    }

    private static let freeSaleTypes: Set<DailySummarySaleType> = [
        .freeTaxable, .freeExempt, .freeUnaffected, .freeExport
    ]
}
