@testable import App
import Vapor
import XCTest
import FluentSQLite

final class PassControllerTests: XCTestCase {
    func testPostingAPushTokenShouldCreateAPushAssociationInTheDatabase() throws {
        // Given
        let deviceID = "12345"
        let passID = "abc"
        let pushID = "54321"
        let app = try Application.testing()
        let conn = try app.newConnection(to: .sqlite).wait()
        let url = URL(string: "/v1/devices/\(deviceID)/registrations/\(String.passType)/\(passID)")!
        let body = try JSONEncoder().encode(["pushToken": pushID])
        let request = HTTPRequest(method: .POST,
                                  url: url,
                                  headers: .applicationJsonHeaders,
                                  body: body)
        let responder = try app.make(Responder.self)
        XCTAssert(try PushAssociation.query(on: conn).all().wait().isEmpty)

        // When
        let response = try responder.respond(to: .init(http: request, using: app)).wait()

        // Then
        let pushAssociations = try PushAssociation.query(on: conn).all().wait()
        XCTAssertEqual(response.http.status, .created)
        XCTAssertEqual(pushAssociations.count, 1)
        XCTAssertEqual(pushAssociations[0].deviceID, deviceID)
        XCTAssertEqual(pushAssociations[0].passID, passID)
        XCTAssertEqual(pushAssociations[0].pushID, pushID)
        conn.close()
    }

    func testPostingAnExistingPushTokenShouldNotCreateAPushAssociationInTheDatabase() throws {
        // Given
        let deviceID = "12345"
        let passID = "abc"
        let pushID = "54321"
        let pushAssociation = PushAssociation(deviceID: deviceID,
                                              pushID: pushID,
                                              passType: .passType,
                                              passID: passID)
        let app = try Application.testing()
        let conn = try app.newConnection(to: .sqlite).wait()
        _ = pushAssociation.save(on: conn)
        let url = URL(string: "/v1/devices/\(deviceID)/registrations/\(String.passType)/\(passID)")!
        let body = try JSONEncoder().encode(["pushToken": pushID])
        let request = HTTPRequest(method: .POST,
                                  url: url,
                                  headers: .applicationJsonHeaders,
                                  body: body)
        let responder = try app.make(Responder.self)
        XCTAssertEqual(try PushAssociation.query(on: conn).count().wait(), 1)

        // When
        let response = try responder.respond(to: .init(http: request, using: app)).wait()

        // Then
        XCTAssertEqual(response.http.status, .ok)
        XCTAssertEqual(try PushAssociation.query(on: conn).count().wait(), 1)
        conn.close()
    }

    static let allTests = [
        ("testPostingAPushTokenShouldCreateAPushAssociationInTheDatabase",
         testPostingAPushTokenShouldCreateAPushAssociationInTheDatabase)
    ]
}

private extension String {
    static let passType = "pass.de.adorsys.businesscard"
    static let passKitHeader = "application/vnd.apple.pkpass"
}

private extension HTTPHeaders {
    static let applicationJsonHeaders = HTTPHeaders([
        ("Content-Type", "application/json")
        ])
}
