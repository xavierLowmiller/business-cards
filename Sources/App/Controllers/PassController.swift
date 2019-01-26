import Vapor

private extension String {
    static let passType = "pass.de.adorsys.businesscard"
    static let passKitHeader = "application/vnd.apple.pkpass"
}

final class PassController {
    struct PushQueryResponse: Content {
        let lastUpdated: String
        let serialNumbers: [String]
    }

    func getPasses(_ req: Request) throws -> Future<PushQueryResponse> {
        let deviceID: String = try req.parameters.next()
        let passType: String = try req.parameters.next()
        guard passType == .passType else { throw Abort(.badRequest) }

        if let tag: String = try? req.query.get(at: "passesUpdatedSince") {
            print(tag)
        }

        return PushAssociation.query(on: req)
            .filter(\.deviceID, .equal, deviceID)
            .all()
            .map {
                let passIDs = $0.map { $0.passID }
                return PushQueryResponse(lastUpdated: "", serialNumbers: passIDs)
            }
    }

    func getPass(_ req: Request) throws -> HTTPResponse {
        let passType: String = try req.parameters.next()
        var serialNumber: String = try req.parameters.next()

        guard passType == .passType else { throw Abort(.badRequest) }

        let fileExtension = ".pkpass"

        if !serialNumber.hasSuffix(fileExtension) {
            serialNumber += fileExtension
        }

        let path = WorkingDirectory.passes + serialNumber

        var res = try req.fileio().chunkedResponse(file: path, for: req.http)
        res.headers.add(name: .contentType, value: .passKitHeader)
        print(res)
        return res
    }

    /// Saves a decoded `PushAssociation` to the database.
    func create(_ req: Request, json: [String: String]) throws -> Future<Response> {
        let deviceID: String = try req.parameters.next()
        let passType: String = try req.parameters.next()
        let passID: String = try req.parameters.next()

        guard let pushID = json["pushToken"],
            passType == .passType
            else { throw Abort(.badRequest) }

        return PushAssociation.query(on: req)
            .filter(\.deviceID, .equal, deviceID)
            .filter(\.passType, .equal, .passType)
            .filter(\.passID, .equal, passID)
            .count()
            .map { $0 != 0 }
            .flatMap { exists -> Future<HTTPStatus> in
                // If token exists, return 200
                guard !exists else { return req.future(.ok) }

                let push = PushAssociation(
                    deviceID: deviceID,
                    pushID: pushID,
                    passType: passType,
                    passID: passID
                )
                return push
                    .save(on: req)
                    .map { _ in .created }
            }
            .flatMap { status in
                req.response().encode(status: status, for: req)
            }
    }

    func delete(_ req: Request) throws -> Future<Response> {
        let deviceID: String = try req.parameters.next()
        let passType: String = try req.parameters.next()
        let passID: String = try req.parameters.next()

        guard passType == .passType else { throw Abort(.badRequest) }

        return PushAssociation.query(on: req)
            .filter(\.deviceID, .equal, deviceID)
            .filter(\.passType, .equal, .passType)
            .filter(\.passID, .equal, passID)
            .all()
            .flatMap {
                Future<Void>.andAll($0.map { $0.delete(on: req) }, eventLoop: req.eventLoop)
            }
            .map {
                req.response()
            }
    }

    func log(_ req: Request) throws -> HTTPResponse {
        print(req.http.body)
        var res = HTTPResponse(status: .ok)
        res.headers.add(name: .contentType, value: "application/json")
        return res
    }

    func redirect(_ req: Request) throws -> Response {
        let serialNumber: String = try req.parameters.next()
        return req.redirect(to: "/v1/passes/" + .passType + "/" + serialNumber)
    }
}
