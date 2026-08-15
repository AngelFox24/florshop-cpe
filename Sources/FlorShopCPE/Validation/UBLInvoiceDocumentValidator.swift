import Foundation

public enum UBLInvoiceDocumentValidationError: Error, Equatable, Sendable {
    case invalidSeries(expectedPrefix: String)
    case invalidNumber
    case supplierMustHaveRUC
    case facturaCustomerMustHaveRUC
    case invalidRUC
    case invalidSupplierAddressTypeCode
    case emptyLines
    case duplicatedLineIdentifier(String)
    case emptyPaymentInstallments
    case tooManyPaymentInstallments
    case nonPositivePendingPaymentAmount
    case nonPositivePaymentInstallment(Int)
    case invalidPaymentInstallmentDueDate(Int)
    case paymentInstallmentsTotalMismatch
    case invalidPayableRoundingAmount
}

/// Verifica invariantes del dominio antes de generar o firmar el XML.
public struct UBLInvoiceDocumentValidator: Sendable {
    public init() {}

    public func validate(_ document: any UBLInvoiceDocument) throws {
        let expectedPrefix = document.documentType == .factura ? "F" : "B"
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
        if document.documentType == .factura {
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

        if let rounding = document.monetaryTotal.payableRoundingAmount,
           abs(CPEPrecision.monetary(rounding.value)) > 1 {
            throw UBLInvoiceDocumentValidationError.invalidPayableRoundingAmount
        }

        var identifiers = Set<String>()
        for line in document.lines where !identifiers.insert(line.id).inserted {
            throw UBLInvoiceDocumentValidationError.duplicatedLineIdentifier(line.id)
        }

        if let factura = document as? Factura,
           case let .credit(pendingAmount, installments) = factura.paymentCondition {
            guard pendingAmount.value > 0 else {
                throw UBLInvoiceDocumentValidationError.nonPositivePendingPaymentAmount
            }
            guard !installments.isEmpty else {
                throw UBLInvoiceDocumentValidationError.emptyPaymentInstallments
            }
            guard installments.count <= 999 else {
                throw UBLInvoiceDocumentValidationError.tooManyPaymentInstallments
            }
            for (index, installment) in installments.enumerated() {
                guard installment.amount.value > 0 else {
                    throw UBLInvoiceDocumentValidationError.nonPositivePaymentInstallment(index + 1)
                }
                guard dateKey(installment.dueDate) > dateKey(factura.issueDate) else {
                    throw UBLInvoiceDocumentValidationError.invalidPaymentInstallmentDueDate(index + 1)
                }
            }
            let installmentsTotal = installments.reduce(Decimal.zero) { partial, installment in
                partial + CPEPrecision.monetary(installment.amount.value)
            }
            guard CPEPrecision.monetary(installmentsTotal) == CPEPrecision.monetary(pendingAmount.value) else {
                throw UBLInvoiceDocumentValidationError.paymentInstallmentsTotalMismatch
            }
        }
    }

    private func isRUC(_ value: String) -> Bool {
        value.range(of: #"^\d{11}$"#, options: .regularExpression) != nil
    }

    private func dateKey(_ date: IssueDate) -> Int {
        date.year * 10_000 + date.month * 100 + date.day
    }
}
