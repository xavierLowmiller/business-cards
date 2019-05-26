//
//  Application+Testing.swift
//  App
//
//  Created by Xaver Lohmüller on 12.05.19.
//

import App
import Vapor

extension Application {
    static func testing() throws -> Application {
        var config = Config.default()
        var services = Services.default()
        var env = Environment.testing
        
        try App.configure(&config, &env, &services)
        let app = try Application(config: config, environment: env, services: services)
        try App.boot(app)

        return app
    }
}
