/// Datos comunes de los comprobantes que SUNAT representa mediante la raíz
/// UBL `Invoice`, actualmente factura y boleta de venta.
public protocol UBLInvoiceDocument: Sendable {
    var identifier: DocumentIdentifier { get }
    var issueDate: IssueDate { get }
    var issueTime: IssueTime? { get }
    var currency: CurrencyCode { get }
    var supplier: Supplier { get }
    var customer: Customer { get }
    var taxTotal: TaxTotal { get }
    var monetaryTotal: MonetaryTotal { get }
    var lines: [InvoiceLine] { get }
    var additionalNotes: [DocumentNote] { get }

    /// Tipo determinado por el modelo concreto. No forma parte del
    /// identificador para impedir combinaciones como `Boleta` + `factura`.
    var documentType: ElectronicDocumentType { get }
}

/// Leyendas explícitas del catálogo 52 de SUNAT que no pueden inferirse de los
/// importes o líneas del documento.
public enum SunatLegend: String, Codable, Equatable, Sendable {
    case perception = "2000"
    case amazonGoods = "2001"
    case amazonServices = "2002"
    case amazonConstruction = "2003"
    case travelAgencyPackage = "2004"
    case itinerantSale = "2005"
    case subjectToDetraction = "2006"

    public var text: String {
        switch self {
        case .perception: "COMPROBANTE DE PERCEPCIÓN"
        case .amazonGoods: "BIENES TRANSFERIDOS EN LA AMAZONÍA REGIÓN SELVA PARA SER CONSUMIDOS EN LA MISMA"
        case .amazonServices: "SERVICIOS PRESTADOS EN LA AMAZONÍA REGIÓN SELVA PARA SER CONSUMIDOS EN LA MISMA"
        case .amazonConstruction: "CONTRATOS DE CONSTRUCCIÓN EJECUTADOS EN LA AMAZONÍA REGIÓN SELVA"
        case .travelAgencyPackage: "AGENCIA DE VIAJE - PAQUETE TURÍSTICO"
        case .itinerantSale: "VENTA REALIZADA POR EMISOR ITINERANTE"
        case .subjectToDetraction: "OPERACIÓN SUJETA A DETRACCIÓN"
        }
    }
}

public struct DocumentNote: Equatable, Sendable {
    public let value: String
    public let legend: SunatLegend?

    /// Nota informativa libre, sin código del catálogo 52.
    public init(_ value: String) {
        self.value = value
        self.legend = nil
    }

    /// Leyenda SUNAT con código y texto canónicos.
    public init(legend: SunatLegend) {
        self.value = legend.text
        self.legend = legend
    }
}
