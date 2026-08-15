import Foundation

/// Motor contable único para todos los CPE soportados por la librería.
enum CPECalculation {
    struct CalculatedLine {
        let lineExtensionAmount: MonetaryAmount
        let alternativePrices: [AlternativePrice]
        let taxTotal: LineTaxTotal
        let price: MonetaryAmount
        let isFreeOfCharge: Bool
    }

    static func line(
        quantity: Decimal,
        pricing: LinePricing
    ) -> CalculatedLine {
        let commercialValue = pricing.amount
        let taxCategory = pricing.taxTreatment.category
        let isReferenceValue = pricing.isReferenceValue

        let isFree = isReferenceValue
        let rate = taxCategory.percent ?? .zero
        let appliesTax = taxCategory.scheme.identifier == TaxScheme.igv.identifier && rate != 0

        let netUnitPrice: Decimal
        let alternativePrice: AlternativePrice
        if isFree {
            netUnitPrice = .zero
            alternativePrice = AlternativePrice(
                amount: MonetaryAmount(value: CPEPrecision.unitValue(commercialValue)),
                type: .referenceValue
            )
        } else {
            switch pricing.taxedPriceBasis ?? .excludingTaxes {
            case .includingTaxes:
                let value = pricing.amount
                netUnitPrice = appliesTax
                    ? CPEPrecision.unitValue(value / (1 + rate / 100))
                    : value
                alternativePrice = AlternativePrice(
                    amount: MonetaryAmount(value: CPEPrecision.unitValue(value)),
                    type: .unitPriceIncludingTaxes
                )
            case .excludingTaxes:
                let value = pricing.amount
                netUnitPrice = value
                let gross = appliesTax ? value * (1 + rate / 100) : value
                alternativePrice = AlternativePrice(
                    amount: MonetaryAmount(value: CPEPrecision.unitValue(gross)),
                    type: .unitPriceIncludingTaxes
                )
            }
        }

        let taxableValue = CPEPrecision.monetary(
            (isFree ? commercialValue : netUnitPrice) * quantity
        )
        // SUNAT define LineExtensionAmount como el valor de venta del ítem.
        // En operaciones gratuitas es el valor referencial total, aunque no
        // forme parte del importe que el cliente debe pagar.
        let lineExtension = taxableValue
        let taxAmount = appliesTax && !isFree
            ? CPEPrecision.monetary(taxableValue * rate / 100)
            : .zero
        let subtotal = LineTaxSubtotal(
            taxableAmount: MonetaryAmount(value: taxableValue),
            taxAmount: MonetaryAmount(value: taxAmount),
            category: taxCategory
        )

        return CalculatedLine(
            lineExtensionAmount: MonetaryAmount(value: lineExtension),
            alternativePrices: [alternativePrice],
            taxTotal: LineTaxTotal(
                amount: MonetaryAmount(value: taxAmount),
                subtotals: [subtotal]
            ),
            price: MonetaryAmount(value: isFree ? .zero : CPEPrecision.unitValue(netUnitPrice)),
            isFreeOfCharge: isFree
        )
    }

    static func taxTotal<Line>(
        from lines: [Line],
        taxTotal: (Line) -> LineTaxTotal
    ) -> TaxTotal {
        var order: [String] = []
        var schemes: [String: TaxScheme] = [:]
        var taxable: [String: [Decimal]] = [:]
        var taxes: [String: [Decimal]] = [:]

        for line in lines {
            for subtotal in taxTotal(line).subtotals {
                let key = subtotal.category.scheme.identifier
                if schemes[key] == nil { order.append(key) }
                schemes[key] = subtotal.category.scheme
                taxable[key, default: []].append(subtotal.taxableAmount.value)
                taxes[key, default: []].append(subtotal.taxAmount.value)
            }
        }

        let subtotals = order.compactMap { key -> TaxSubtotal? in
            guard let scheme = schemes[key] else { return nil }
            return TaxSubtotal(
                taxableAmount: MonetaryAmount(value: CPEPrecision.monetarySum(taxable[key] ?? [])),
                taxAmount: MonetaryAmount(value: CPEPrecision.monetarySum(taxes[key] ?? [])),
                scheme: scheme
            )
        }
        return TaxTotal(
            amount: MonetaryAmount(value: CPEPrecision.monetarySum(subtotals.map(\.taxAmount.value))),
            subtotals: subtotals
        )
    }

    static func monetaryTotal(
        lineAmounts: [MonetaryAmount],
        taxTotal: TaxTotal,
        allowanceCharges: [AllowanceCharge] = [],
        prepaidAmount: MonetaryAmount? = nil,
        payableRoundingAmount: MonetaryAmount? = nil
    ) -> MonetaryTotal {
        let lineExtension = CPEPrecision.monetarySum(lineAmounts.map(\.value))
        let allowances = CPEPrecision.monetarySum(
            allowanceCharges.filter { !$0.isCharge }.map(\.amount.value)
        )
        let charges = CPEPrecision.monetarySum(
            allowanceCharges.filter(\.isCharge).map(\.amount.value)
        )
        let prepaid = prepaidAmount?.normalized.value ?? .zero
        let rounding = payableRoundingAmount?.normalized.value ?? .zero
        let taxInclusive = CPEPrecision.monetary(
            lineExtension - allowances + charges + taxTotal.amount.value
        )
        let payable = CPEPrecision.monetary(taxInclusive - prepaid + rounding)

        return MonetaryTotal(
            lineExtensionAmount: MonetaryAmount(value: lineExtension),
            taxInclusiveAmount: MonetaryAmount(value: taxInclusive),
            allowanceTotalAmount: allowances == 0 ? nil : MonetaryAmount(value: allowances),
            chargeTotalAmount: charges == 0 ? nil : MonetaryAmount(value: charges),
            prepaidAmount: prepaid == 0 ? nil : MonetaryAmount(value: prepaid),
            payableRoundingAmount: rounding == 0 ? nil : MonetaryAmount(value: rounding),
            payableAmount: MonetaryAmount(value: payable)
        )
    }
}
