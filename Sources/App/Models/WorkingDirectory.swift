enum WorkingDirectory {
    static let root = #file.components(separatedBy: "/Sources/")[0] + "/"
    static let passes = root.appending("Passes/")
}
