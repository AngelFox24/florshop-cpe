import Foundation

public struct DocumentReference: Codable, Equatable, Sendable {
    public let identifier: String
    public let documentTypeCode: String
    public let documentTypeDescription: String?

    public init(
        identifier: String,
        documentTypeCode: String,
        documentTypeDescription: String? = nil
    ) {
        self.identifier = identifier
        self.documentTypeCode = documentTypeCode
        self.documentTypeDescription = documentTypeDescription
    }
}

/// Pago futuro que forma parte de una factura emitida al crédito.
///
/// SUNAT identifica las cuotas como `Cuota001`, `Cuota002`, etc. La librería
/// genera esos identificadores según la posición de cada elemento en el arreglo.
public struct PaymentInstallment: Codable, Equatable, Sendable {
    public let amount: MonetaryAmount
    public let dueDate: IssueDate

    public init(amount: MonetaryAmount, dueDate: IssueDate) {
        self.amount = amount
        self.dueDate = dueDate
    }
}

/// Condición de pago de una factura electrónica.
public enum PaymentCondition: Codable, Equatable, Sendable {
    /// El importe total se paga en la fecha de emisión.
    case cash

    /// Una parte o la totalidad se pagará después de la fecha de emisión.
    case credit(installments: [PaymentInstallment])

    public var pendingAmount: MonetaryAmount? {
        guard case let .credit(installments) = self else { return nil }
        return MonetaryAmount(
            value: CPEPrecision.monetarySum(installments.map(\.amount.value))
        )
    }
}

/// Cargo o descuento global de una factura.
public struct AllowanceCharge: Equatable, Sendable {
    public let isCharge: Bool
    public let reasonCode: String?
    public let multiplierFactor: Decimal?
    public let amount: MonetaryAmount
    public let baseAmount: MonetaryAmount?

    public init(
        isCharge: Bool,
        reasonCode: String? = nil,
        amount: Decimal
    ) {
        self.isCharge = isCharge
        self.reasonCode = reasonCode
        self.multiplierFactor = nil
        self.amount = MonetaryAmount(value: CPEPrecision.monetary(amount))
        self.baseAmount = nil
    }

    public init(
        isCharge: Bool,
        reasonCode: String? = nil,
        multiplierFactor: Decimal,
        baseAmount: Decimal
    ) {
        self.isCharge = isCharge
        self.reasonCode = reasonCode
        self.multiplierFactor = multiplierFactor
        self.baseAmount = MonetaryAmount(value: CPEPrecision.monetary(baseAmount))
        self.amount = MonetaryAmount(
            value: CPEPrecision.monetary(baseAmount * multiplierFactor)
        )
    }
}
