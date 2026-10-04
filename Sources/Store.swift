import Foundation

enum Store {
    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("衣镜", isDirectory: true)
    }

    static var media: URL { root.appendingPathComponent("media", isDirectory: true) }
    static var libraryURL: URL { root.appendingPathComponent("library.json") }
    static var settingsURL: URL { root.appendingPathComponent("settings.json") }

    static func prepare() {
        try? FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
    }

    static func loadLibrary() -> LibraryFile? {
        guard let data = try? Data(contentsOf: libraryURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var library = try? decoder.decode(LibraryFile.self, from: data) else { return nil }
        library.sanitize()
        return library.looks.isEmpty ? nil : library
    }

    static func saveLibrary(_ library: LibraryFile) {
        prepare()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(library) else { return }
        try? data.write(to: libraryURL, options: .atomic)
    }

    static func loadSettings() -> Settings {
        guard let data = try? Data(contentsOf: settingsURL) else { return .initial }
        let decoder = JSONDecoder()
        return (try? decoder.decode(Settings.self, from: data)) ?? .initial
    }

    static func saveSettings(_ settings: Settings) {
        prepare()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settingsURL.path)
    }

    static func writeMedia(_ data: Data, ext: String) -> String {
        prepare()
        let name = UUID().uuidString + "." + ext
        try? data.write(to: media.appendingPathComponent(name), options: .atomic)
        return name
    }

    static func readMedia(_ name: String) -> Data? {
        try? Data(contentsOf: media.appendingPathComponent(name))
    }

    static func mediaURL(_ name: String) -> URL {
        media.appendingPathComponent(name)
    }
}
