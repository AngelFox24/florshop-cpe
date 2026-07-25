import Foundation
import ZIPFoundation

/// Archivo ZIP listo para ser remitido mediante `sendBill`.
public struct SunatBillPackage: Sendable {
    public let archiveURL: URL
    public let fileName: String
    public let xmlEntryName: String

    public init(archiveURL: URL, fileName: String, xmlEntryName: String) {
        self.archiveURL = archiveURL
        self.fileName = fileName
        self.xmlEntryName = xmlEntryName
    }
}

public enum SunatBillPackageError: Error, Equatable {
    case fileNotFound
    case sourceIsNotARegularFile
    case sourceIsNotAZIP
    case invalidFileName
    case unreadableZIP
    case zipMustContainExactlyOneXML
    case xmlEntryNameDoesNotMatchZIP
}

/// Valida el archivo que se entregará al servicio `sendBill` de SUNAT.
public struct SunatBillPackageValidator {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func validate(zipAt zipURL: URL) throws -> SunatBillPackage {
        let archiveURL = zipURL.standardizedFileURL
        try validateFile(at: archiveURL)

        let fileName = archiveURL.lastPathComponent
        guard isExpectedSunatFileName(fileName) else {
            throw SunatBillPackageError.invalidFileName
        }

        let archive: Archive
        do {
            archive = try Archive(url: archiveURL, accessMode: .read)
        } catch {
            throw SunatBillPackageError.unreadableZIP
        }

        let entries = Array(archive)
        guard entries.count == 1, let entry = entries.first,
              entry.type == .file,
              URL(fileURLWithPath: entry.path).pathExtension.caseInsensitiveCompare("xml") == .orderedSame else {
            throw SunatBillPackageError.zipMustContainExactlyOneXML
        }

        let expectedEntryName = archiveURL.deletingPathExtension().lastPathComponent + ".xml"
        guard entry.path == expectedEntryName else {
            throw SunatBillPackageError.xmlEntryNameDoesNotMatchZIP
        }

        return SunatBillPackage(
            archiveURL: archiveURL,
            fileName: fileName,
            xmlEntryName: entry.path
        )
    }

    private func validateFile(at url: URL) throws {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw SunatBillPackageError.fileNotFound
        }
        guard !isDirectory.boolValue else {
            throw SunatBillPackageError.sourceIsNotARegularFile
        }
        guard url.pathExtension.caseInsensitiveCompare("zip") == .orderedSame else {
            throw SunatBillPackageError.sourceIsNotAZIP
        }
    }

    private func isExpectedSunatFileName(_ fileName: String) -> Bool {
        let pattern = #"^\d{11}-\d{2}-[A-Za-z0-9]{4}-\d{1,8}\.zip$"#
        return fileName.range(of: pattern, options: .regularExpression) != nil
    }
}
