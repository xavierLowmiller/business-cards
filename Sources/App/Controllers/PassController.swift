// Implements https://developer.apple.com/library/archive/documentation/PassKit/Reference/PassKit_WebService/WebService.html

import Vapor

private extension String {
    static let passType = "pass.de.adorsys.businesscard"
    static let passKitHeader = "application/vnd.apple.pkpass"
    static let applicationJsonHeader = "application/json"
}

final class PassController {
    struct PushQueryResponse: Content {
        let lastUpdated: String
        let serialNumbers: [String]
    }

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

    func getPasses(_ req: Request) throws -> Future<PushQueryResponse> {
        let deviceID: String = try req.parameters.next()
        let passType: String = try req.parameters.next()
        guard passType == .passType else { throw Abort(.badRequest) }

        let tag: TimeInterval = (try? req.query.get(at: "passesUpdatedSince")) ?? 0
        let timeStamp = Date(timeIntervalSince1970: tag)

        return PushAssociation.query(on: req)
            .filter(\.deviceID, .equal, deviceID)
            .filter(\.creationDate, .greaterThan, timeStamp)
            .all()
            .map { passes in
                let latestTimeStamp = passes
                    .map { $0.creationDate }
                    .sorted()
                    .last?
                    .timeIntervalSince1970
                let passIDs = passes.map { $0.passID }
                return PushQueryResponse(lastUpdated: "\(latestTimeStamp ?? tag)", serialNumbers: passIDs)
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

        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let lastModified = Date(rfc1123: (attributes[.modificationDate] as! Date).rfc1123)!

        if let reqHeader = req.http.headers[.ifModifiedSince].first,
            let ifModifiedSince = Date(rfc1123: reqHeader),
            ifModifiedSince >= lastModified {
            return HTTPResponse(status: .notModified)
        }

        var res = try req.fileio().chunkedResponse(file: path, for: req.http)
        res.headers.add(name: .contentType, value: .passKitHeader)
        res.headers.add(name: .lastModified, value: lastModified.rfc1123)
        return res
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
                .andAll($0.map { $0.delete(on: req) }, eventLoop: req.eventLoop)
            }
            .map {
                req.response()
            }
    }

    func log(_ req: Request) throws -> HTTPResponse {
        print(req.http.body)
        var res = HTTPResponse(status: .ok)
        res.headers.add(name: .contentType, value: .applicationJsonHeader)
        return res
    }

    func redirect(_ req: Request) throws -> Response {
        let serialNumber: String = try req.parameters.next()
        return req.redirect(to: "/v1/passes/" + .passType + "/" + serialNumber)
    }
}
