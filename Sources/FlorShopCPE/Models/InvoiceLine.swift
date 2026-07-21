import Foundation

public struct InvoiceLine: Codable, Equatable, Sendable {
    public let id: String
    public let quantity: Quantity
    public let lineExtensionAmount: MonetaryAmount
    public let alternativePrices: [AlternativePrice]
    public let taxTotal: TaxTotal
    public let item: Item
    public let price: MonetaryAmount

    public init(
        id: String,
        quantity: Quantity,
        lineExtensionAmount: MonetaryAmount,
        alternativePrices: [AlternativePrice],
        taxTotal: TaxTotal,
        item: Item,
        price: MonetaryAmount
    ) {
        self.id = id
        self.quantity = quantity
        self.lineExtensionAmount = lineExtensionAmount
        self.alternativePrices = alternativePrices
        self.taxTotal = taxTotal
        self.item = item
        self.price = price
    }
}

public struct AlternativePrice: Codable, Equatable, Sendable {
    public let amount: MonetaryAmount
    public let type: PriceType

    public init(amount: MonetaryAmount, type: PriceType) {
        self.amount = amount
        self.type = type
    }
}

public enum PriceType: String, Codable, Sendable {
    case unitPriceIncludingTaxes = "01"
    case referenceValue = "02"
}

public struct Item: Codable, Equatable, Sendable {
    public let description: String
    public let sellerItemIdentifier: String?

    public init(description: String, sellerItemIdentifier: String? = nil) {
        self.description = description
        self.sellerItemIdentifier = sellerItemIdentifier
    }
}
