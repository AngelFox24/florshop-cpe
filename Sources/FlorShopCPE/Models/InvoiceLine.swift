import Foundation

public struct InvoiceLine: Equatable, Sendable {
    public let id: String
    public let quantity: Quantity
    /// Precio y tratamiento tributario comercial recibidos sin modificar.
    public let pricing: LinePricing
    public let taxTreatment: TaxTreatment
    public let taxCategory: TaxCategory
    public let lineExtensionAmount: MonetaryAmount
    public let alternativePrices: [AlternativePrice]
    public let taxTotal: LineTaxTotal
    public let item: Item
    public let price: MonetaryAmount
    public let isFreeOfCharge: Bool?

    public init(
        id: String,
        quantity: Quantity,
        pricing: LinePricing,
        item: Item
    ) {
        let calculated = CPECalculation.line(
            quantity: quantity.value,
            pricing: pricing
        )
        let taxTreatment = pricing.taxTreatment
        let taxCategory = taxTreatment.category
        self.id = id
        self.quantity = quantity
        self.pricing = pricing
        self.taxTreatment = taxTreatment
        self.taxCategory = taxCategory
        self.lineExtensionAmount = calculated.lineExtensionAmount
        self.alternativePrices = calculated.alternativePrices
        self.taxTotal = calculated.taxTotal
        self.item = item
        self.price = calculated.price
        self.isFreeOfCharge = calculated.isFreeOfCharge ? true : nil
    }
}

public struct AlternativePrice: Equatable, Sendable {
    public let amount: MonetaryAmount
    public let type: PriceType

    init(amount: MonetaryAmount, type: PriceType) {
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
    public let commodityClassificationCode: String?

    public init(
        description: String,
        sellerItemIdentifier: String? = nil,
        commodityClassificationCode: String? = nil
    ) {
        self.description = description
        self.sellerItemIdentifier = sellerItemIdentifier
        self.commodityClassificationCode = commodityClassificationCode
    }
}
