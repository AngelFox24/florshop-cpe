import Foundation

/// Tipo de CPE usado para construir sus archivos y seleccionar el flujo SUNAT.
public enum CPEDocumentType: String, Sendable {
    case factura = "01"
    case boleta = "03"
    case notaDeCredito = "07"
    case notaDeDebito = "08"
    case resumenDiario = "RC"
    case comunicacionBaja = "RA"

    public init(_ documentType: ElectronicDocumentType) {
        switch documentType {
        case .factura: self = .factura
        case .boleta: self = .boleta
        case .notaDeCredito: self = .notaDeCredito
        case .notaDeDebito: self = .notaDeDebito
        }
    }
}

/// Identidad usada para los nombres de archivo exigidos por SUNAT.
public struct CPEIdentity: Sendable, Equatable {
    public let emitterRUC: String
    public let documentType: CPEDocumentType
    public let documentIdentifier: String

    public init(
        emitterRUC: String,
        documentType: CPEDocumentType,
        documentIdentifier: String
    ) {
        self.emitterRUC = emitterRUC
        self.documentType = documentType
        self.documentIdentifier = documentIdentifier
    }

    public init(document: any UBLInvoiceDocument) {
        self.init(
            emitterRUC: document.supplier.taxIdentifier.value,
            documentType: CPEDocumentType(document.documentType),
            documentIdentifier: document.identifier.value
        )
    }

    public init(note: NotaCredito) {
        self.init(
            emitterRUC: note.supplier.taxIdentifier.value,
            documentType: CPEDocumentType(note.documentType),
            documentIdentifier: note.identifier.value
        )
    }

    public init(debitNote: NotaDebito) {
        self.init(
            emitterRUC: debitNote.supplier.taxIdentifier.value,
            documentType: CPEDocumentType(debitNote.documentType),
            documentIdentifier: debitNote.identifier.value
        )
    }

    public init(summary: ResumenDiarioBoletas) {
        self.init(
            emitterRUC: summary.supplier.taxIdentifier.value,
            documentType: .resumenDiario,
            documentIdentifier: String(summary.identifier.value.dropFirst(3))
        )
    }

    public init(communication: ComunicacionBaja) {
        self.init(
            emitterRUC: communication.supplier.taxIdentifier.value,
            documentType: .comunicacionBaja,
            documentIdentifier: String(communication.identifier.value.dropFirst(3))
        )
    }

    /// Código usado en el nombre SUNAT (`01`, `03`, `07`, `08`, `RC`, `RA`).
    public var documentTypeCode: String {
        documentType.rawValue
    }

    public var fileBaseName: String {
        "\(emitterRUC)-\(documentTypeCode)-\(documentIdentifier)"
    }
}

/// Carpeta raíz de un comprobante. La librería crea dentro de ella `xml`,
/// `zip` y `cdr`, sin pedir más rutas al consumidor.
public struct CPEOutputConfiguration: Sendable {
    public let rootDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }
}

/// Interfaz común de un comprobante preparado para enviar a SUNAT.
public protocol CPEDocument: Sendable {
    var identity: CPEIdentity { get }
    var signedXMLURL: URL { get }
    var zipURL: URL { get }
    var cdrDirectory: URL { get }
}

/// Documento preparado para la operación SUNAT `sendBill`.
public struct SunatBillDocument: CPEDocument {
    public let identity: CPEIdentity
    public let signedXMLURL: URL
    public let zipURL: URL
    public let cdrDirectory: URL

    init(identity: CPEIdentity, signedXMLURL: URL, zipURL: URL, cdrDirectory: URL) {
        self.identity = identity
        self.signedXMLURL = signedXMLURL
        self.zipURL = zipURL
        self.cdrDirectory = cdrDirectory
    }
}

/// Documento preparado para las operaciones SUNAT `sendSummary` y
/// `getStatus`.
public struct SunatSummaryDocument: CPEDocument {
    public let identity: CPEIdentity
    public let signedXMLURL: URL
    public let zipURL: URL
    public let cdrDirectory: URL

    init(identity: CPEIdentity, signedXMLURL: URL, zipURL: URL, cdrDirectory: URL) {
        self.identity = identity
        self.signedXMLURL = signedXMLURL
        self.zipURL = zipURL
        self.cdrDirectory = cdrDirectory
    }
}

/// Rutas de los archivos CDR devueltos por SUNAT.
public struct SunatCDRArtifacts: Sendable {
    public let archiveURL: URL
    public let xmlURL: URL

    public init(archiveURL: URL, xmlURL: URL) {
        self.archiveURL = archiveURL
        self.xmlURL = xmlURL
    }
}

