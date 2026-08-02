import Foundation
import ZIPFoundation

public struct SunatSummaryPackage: Sendable {
    public let archiveURL: URL
    public let fileName: String
    public let xmlEntryName: String

    public init(archiveURL: URL, fileName: String, xmlEntryName: String) {
        self.archiveURL = archiveURL
        self.fileName = fileName
        self.xmlEntryName = xmlEntryName
    }
}

public enum SunatSummaryPackageError: Error, Equatable {
    case fileNotFound
    case sourceIsNotARegularFile
    case sourceIsNotAZIP
    case invalidFileName
    case unreadableZIP
    case zipMustContainExactlyOneXML
    case xmlEntryNameDoesNotMatchZIP
}

public struct SunatSummaryPackageValidator {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func validate(zipAt zipURL: URL) throws -> SunatSummaryPackage {
        let url = zipURL.standardizedFileURL
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw SunatSummaryPackageError.fileNotFound
        }
        guard !isDirectory.boolValue else { throw SunatSummaryPackageError.sourceIsNotARegularFile }
        guard url.pathExtension.caseInsensitiveCompare("zip") == .orderedSame else {
            throw SunatSummaryPackageError.sourceIsNotAZIP
        }
        let fileName = url.lastPathComponent
        guard fileName.range(
            of: #"^\d{11}-(RC|RA)-\d{8}-\d{5}\.zip$"#,
            options: .regularExpression
        ) != nil else {
            throw SunatSummaryPackageError.invalidFileName
        }
        let archive: Archive
        do { archive = try Archive(url: url, accessMode: .read) }
        catch { throw SunatSummaryPackageError.unreadableZIP }
        let entries = Array(archive)
        guard entries.count == 1, let entry = entries.first,
              entry.type == .file,
              URL(fileURLWithPath: entry.path).pathExtension.caseInsensitiveCompare("xml") == .orderedSame else {
            throw SunatSummaryPackageError.zipMustContainExactlyOneXML
        }
        let expected = url.deletingPathExtension().lastPathComponent + ".xml"
        guard entry.path == expected else { throw SunatSummaryPackageError.xmlEntryNameDoesNotMatchZIP }
        return SunatSummaryPackage(archiveURL: url, fileName: fileName, xmlEntryName: entry.path)
    }
}
