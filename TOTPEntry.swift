import Foundation

struct TOTPEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var issuer: String
    let createdAt: Date

    init(id: UUID = UUID(), name: String, issuer: String = "General", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.createdAt = createdAt
    }
}

struct ExportableEntry: Codable {
    let name: String
    let issuer: String
    let secret: String
}
