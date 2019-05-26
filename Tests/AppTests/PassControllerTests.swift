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

    func testGettingAPassShouldReturnAPkPassFile() throws {
        // Given
        let passID = "xlo"
        let app = try Application.testing()
        let conn = try app.newConnection(to: .sqlite).wait()
        let responder = try app.make(Responder.self)
        let url = URL(string: "/v1/passes/\(String.passType)/\(passID)")!
        let request = HTTPRequest(url: url)

        // When
        let response = try responder.respond(to: .init(http: request, using: app)).wait()

        // Then
        XCTAssertEqual(response.http.status, .ok)
        XCTAssertEqual(response.http.headers[.contentType], [.passKitHeader])
        XCTAssertEqual(response.http.body.count, nil) // Means streaming
        conn.close()
    }

    func testGettingAPassWithAIfModifiedSinceDateWithinRangeShouldReturnNotModfied() throws {
        // Given
        let passID = "xlo"
        let app = try Application.testing()
        let conn = try app.newConnection(to: .sqlite).wait()
        let responder = try app.make(Responder.self)
        let url = URL(string: "/v1/passes/\(String.passType)/\(passID)")!
        let headers = HTTPHeaders([("If-Modified-Since", Date().rfc1123)])
        let request = HTTPRequest(url: url, headers: headers)

        // When
        let response = try responder.respond(to: .init(http: request, using: app)).wait()

        // Then
        XCTAssertEqual(response.http.status, .notModified)
        XCTAssertEqual(response.http.body.count, 0)
        conn.close()
    }

    func testGettingAPassWithAnOldIfModifiedSinceDateShouldReturnAPkPassFile() throws {
        // Given
        let passID = "xlo"
        let app = try Application.testing()
        let conn = try app.newConnection(to: .sqlite).wait()
        let responder = try app.make(Responder.self)
        let url = URL(string: "/v1/passes/\(String.passType)/\(passID)")!
        let headers = HTTPHeaders([("If-Modified-Since", Date.distantPast.rfc1123)])
        let request = HTTPRequest(url: url, headers: headers)

        // When
        let response = try responder.respond(to: .init(http: request, using: app)).wait()

        // Then
        XCTAssertEqual(response.http.status, .ok)
        XCTAssertEqual(response.http.headers[.contentType], [.passKitHeader])
        XCTAssertEqual(response.http.body.count, nil) // Means streaming
        conn.close()
    }

    static let allTests = [
        ("testLinuxTestSuiteIncludesAllTests",
         testLinuxTestSuiteIncludesAllTests),
        ("testPostingAPushTokenShouldCreateAPushAssociationInTheDatabase",
         testPostingAPushTokenShouldCreateAPushAssociationInTheDatabase),
        ("testPostingAnExistingPushTokenShouldNotCreateAPushAssociationInTheDatabase",
         testPostingAnExistingPushTokenShouldNotCreateAPushAssociationInTheDatabase),
        ("testGettingAPassShouldReturnAPkPassFile",
         testGettingAPassShouldReturnAPkPassFile),
        ("testGettingAPassWithAIfModifiedSinceDateWithinRangeShouldReturnNotModfied",
         testGettingAPassWithAIfModifiedSinceDateWithinRangeShouldReturnNotModfied),
        ("testGettingAPassWithAnOldIfModifiedSinceDateShouldReturnAPkPassFile",
         testGettingAPassWithAnOldIfModifiedSinceDateShouldReturnAPkPassFile)
    ]

    // https://oleb.net/blog/2017/03/keeping-xctest-in-sync/ Thanks, Ole!
    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let thisClass = type(of: self)
        let linuxCount = thisClass.allTests.count
        #if swift(>=4.0)
        let darwinCount = thisClass
            .defaultTestSuite.testCaseCount
        #else
        let darwinCount = Int(thisClass
            .defaultTestSuite().testCaseCount)
        #endif
        XCTAssertEqual(linuxCount, darwinCount,
                       "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }
}

private extension String {
    static let passType = "pass.de.adorsys.businesscard"
    static let passKitHeader = "application/vnd.apple.pkpass"
    static let applicationJsonHeader = "application/json"
}

private extension HTTPHeaders {
    static let applicationJsonHeaders = HTTPHeaders([
        ("Content-Type", .applicationJsonHeader)
    ])
}
