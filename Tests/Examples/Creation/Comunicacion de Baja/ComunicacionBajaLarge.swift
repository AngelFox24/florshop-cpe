import Foundation
import FlorShopCPE

struct ComunicacionBajaLargeExample {
    static func getComunicacionBajaLarge(sequence: Int? = nil) throws -> ComunicacionBaja {
        let context = try makeComunicacionBajaExampleContext()

        // MARK: Example of Comunicacion de Baja
        return try ComunicacionBaja(
            identifier: VoidedDocumentsIdentifier(
                date: context.issueDate,
                sequence: sequence ?? context.sequence
            ),
            issueDate: context.issueDate,
            referenceDate: context.issueDate,
            supplier: Supplier(
                taxIdentifier: PartyIdentifier(value: "10708255195", documentType: .ruc),
                commercialName: "EMISOR",                    // Por defecto: nil
                legalName: "EMISOR S.A.C.",
                address: Address(                             // Por defecto: nil
                    ubigeoCode: "150130",                    // Por defecto: nil
                    addressTypeCode: "0000",                 // Por defecto: nil
                    urbanization: "URB. SAN BORJA",          // Por defecto: nil
                    city: "LIMA",                            // Por defecto: nil
                    department: "LIMA",                      // Por defecto: nil
                    district: "SAN BORJA",                   // Por defecto: nil
                    line: "CAL. PABLO USANDIZAGA 670",
                    countryCode: "PE"                        // Por defecto: "PE"
                ),
                contact: Contact(                             // Por defecto: nil
                    telephone: "+51 999 999 999",            // Por defecto: nil
                    email: "ventas@ejemplo.pe"               // Por defecto: nil
                )
            ),
            lines: [
                VoidedDocumentLine(
                    lineID: 1,
                    documentType: .factura,
                    documentIdentifier: DocumentIdentifier(series: "F001", number: "12345"),
                    reason: "DOCUMENTO NO OTORGADO"
                ),
                VoidedDocumentLine(
                    lineID: 2,
                    documentType: .notaDeCredito,
                    documentIdentifier: DocumentIdentifier(series: "FC01", number: "12346"),
                    reason: "NOTA DE CRÉDITO EMITIDA POR ERROR"
                ),
                VoidedDocumentLine(
                    lineID: 3,
                    documentType: .notaDeDebito,
                    documentIdentifier: DocumentIdentifier(series: "FD01", number: "12347"),
                    reason: "NOTA DE DÉBITO EMITIDA POR ERROR"
                )
            ]
        )
        // MARK: End of Example
    }
}

struct ComunicacionBajaExampleContext {
    let issueDate: IssueDate
    let sequence: Int
}

func makeComunicacionBajaExampleContext() throws -> ComunicacionBajaExampleContext {
    let dateTime = try currentLimaExampleDateTime()
    return ComunicacionBajaExampleContext(
        issueDate: dateTime.issueDate,
        sequence: max(1, Int(dateTime.instant.timeIntervalSince1970) % 99_999)
    )
}
