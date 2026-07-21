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

    public init(identifier: PartyIdentifier, legalName: String) {
        self.identifier = identifier
        self.legalName = legalName
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

public struct SignatureInformation: Codable, Equatable, Sendable {
    public let identifier: String
    public let signatoryIdentifier: String
    public let signatoryName: String
    public let uri: String

    public init(identifier: String, signatoryIdentifier: String, signatoryName: String, uri: String) {
        self.identifier = identifier
        self.signatoryIdentifier = signatoryIdentifier
        self.signatoryName = signatoryName
        self.uri = uri
    }
}
