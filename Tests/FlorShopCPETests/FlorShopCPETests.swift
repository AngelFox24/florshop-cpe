import Foundation
import Testing
@testable import FlorShopCPE

@Test func boletaModelRetainsItsDomainData() {
    let amount = MonetaryAmount(value: 118, currency: .pen)
    let supplier = Supplier(
        taxIdentifier: PartyIdentifier(value: "20123456789", documentType: .ruc),
        legalName: "GREENTER S.A.C."
    )
    let customer = Customer(
        identifier: PartyIdentifier(value: "20203030", documentType: .dni),
        legalName: "PERSON 1"
    )
    let taxCategory = TaxCategory(
        percent: 18,
        exemptionReasonCode: .gravadoOperacionOnerosa,
        scheme: .igv
    )
    let taxTotal = TaxTotal(
        amount: MonetaryAmount(value: 18, currency: .pen),
        subtotals: [TaxSubtotal(
            taxableAmount: MonetaryAmount(value: 100, currency: .pen),
            taxAmount: MonetaryAmount(value: 18, currency: .pen),
            category: taxCategory
        )]
    )
    let line = InvoiceLine(
        id: "1",
        quantity: Quantity(value: 2, unitCode: .unit),
        lineExtensionAmount: MonetaryAmount(value: 100, currency: .pen),
        alternativePrices: [AlternativePrice(amount: amount, type: .unitPriceIncludingTaxes)],
        taxTotal: taxTotal,
        item: Item(description: "PROD 1", sellerItemIdentifier: "C023"),
        price: MonetaryAmount(value: 50, currency: .pen)
    )
    let boleta = Boleta(
        identifier: DocumentIdentifier(series: "B001", number: "1"),
        issueDate: IssueDate(year: 2020, month: 8, day: 19),
        currency: .pen,
        supplier: supplier,
        customer: customer,
        taxTotal: taxTotal,
        monetaryTotal: MonetaryTotal(
            lineExtensionAmount: MonetaryAmount(value: 100, currency: .pen),
            taxInclusiveAmount: amount,
            payableAmount: amount
        ),
        lines: [line]
    )

    #expect(boleta.identifier.value == "B001-1")
    #expect(boleta.lines.count == 1)
    #expect(boleta.taxTotal.subtotals.first?.category.scheme == .igv)
}
