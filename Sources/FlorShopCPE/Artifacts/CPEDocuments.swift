import Foundation

/// Identidad usada para los nombres de archivo exigidos por SUNAT.
public struct CPEIdentity: Sendable, Equatable {
    public let emitterRUC: String
    /// Código usado en el nombre SUNAT (`01`, `03`, `RC`, posteriormente `RA`).
    public let documentTypeCode: String
    public let documentIdentifier: String

    public init(
        emitterRUC: String,
        documentType: ElectronicDocumentType,
        documentIdentifier: String
    ) {
        self.emitterRUC = emitterRUC
        self.documentTypeCode = documentType.rawValue
        self.documentIdentifier = documentIdentifier
    }

    public init(document: any UBLInvoiceDocument) {
        self.init(
            emitterRUC: document.supplier.taxIdentifier.value,
            documentType: document.identifier.type,
            documentIdentifier: document.identifier.value
        )
    }

    public init(note: NotaCredito) {
        self.init(
            emitterRUC: note.supplier.taxIdentifier.value,
            documentType: .notaDeCredito,
            documentIdentifier: note.identifier.value
        )
    }

    public init(debitNote: NotaDebito) {
        self.init(
            emitterRUC: debitNote.supplier.taxIdentifier.value,
            documentType: .notaDeDebito,
            documentIdentifier: debitNote.identifier.value
        )
    }

    public init(summary: ResumenDiarioBoletas) {
        self.init(
            emitterRUC: summary.supplier.taxIdentifier.value,
            documentTypeCode: "RC",
            documentIdentifier: String(summary.identifier.value.dropFirst(3))
        )
    }

    private init(
        emitterRUC: String,
        documentTypeCode: String,
        documentIdentifier: String
    ) {
        self.emitterRUC = emitterRUC
        self.documentTypeCode = documentTypeCode
        self.documentIdentifier = documentIdentifier
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

/// Comprobante preparado para envío. Encapsula sus rutas internas para que el
/// consumidor no tenga que pasar el ZIP ni la carpeta CDR manualmente.
public struct CPEDocument: Sendable {
    public let identity: CPEIdentity
    public let signedXMLURL: URL
    public let zipURL: URL
    public let cdrDirectory: URL

    public init(identity: CPEIdentity, signedXMLURL: URL, zipURL: URL, cdrDirectory: URL) {
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

/// Escribe los archivos de un CPE y encapsula sus rutas en `CPEDocument`.
public struct CPEDocumentWriter {
    private let fileManager: FileManager
    private let packager: XMLDocumentPackager

    public init(
        fileManager: FileManager = .default,
        packager: XMLDocumentPackager = XMLDocumentPackager()
    ) {
        self.fileManager = fileManager
        self.packager = packager
    }

    public func write(
        _ signedCPE: SignedCPE,
        output: CPEOutputConfiguration
    ) throws -> CPEDocument {
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
            return CPEDocument(
                identity: signedCPE.identity,
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
        for document: CPEDocument
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
