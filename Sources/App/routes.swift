import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    let v1 = router.grouped("v1")
    let devices = v1.grouped(
        "devices",
        String.parameter,
        "registrations",
        String.parameter
    )
    // Example of configuring a controller
    let passController = PassController()
    devices.post([String: String].self, at: String.parameter, use: passController.create)
    devices.get("/", use: passController.getPasses)
}
