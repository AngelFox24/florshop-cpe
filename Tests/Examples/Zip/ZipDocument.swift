import Foundation
import FlorShopCPE

struct ZipDocumentExample {
    // Example of SignedCPE in: Examples/Sing/SingDocument.swift
    static func zip(signedDocument: SignedBillCPE, url: URL) throws -> SunatBillDocument {
        // MARK: Example of Zip
        let document: SunatBillDocument = try FlorShopCPE.write(
            signedDocument,
            output: CPEOutputConfiguration(rootDirectory: url) //La URL de rootDirectory es la ruta donde se guardara los archivos
        )
        // MARK: End of Example of SING
        return document
    }

    static func zip(signedDocument: SignedSummaryCPE, url: URL) throws -> SunatSummaryDocument {
        try FlorShopCPE.write(
            signedDocument,
            output: CPEOutputConfiguration(rootDirectory: url)
        )
    }
}
