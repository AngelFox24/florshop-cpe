import Foundation

/// Identificador SUNAT de una Comunicación de Baja
/// (`RA-YYYYMMDD-correlativo`).
public struct VoidedDocumentsIdentifier: Codable, Equatable, Sendable {
    public let date: IssueDate
    public let sequence: Int

    public init(date: IssueDate, sequence: Int) {
        self.date = date
        self.sequence = sequence
    }

    public var value: String {
        String(format: "RA-%04d%02d%02d-%05d", date.year, date.month, date.day, sequence)
    }
}

/// Documento cuya numeración se comunica como dada de baja.
///
/// La Comunicación de Baja admite facturas y notas vinculadas a facturas.
/// Las boletas y sus notas se anulan mediante el Resumen Diario.
public struct VoidedDocumentLine: Codable, Equatable, Sendable {
    public let lineID: Int
    public let documentIdentifier: DocumentIdentifier
    public let reason: String

    public init(
        lineID: Int,
        documentIdentifier: DocumentIdentifier,
        reason: String
    ) {
        self.lineID = lineID
        self.documentIdentifier = documentIdentifier
        self.reason = reason
    }
}

/// Comunicación de Baja representada por la raíz SUNAT `VoidedDocuments`.
///
/// Todos los documentos incluidos deben haber sido emitidos en
/// `referenceDate`. El envío utiliza el flujo asíncrono `sendSummary` /
/// `getStatus`; la persistencia del ticket y sus reintentos corresponden al
/// sistema que consume la librería.
public struct ComunicacionBaja: Codable, Equatable, Sendable {
    public let identifier: VoidedDocumentsIdentifier
    public let issueDate: IssueDate
    public let referenceDate: IssueDate
    public let supplier: Supplier
    public let lines: [VoidedDocumentLine]

    public init(
        identifier: VoidedDocumentsIdentifier,
        issueDate: IssueDate,
        referenceDate: IssueDate,
        supplier: Supplier,
        lines: [VoidedDocumentLine]
    ) throws {
        self.identifier = identifier
        self.issueDate = issueDate
        self.referenceDate = referenceDate
        self.supplier = supplier
        self.lines = lines
        try VoidedDocumentsValidator().validate(self)
    }
}
