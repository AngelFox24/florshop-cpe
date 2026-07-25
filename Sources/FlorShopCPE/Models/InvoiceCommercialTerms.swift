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

/// Condición de pago de una factura. Permite representar tanto la condición
/// principal (`Contado` o `Credito`) como sus cuotas.
public struct PaymentTerm: Codable, Equatable, Sendable {
    public let identifier: String
    public let paymentMeansID: String
    public let amount: MonetaryAmount?
    public let dueDate: IssueDate?

    public init(
        identifier: String = "FormaPago",
        paymentMeansID: String,
        amount: MonetaryAmount? = nil,
        dueDate: IssueDate? = nil
    ) {
        self.identifier = identifier
        self.paymentMeansID = paymentMeansID
        self.amount = amount
        self.dueDate = dueDate
    }
}

/// Cargo o descuento global de una factura.
public struct AllowanceCharge: Codable, Equatable, Sendable {
    public let isCharge: Bool
    public let reasonCode: String?
    public let multiplierFactor: Decimal?
    public let amount: MonetaryAmount
    public let baseAmount: MonetaryAmount?

    public init(
        isCharge: Bool,
        reasonCode: String? = nil,
        multiplierFactor: Decimal? = nil,
        amount: MonetaryAmount,
        baseAmount: MonetaryAmount? = nil
    ) {
        self.isCharge = isCharge
        self.reasonCode = reasonCode
        self.multiplierFactor = multiplierFactor
        self.amount = amount
        self.baseAmount = baseAmount
    }
}
