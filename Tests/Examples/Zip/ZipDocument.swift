import Foundation
import FlorShopCPE

struct ZipDocument {
    // Example of SignedCPE in: Examples/Sing/SingDocument.swift
    static func zip(signedDocument: SignedCPE, url: URL) async throws -> CPEDocument {
        // MARK: Example of Zip
        let document: CPEDocument = try CPEDocumentWriter().write(
            signedDocument,
            output: CPEOutputConfiguration(rootDirectory: url) //La URL de rootDirectory es la ruta donde se guardara los archivos
        )
        // CPEDocument tiene los atributos .signedXMLURL que hace referencia a una URL donde esta (completar)
        let signedXML: URL = document.signedXMLURL
        // CPEDocument tiene los atributos .zipURL que hace referencia a una URL donde esta (completar)
        let zip: URL = document.zipURL
        // MARK: End of Example of SING
        return document
    }
}