public enum CPEDocumentWritingError: Error, Equatable {
    case documentAlreadyExists
    case unableToCreateOutputDirectory
    case unableToWriteSignedXML
    case unableToWriteCDRArchive
    case unableToWriteCDRXML
}

/// Escribe los archivos de un CPE y encapsula sus rutas en un documento SUNAT.
struct CPEDocumentWriter {
    private let fileManager: FileManager
    private let packager: XMLDocumentPackager

    init(
        fileManager: FileManager = .default,
        packager: XMLDocumentPackager = XMLDocumentPackager()
    ) {
        self.fileManager = fileManager
        self.packager = packager
    }

    func write(
        _ signedCPE: SignedBillCPE,
        output: CPEOutputConfiguration
    ) throws -> SunatBillDocument {
        let artifacts = try writeArtifacts(signedCPE, output: output)
        return SunatBillDocument(
            identity: signedCPE.identity,
            signedXMLURL: artifacts.signedXMLURL,
            zipURL: artifacts.zipURL,
            cdrDirectory: artifacts.cdrDirectory
        )
    }

    func write(
        _ signedCPE: SignedSummaryCPE,
        output: CPEOutputConfiguration
    ) throws -> SunatSummaryDocument {
        let artifacts = try writeArtifacts(signedCPE, output: output)
        return SunatSummaryDocument(
            identity: signedCPE.identity,
            signedXMLURL: artifacts.signedXMLURL,
            zipURL: artifacts.zipURL,
            cdrDirectory: artifacts.cdrDirectory
        )
    }

    private func writeArtifacts(
        _ signedCPE: any SignedCPE,
        output: CPEOutputConfiguration
    ) throws -> WrittenCPEArtifacts {
        let directories = try outputDirectories(for: output)
        let fileBaseName = signedCPE.identity.fileBaseName
        let xmlURL = directories.xml.appendingPathComponent(fileBaseName).appendingPathExtension("xml")
        let zipURL = directories.zip.appendingPathComponent(fileBaseName).appendingPathExtension("zip")

        guard !fileManager.fileExists(atPath: xmlURL.path),
              !fileManager.fileExists(atPath: zipURL.path) else {
            throw CPEDocumentWritingError.documentAlreadyExists
        }

        do {
            try signedCPE.xml.write(to: xmlURL, options: .atomic)
        } catch {
            throw CPEDocumentWritingError.unableToWriteSignedXML
        }

        do {
            let packaged = try packager.package(xmlAt: xmlURL, destinationDirectory: directories.zip)
            return WrittenCPEArtifacts(
                signedXMLURL: xmlURL,
                zipURL: packaged.archiveURL,
                cdrDirectory: directories.cdr
            )
        } catch {
            try? fileManager.removeItem(at: xmlURL)
            throw error
        }
    }

    func storeCDR(
        _ result: SunatBillSubmissionResult,
        for document: any CPEDocument
    ) throws -> SunatCDRArtifacts {
        let fileBaseName = "R-\(document.identity.fileBaseName)"
        let archiveURL = document.cdrDirectory.appendingPathComponent(fileBaseName).appendingPathExtension("zip")
        let xmlURL = document.cdrDirectory.appendingPathComponent(fileBaseName).appendingPathExtension("xml")

        guard !fileManager.fileExists(atPath: archiveURL.path),
              !fileManager.fileExists(atPath: xmlURL.path) else {
            throw CPEDocumentWritingError.documentAlreadyExists
        }

        do {
            try result.cdrArchive.write(to: archiveURL, options: .atomic)
        } catch {
            throw CPEDocumentWritingError.unableToWriteCDRArchive
        }

        do {
            try result.cdrXML.write(to: xmlURL, options: .atomic)
        } catch {
            try? fileManager.removeItem(at: archiveURL)
            throw CPEDocumentWritingError.unableToWriteCDRXML
        }

        return SunatCDRArtifacts(archiveURL: archiveURL, xmlURL: xmlURL)
    }

    private func outputDirectories(for output: CPEOutputConfiguration) throws -> OutputDirectories {
        let root = output.rootDirectory.standardizedFileURL
        let directories = OutputDirectories(
            xml: root.appendingPathComponent("xml", isDirectory: true),
            zip: root.appendingPathComponent("zip", isDirectory: true),
            cdr: root.appendingPathComponent("cdr", isDirectory: true)
        )

        do {
            try fileManager.createDirectory(at: directories.xml, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: directories.zip, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: directories.cdr, withIntermediateDirectories: true)
            return directories
        } catch {
            throw CPEDocumentWritingError.unableToCreateOutputDirectory
        }
    }
}

private struct OutputDirectories {
    let xml: URL
    let zip: URL
    let cdr: URL
}

private struct WrittenCPEArtifacts {
    let signedXMLURL: URL
    let zipURL: URL
    let cdrDirectory: URL
}
