import Vapor

final class PassController {
    struct PushQueryResponse: Content {
        let lastUpdated: String
        let serialNumbers: [String]
    }

    func getPasses(_ req: Request) throws -> Future<PushQueryResponse> {
        let deviceID: String = try req.parameters.next()
        let passType: String = try req.parameters.next()

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

//    private func getPasses(_ request: Request) throws -> ResponseRepresentable {
//        guard let deviceID = request.parameters[deviceIdKey]?.string,
//            let passTypeIdentifier = request.parameters[passTypeKey],
//            passTypeIdentifier.string == passID
//            else { throw Abort.badRequest }
//
//        if let tag = request.query?["passesUpdatedSince"]?.string {
//            print(tag)
//        }
//
//        let serialNumbers = try PushAssociation.makeQuery()
//            .filter("device_id", deviceID)
//            .all()
//            .map({ $0.passID })
//        if serialNumbers.isEmpty {
//            return Response(status: .noContent)
//        } else {
//            var json = JSON()
//            try json.set("lastUpdated", "")
//            try json.set("serialNumbers", serialNumbers.makeNode(in: nil))
//            return json
//        }
//    }

    /// Saves a decoded `PushAssociation` to the database.
    func create(_ req: Request, json: [String: String]) throws -> Future<Response> {
        let deviceID: String = try req.parameters.next()
        let passType: String = try req.parameters.next()
        let passID: String = try req.parameters.next()
        guard let pushID = json["pushToken"] else { throw Abort(.badRequest) }

        return PushAssociation.query(on: req)
            .filter(\.deviceID, .equal, deviceID)
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

}
