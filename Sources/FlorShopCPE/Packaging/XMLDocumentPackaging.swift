import Foundation
import ZIPFoundation

public struct PackagedXMLDocument: Sendable {
    /// Ruta del archivo ZIP creado.
    public let archiveURL: URL

    /// Nombre del XML dentro del ZIP, sin directorios.
    public let entryName: String

    public init(archiveURL: URL, entryName: String) {
        self.archiveURL = archiveURL
        self.entryName = entryName
    }
}

public enum XMLDocumentPackagingError: Error, Equatable {
    case sourceFileNotFound
    case sourceIsNotARegularFile
    case sourceIsNotXML
    case destinationDirectoryNotFound
    case destinationIsNotADirectory
    case destinationArchiveAlreadyExists
    case archiveCreationFailed
    case archiveEntryCreationFailed
}

/// Empaqueta XML firmados en ZIP para su posterior envío a SUNAT.
///
/// Forma parte de `FlorShopCPE`; la carpeta `Packaging` solo organiza este
/// paso independiente de generar y firmar el XML.
public struct XMLDocumentPackager {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func package(
        xmlAt xmlURL: URL,
        destinationDirectory: URL? = nil
    ) throws -> PackagedXMLDocument {
        let sourceURL = xmlURL.standardizedFileURL
        try validateSource(sourceURL)

        let directoryURL = (destinationDirectory ?? sourceURL.deletingLastPathComponent()).standardizedFileURL
        try validateDestinationDirectory(directoryURL)

        let entryName = sourceURL.lastPathComponent
        let archiveURL = directoryURL
            .appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("zip")

        guard !fileManager.fileExists(atPath: archiveURL.path) else {
            throw XMLDocumentPackagingError.destinationArchiveAlreadyExists
        }
        let archive: Archive
        do {
            archive = try Archive(url: archiveURL, accessMode: .create)
        } catch {
            throw XMLDocumentPackagingError.archiveCreationFailed
        }

        do {
            try archive.addEntry(
                with: entryName,
                relativeTo: sourceURL.deletingLastPathComponent(),
                compressionMethod: .deflate
            )
        } catch {
            try? fileManager.removeItem(at: archiveURL)
            throw XMLDocumentPackagingError.archiveEntryCreationFailed
        }

        return PackagedXMLDocument(archiveURL: archiveURL, entryName: entryName)
    }

    private func validateSource(_ sourceURL: URL) throws {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
            throw XMLDocumentPackagingError.sourceFileNotFound
        }
        guard !isDirectory.boolValue else {
            throw XMLDocumentPackagingError.sourceIsNotARegularFile
        }
        guard sourceURL.pathExtension.caseInsensitiveCompare("xml") == .orderedSame else {
            throw XMLDocumentPackagingError.sourceIsNotXML
        }
    }

    private func validateDestinationDirectory(_ destinationURL: URL) throws {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory) else {
            throw XMLDocumentPackagingError.destinationDirectoryNotFound
        }
        guard isDirectory.boolValue else {
            throw XMLDocumentPackagingError.destinationIsNotADirectory
        }
    }
}
