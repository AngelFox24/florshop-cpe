import Foundation

/// Política numérica común para los comprobantes electrónicos de SUNAT.
///
/// Los modelos conservan el `Decimal` recibido. La normalización se aplica en
/// los límites contables: importes a dos decimales, precios y cantidades a
/// diez, y tasas o factores a cinco. Todos los redondeos usan `.plain`.
public enum CPEPrecision {
    public static let monetaryScale = 2
    public static let unitValueScale = 10
    public static let rateScale = 5

    public static func monetary(_ value: Decimal) -> Decimal {
        rounded(value, scale: monetaryScale)
    }

    public static func unitValue(_ value: Decimal) -> Decimal {
        rounded(value, scale: unitValueScale)
    }

    public static func rate(_ value: Decimal) -> Decimal {
        rounded(value, scale: rateScale)
    }

    /// Calcula el valor monetario de una línea sin reducir previamente la
    /// precisión comercial del precio ni de la cantidad.
    public static func lineAmount(unitPrice: Decimal, quantity: Decimal) -> Decimal {
        monetary(unitPrice * quantity)
    }

    /// Suma importes ya llevados individualmente a la precisión monetaria.
    public static func monetarySum<S: Sequence>(_ values: S) -> Decimal where S.Element == Decimal {
        monetary(values.reduce(Decimal.zero) { partial, value in
            partial + monetary(value)
        })
    }

    public static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}

public struct MonetaryAmount: Codable, Equatable, Sendable {
    public let value: Decimal

    /// Importe expresado en la moneda declarada por el documento raíz.
    public init(value: Decimal) {
        self.value = value
    }

    /// Vista normalizada para campos monetarios finales de SUNAT.
    public var normalized: MonetaryAmount {
        MonetaryAmount(value: CPEPrecision.monetary(value))
    }
}

/// Cantidad comercial cuya unidad determina si admite fracciones.
///
/// Las unidades individuales reciben `Int`; las medidas continuas conservan
/// un `Decimal`. No existe un inicializador público que permita combinarlas
/// arbitrariamente.
public struct Quantity: Equatable, Sendable {
    public let value: Decimal
    public let unitCode: UnitCode

    private init(value: Decimal, unitCode: UnitCode) {
        self.value = value
        self.unitCode = unitCode
    }

    public static func units(_ count: Int) -> Quantity {
        Quantity(value: Decimal(count), unitCode: .unit)
    }

    public static func kilograms(_ value: Decimal) -> Quantity {
        Quantity(value: value, unitCode: .kilogram)
    }

    public static func grams(_ value: Decimal) -> Quantity {
        Quantity(value: value, unitCode: .gram)
    }

    public static func liters(_ value: Decimal) -> Quantity {
        Quantity(value: value, unitCode: .liter)
    }

    public static func meters(_ value: Decimal) -> Quantity {
        Quantity(value: value, unitCode: .meter)
    }

    public static func serviceUnits(_ value: Decimal) -> Quantity {
        Quantity(value: value, unitCode: .serviceUnit)
    }
}

public enum UnitCode: String, Codable, Sendable {
    case unit = "NIU"
    case kilogram = "KGM"
    case gram = "GRM"
    case liter = "LTR"
    case meter = "MTR"
    case serviceUnit = "ZZ"
}

public struct MonetaryTotal: Equatable, Sendable {
    public let lineExtensionAmount: MonetaryAmount
    public let taxInclusiveAmount: MonetaryAmount
    public let allowanceTotalAmount: MonetaryAmount?
    public let chargeTotalAmount: MonetaryAmount?
    public let prepaidAmount: MonetaryAmount?
    public let payableRoundingAmount: MonetaryAmount?
    public let payableAmount: MonetaryAmount

    init(
        lineExtensionAmount: MonetaryAmount,
        taxInclusiveAmount: MonetaryAmount,
        allowanceTotalAmount: MonetaryAmount? = nil,
        chargeTotalAmount: MonetaryAmount? = nil,
        prepaidAmount: MonetaryAmount? = nil,
        payableRoundingAmount: MonetaryAmount? = nil,
        payableAmount: MonetaryAmount
    ) {
        self.lineExtensionAmount = lineExtensionAmount
        self.taxInclusiveAmount = taxInclusiveAmount
        self.allowanceTotalAmount = allowanceTotalAmount
        self.chargeTotalAmount = chargeTotalAmount
        self.prepaidAmount = prepaidAmount
        self.payableRoundingAmount = payableRoundingAmount
        self.payableAmount = payableAmount
    }
}
