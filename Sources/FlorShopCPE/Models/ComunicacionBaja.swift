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

/// Tipos de comprobante admitidos por una Comunicación de Baja.
/// Las boletas y sus notas se anulan mediante el Resumen Diario.
public enum VoidedDocumentType: String, Codable, Sendable {
    case factura = "01"
    case notaDeCredito = "07"
    case notaDeDebito = "08"
}

/// Documento cuya numeración se comunica como dada de baja.
///
/// La Comunicación de Baja admite facturas y notas vinculadas a facturas.
/// Las boletas y sus notas se anulan mediante el Resumen Diario.
public struct VoidedDocumentLine: Codable, Equatable, Sendable {
    public let lineID: Int
    public let documentType: VoidedDocumentType
    public let documentIdentifier: DocumentIdentifier
    public let reason: String

    public init(
        lineID: Int,
        documentType: VoidedDocumentType,
        documentIdentifier: DocumentIdentifier,
        reason: String
    ) {
        self.lineID = lineID
        self.documentType = documentType
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

    init(
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

    /// Crea una Comunicación de Baja y deriva la fecha del identificador `RA`
    /// desde su fecha de generación. `referenceDate` corresponde a la fecha de
    /// emisión de los documentos dados de baja y puede ser anterior.
    public init(
        sequence: Int,
        issueDate: IssueDate,
        referenceDate: IssueDate,
        supplier: Supplier,
        lines: [VoidedDocumentLine]
    ) throws {
        try self.init(
            identifier: VoidedDocumentsIdentifier(date: issueDate, sequence: sequence),
            issueDate: issueDate,
            referenceDate: referenceDate,
            supplier: supplier,
            lines: lines
        )
    }
}
