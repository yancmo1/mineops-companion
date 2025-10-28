import Foundation

public enum ResourceLoader {
    enum LoadError: Error, LocalizedError {
        case missing(String)

        var errorDescription: String? {
            switch self {
            case .missing(let name):
                return "Resource not found in Bundle.module: \(name)"
            }
        }
    }

    /// URL for a resource inside the package's Resources folder.
    public static func url(
        for name: String,
        ext: String? = nil,
        subdirectory: String? = nil
    ) throws -> URL {
        if let resourceURL = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            return resourceURL
        }
        throw LoadError.missing([name, ext].compactMap { $0 }.joined(separator: "."))
    }

    /// Raw data loader (JSON by default).
    public static func data(
        named name: String,
        ext: String = "json",
        subdirectory: String? = nil
    ) throws -> Data {
        let resourceURL = try url(for: name, ext: ext, subdirectory: subdirectory)
        return try Data(contentsOf: resourceURL, options: .mappedIfSafe)
    }

    /// Decode any Decodable type from a bundled JSON file.
    public static func decode<T: Decodable>(
        _ type: T.Type,
        from name: String,
        ext: String = "json",
        decoder: JSONDecoder = .init()
    ) throws -> T {
        let payload = try data(named: name, ext: ext)
        return try decoder.decode(T.self, from: payload)
    }
}
