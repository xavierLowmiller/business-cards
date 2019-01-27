import FluentSQLite
import Vapor

/// A single entry of a PushAssociation list.
struct PushAssociation: SQLiteModel {
    var id: Int?

    let deviceID: String
    let pushID: String
    let passType: String
    let passID: String
    let creationDate: Date

    init(deviceID: String, pushID: String, passType: String, passID: String) {
        self.deviceID = deviceID
        self.pushID = pushID
        self.passType = passType
        self.passID = passID
        creationDate = Date()
    }
}

/// Allows `PushAssociation` to be used as a dynamic migration.
extension PushAssociation: Migration { }

/// Allows `PushAssociation` to be encoded to and decoded from HTTP messages.
extension PushAssociation: Content { }

/// Allows `PushAssociation` to be used as a dynamic parameter in route definitions.
extension PushAssociation: Parameter { }
