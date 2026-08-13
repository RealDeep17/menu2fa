import Foundation

struct TOTPEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var issuer: String
    var algorithm: OTPAlgorithm
    var digits: Int
    var period: TimeInterval
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, issuer, algorithm, digits, period, createdAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        issuer: String = "General",
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: TimeInterval = 30.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.issuer = try container.decode(String.self, forKey: .issuer)
        self.algorithm = try container.decodeIfPresent(OTPAlgorithm.self, forKey: .algorithm) ?? .sha1
        self.digits = try container.decodeIfPresent(Int.self, forKey: .digits) ?? 6
        self.period = try container.decodeIfPresent(TimeInterval.self, forKey: .period) ?? 30.0
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

struct ExportableEntry: Codable {
    let name: String
    let issuer: String
    let secret: String
    var algorithm: OTPAlgorithm? = .sha1
    var digits: Int? = 6
    var period: TimeInterval? = 30.0

    enum CodingKeys: String, CodingKey {
        case name, issuer, secret, algorithm, digits, period
    }

    init(
        name: String,
        issuer: String,
        secret: String,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: TimeInterval = 30.0
    ) {
        self.name = name
        self.issuer = issuer
        self.secret = secret
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.issuer = try container.decode(String.self, forKey: .issuer)
        self.secret = try container.decode(String.self, forKey: .secret)
        self.algorithm = try container.decodeIfPresent(OTPAlgorithm.self, forKey: .algorithm) ?? .sha1
        self.digits = try container.decodeIfPresent(Int.self, forKey: .digits) ?? 6
        self.period = try container.decodeIfPresent(TimeInterval.self, forKey: .period) ?? 30.0
    }
}

