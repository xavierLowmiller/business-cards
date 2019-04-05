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

    let passController = PassController()
    devices.post([String: String].self, at: String.parameter, use: passController.create)
    devices.get("/", use: passController.getPasses)
    devices.delete(String.parameter, use: passController.delete)
    v1.get("passes", String.parameter, String.parameter, use: passController.getPass)
    v1.post("log", use: passController.log)
    router.get(String.parameter, use: passController.redirect)
}
