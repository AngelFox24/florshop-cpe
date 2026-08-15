import Foundation

public struct TaxTotal: Equatable, Sendable {
    public let amount: MonetaryAmount
    public let subtotals: [TaxSubtotal]

    init(amount: MonetaryAmount, subtotals: [TaxSubtotal]) {
        self.amount = amount
        self.subtotals = subtotals
    }
}

public struct TaxSubtotal: Equatable, Sendable {
    public let taxableAmount: MonetaryAmount
    public let taxAmount: MonetaryAmount
    public let scheme: TaxScheme

    init(taxableAmount: MonetaryAmount, taxAmount: MonetaryAmount, scheme: TaxScheme) {
        self.taxableAmount = taxableAmount
        self.taxAmount = taxAmount
        self.scheme = scheme
    }
}

/// Impuestos aplicables a una línea de comprobante.
/// Incluye la afectación y tasa que no se requieren en el resumen global.
public struct LineTaxTotal: Equatable, Sendable {
    public let amount: MonetaryAmount
    public let subtotals: [LineTaxSubtotal]

    init(amount: MonetaryAmount, subtotals: [LineTaxSubtotal]) {
        self.amount = amount
        self.subtotals = subtotals
    }
}

public struct LineTaxSubtotal: Equatable, Sendable {
    public let taxableAmount: MonetaryAmount
    public let taxAmount: MonetaryAmount
    public let category: TaxCategory

    init(taxableAmount: MonetaryAmount, taxAmount: MonetaryAmount, category: TaxCategory) {
        self.taxableAmount = taxableAmount
        self.taxAmount = taxAmount
        self.category = category
    }
}

public struct TaxCategory: Codable, Equatable, Sendable {
    public let percent: Decimal?
    public let exemptionReasonCode: TaxExemptionReasonCode?
    public let scheme: TaxScheme

    init(
        percent: Decimal? = nil,
        exemptionReasonCode: TaxExemptionReasonCode? = nil,
        scheme: TaxScheme
    ) {
        self.percent = percent
        self.exemptionReasonCode = exemptionReasonCode
        self.scheme = scheme
    }
}

/// Tratamiento tributario comercial de una línea.
///
/// La librería deriva de este valor la categoría, el código de afectación y el
/// esquema tributario exigidos por SUNAT.
public enum TaxTreatment: Codable, Equatable, Sendable {
    case taxed(rate: Decimal)
    case exempt
    case unaffected
    case free
    case export

    var category: TaxCategory {
        switch self {
        case let .taxed(rate):
            TaxCategory(
                percent: rate,
                exemptionReasonCode: .gravadoOperacionOnerosa,
                scheme: .igv
            )
        case .exempt:
            TaxCategory(
                percent: 0,
                exemptionReasonCode: .exonerado,
                scheme: .exonerado
            )
        case .unaffected:
            TaxCategory(
                percent: 0,
                exemptionReasonCode: .inafecto,
                scheme: .inafecto
            )
        case .free:
            TaxCategory(
                percent: 18,
                exemptionReasonCode: .inafectoRetiroPorBonificacion,
                scheme: .gratuito
            )
        case .export:
            TaxCategory(
                percent: 0,
                exemptionReasonCode: .exportacion,
                scheme: .exportacion
            )
        }
    }
}

/// Indica si el precio de una operación gravada incluye el impuesto.
public enum TaxedPriceBasis: String, Codable, Equatable, Sendable {
    case includingTaxes
    case excludingTaxes
}

/// Precio comercial completo de una línea.
///
/// Sus únicas formas de construcción representan combinaciones tributarias
/// válidas. El importe de entrada se conserva como `Decimal`.
public struct LinePricing: Equatable, Sendable {
    public let amount: Decimal
    public let taxTreatment: TaxTreatment
    public let taxedPriceBasis: TaxedPriceBasis?

    private init(
        amount: Decimal,
        taxTreatment: TaxTreatment,
        taxedPriceBasis: TaxedPriceBasis?
    ) {
        self.amount = amount
        self.taxTreatment = taxTreatment
        self.taxedPriceBasis = taxedPriceBasis
    }

    public static func taxed(
        _ price: Decimal,
        rate: Decimal = 18,
        basis: TaxedPriceBasis = .includingTaxes
    ) -> LinePricing {
        LinePricing(
            amount: price,
            taxTreatment: .taxed(rate: rate),
            taxedPriceBasis: basis
        )
    }

    public static func exempt(_ price: Decimal) -> LinePricing {
        LinePricing(amount: price, taxTreatment: .exempt, taxedPriceBasis: nil)
    }

    public static func unaffected(_ price: Decimal) -> LinePricing {
        LinePricing(amount: price, taxTreatment: .unaffected, taxedPriceBasis: nil)
    }

    public static func export(_ price: Decimal) -> LinePricing {
        LinePricing(amount: price, taxTreatment: .export, taxedPriceBasis: nil)
    }

    public static func free(referenceValue: Decimal) -> LinePricing {
        LinePricing(amount: referenceValue, taxTreatment: .free, taxedPriceBasis: nil)
    }

    var isReferenceValue: Bool {
        taxTreatment == .free
    }
}

public enum TaxExemptionReasonCode: String, Codable, Sendable {
    case gravadoOperacionOnerosa = "10"
    case exonerado = "20"
    case inafecto = "30"
    case inafectoRetiroPorBonificacion = "31"
    case exportacion = "40"
}

public struct TaxScheme: Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let typeCode: String

    public init(identifier: String, name: String, typeCode: String) {
        self.identifier = identifier
        self.name = name
        self.typeCode = typeCode
    }

    public static let igv = TaxScheme(identifier: "1000", name: "IGV", typeCode: "VAT")
    public static let exportacion = TaxScheme(identifier: "9995", name: "EXP", typeCode: "FRE")
    public static let exonerado = TaxScheme(identifier: "9997", name: "EXO", typeCode: "FRE")
    public static let inafecto = TaxScheme(identifier: "9998", name: "INAFECTO", typeCode: "FRE")
    public static let gratuito = TaxScheme(identifier: "9996", name: "GRA", typeCode: "FRE")
}
