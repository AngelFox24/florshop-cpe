import Foundation

public struct Supplier: Codable, Equatable, Sendable {
    public let taxIdentifier: PartyIdentifier
    public let commercialName: String?
    public let legalName: String
    public let address: Address?
    public let contact: Contact?

    public init(
        taxIdentifier: PartyIdentifier,
        commercialName: String? = nil,
        legalName: String,
        address: Address? = nil,
        contact: Contact? = nil
    ) {
        self.taxIdentifier = taxIdentifier
        self.commercialName = commercialName
        self.legalName = legalName
        self.address = address
        self.contact = contact
    }
}

public struct Customer: Codable, Equatable, Sendable {
    public let identifier: PartyIdentifier
    public let legalName: String
    public let address: Address?

    public init(identifier: PartyIdentifier, legalName: String, address: Address? = nil) {
        self.identifier = identifier
        self.legalName = legalName
        self.address = address
    }
}

public struct PartyIdentifier: Codable, Equatable, Sendable {
    public let value: String
    public let documentType: IdentityDocumentType

    public init(value: String, documentType: IdentityDocumentType) {
        self.value = value
        self.documentType = documentType
    }
}

public enum IdentityDocumentType: String, Codable, Sendable {
    case dni = "1"
    case carnetDeExtranjeria = "4"
    case ruc = "6"
    case passport = "7"
    case cedulaDiplomatica = "A"
    case sinDocumento = "0"
}

public struct Address: Codable, Equatable, Sendable {
    public let ubigeoCode: String?
    public let addressTypeCode: String?
    public let urbanization: String?
    public let city: String?
    public let department: String?
    public let district: String?
    public let line: String
    public let countryCode: String

    public init(
        ubigeoCode: String? = nil,
        addressTypeCode: String? = nil,
        urbanization: String? = nil,
        city: String? = nil,
        department: String? = nil,
        district: String? = nil,
        line: String,
        countryCode: String = "PE"
    ) {
        self.ubigeoCode = ubigeoCode
        self.addressTypeCode = addressTypeCode
        self.urbanization = urbanization
        self.city = city
        self.department = department
        self.district = district
        self.line = line
        self.countryCode = countryCode
    }
}

public struct Contact: Codable, Equatable, Sendable {
    public let telephone: String?
    public let email: String?

    public init(telephone: String? = nil, email: String? = nil) {
        self.telephone = telephone
        self.email = email
    }
}

struct SignatureInformation: Sendable {
    static let xmlSignatureID = "SignSUNAT"
    static let uri = "#\(xmlSignatureID)"

    let identifier: String
    let signatoryIdentifier: String
    let signatoryName: String

    init(identifier: String, supplier: Supplier) {
        self.identifier = identifier
        self.signatoryIdentifier = supplier.taxIdentifier.value
        self.signatoryName = supplier.legalName
    }
}
