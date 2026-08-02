import Foundation

public enum UBLInvoiceDocumentValidationError: Error, Equatable, Sendable {
    case unexpectedDocumentType(expected: ElectronicDocumentType, actual: ElectronicDocumentType)
    case invalidSeries(expectedPrefix: String)
    case invalidNumber
    case supplierMustHaveRUC
    case facturaCustomerMustHaveRUC
    case invalidRUC
    case invalidSupplierAddressTypeCode
    case emptyLines
    case duplicatedLineIdentifier(String)
    case inconsistentCurrency
}

/// Verifica invariantes del dominio antes de generar o firmar el XML.
public struct UBLInvoiceDocumentValidator: Sendable {
    public init() {}

    public func validate(_ document: any UBLInvoiceDocument) throws {
        guard document.identifier.type == document.expectedDocumentType else {
            throw UBLInvoiceDocumentValidationError.unexpectedDocumentType(
                expected: document.expectedDocumentType,
                actual: document.identifier.type
            )
        }

        let expectedPrefix = document.expectedDocumentType == .factura ? "F" : "B"
        let seriesPattern = "^\(expectedPrefix)[A-Za-z0-9]{3}$"
        guard document.identifier.series.range(of: seriesPattern, options: .regularExpression) != nil else {
            throw UBLInvoiceDocumentValidationError.invalidSeries(expectedPrefix: expectedPrefix)
        }
        guard document.identifier.number.range(of: #"^[1-9]\d{0,7}$"#, options: .regularExpression) != nil else {
            throw UBLInvoiceDocumentValidationError.invalidNumber
        }
        guard document.supplier.taxIdentifier.documentType == .ruc else {
            throw UBLInvoiceDocumentValidationError.supplierMustHaveRUC
        }
        guard isRUC(document.supplier.taxIdentifier.value) else {
            throw UBLInvoiceDocumentValidationError.invalidRUC
        }
        if let addressTypeCode = document.supplier.address?.addressTypeCode,
           addressTypeCode.range(of: #"^\d{4}$"#, options: .regularExpression) == nil {
            throw UBLInvoiceDocumentValidationError.invalidSupplierAddressTypeCode
        }
        if document.expectedDocumentType == .factura {
            guard document.customer.identifier.documentType == .ruc else {
                throw UBLInvoiceDocumentValidationError.facturaCustomerMustHaveRUC
            }
            guard isRUC(document.customer.identifier.value) else {
                throw UBLInvoiceDocumentValidationError.invalidRUC
            }
        }
        guard !document.lines.isEmpty else {
            throw UBLInvoiceDocumentValidationError.emptyLines
        }

        var identifiers = Set<String>()
        for line in document.lines where !identifiers.insert(line.id).inserted {
            throw UBLInvoiceDocumentValidationError.duplicatedLineIdentifier(line.id)
        }

        guard currencies(in: document).allSatisfy({ $0 == document.currency }) else {
            throw UBLInvoiceDocumentValidationError.inconsistentCurrency
        }
    }

    private func isRUC(_ value: String) -> Bool {
        value.range(of: #"^\d{11}$"#, options: .regularExpression) != nil
    }

    private func currencies(in document: any UBLInvoiceDocument) -> [CurrencyCode] {
        var result = [
            document.taxTotal.amount.currency,
            document.monetaryTotal.lineExtensionAmount.currency,
            document.monetaryTotal.taxInclusiveAmount.currency,
            document.monetaryTotal.payableAmount.currency
        ]
        result.append(contentsOf: [
            document.monetaryTotal.allowanceTotalAmount?.currency,
            document.monetaryTotal.chargeTotalAmount?.currency,
            document.monetaryTotal.prepaidAmount?.currency
        ].compactMap { $0 })
        result.append(contentsOf: document.taxTotal.subtotals.flatMap {
            [$0.taxableAmount.currency, $0.taxAmount.currency]
        })
        for line in document.lines {
            result.append(line.lineExtensionAmount.currency)
            result.append(line.price.currency)
            result.append(line.taxTotal.amount.currency)
            result.append(contentsOf: line.alternativePrices.map(\.amount.currency))
            result.append(contentsOf: line.taxTotal.subtotals.flatMap {
                [$0.taxableAmount.currency, $0.taxAmount.currency]
            })
        }
        if let factura = document as? Factura {
            result.append(contentsOf: factura.paymentTerms.compactMap(\.amount?.currency))
            result.append(contentsOf: factura.allowanceCharges.flatMap {
                [$0.amount.currency] + [$0.baseAmount?.currency].compactMap { $0 }
            })
        }
        return result
    }
}
